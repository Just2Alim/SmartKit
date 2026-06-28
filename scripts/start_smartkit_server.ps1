param(
  [string]$ComposeFile = "docker-compose.server.yml",
  [string]$ComposeProject = "smartkit",
  [string]$ProjectRef = "gofpawwqtunhlnljujun"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

function Read-DotEnv($path) {
  $values = @{}
  if (!(Test-Path $path)) {
    throw ".env not found at $path"
  }

  Get-Content $path | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
      $values[$matches[1].Trim()] = $matches[2]
    }
  }
  return $values
}

function Require-EnvValue($values, $name) {
  if ([string]::IsNullOrWhiteSpace($values[$name])) {
    throw "$name is missing in .env"
  }
  return $values[$name]
}

function EnvValueOrDefault($values, $name, $fallback) {
  if ([string]::IsNullOrWhiteSpace($values[$name])) {
    return $fallback
  }
  return $values[$name]
}

$envValues = Read-DotEnv ".env"
$accessToken = Require-EnvValue $envValues "SUPABASE_ACCESS_TOKEN"
$proxyToken = Require-EnvValue $envValues "OLLAMA_PROXY_TOKEN"
$model = EnvValueOrDefault $envValues "OLLAMA_MODEL" "qwen3:latest"
$keepAlive = EnvValueOrDefault $envValues "OLLAMA_KEEP_ALIVE" "24h"
$numCtxMax = EnvValueOrDefault $envValues "OLLAMA_NUM_CTX_MAX" "1024"
$numPredictMax = EnvValueOrDefault $envValues "OLLAMA_NUM_PREDICT_MAX" "80"
$systemMax = EnvValueOrDefault $envValues "OLLAMA_SYSTEM_MAX" "1000"
$messageMax = EnvValueOrDefault $envValues "OLLAMA_MESSAGE_MAX" "360"

docker compose -p $ComposeProject -f $ComposeFile up -d --build
if ($LASTEXITCODE -ne 0) {
  throw "docker compose up failed"
}

docker compose -p $ComposeProject -f $ComposeFile up -d --force-recreate ollama-warmup
if ($LASTEXITCODE -ne 0) {
  throw "ollama warmup failed to start"
}

$warmupDeadline = (Get-Date).AddMinutes(3)
do {
  $warmupState = docker inspect "$ComposeProject-ollama-warmup-1" --format "{{.State.Status}} {{.State.ExitCode}}" 2>$null
  if ($warmupState -match "^exited 0") {
    break
  }
  if ($warmupState -match "^exited [1-9]") {
    docker compose -p $ComposeProject -f $ComposeFile logs --no-color --tail=80 ollama-warmup
    throw "ollama warmup failed"
  }
  Start-Sleep -Seconds 2
} while ((Get-Date) -lt $warmupDeadline)

if ((Get-Date) -ge $warmupDeadline) {
  throw "ollama warmup did not finish"
}

$healthDeadline = (Get-Date).AddMinutes(2)
do {
  try {
    $health = curl.exe -fsS "http://127.0.0.1:11500/health"
    if ($LASTEXITCODE -eq 0 -and $health -match '"ok"\s*:\s*true') {
      break
    }
  } catch {
    Start-Sleep -Seconds 2
  }
} while ((Get-Date) -lt $healthDeadline)

if ((Get-Date) -ge $healthDeadline) {
  throw "SmartKit proxy health check did not become ready"
}

$url = $null
$urlDeadline = (Get-Date).AddMinutes(2)
do {
  $logs = docker compose -p $ComposeProject -f $ComposeFile logs --no-color --tail=200 cloudflared 2>&1
  $match = [regex]::Match(($logs -join "`n"), 'https://[a-z0-9-]+\.trycloudflare\.com')
  if ($match.Success) {
    $url = $match.Value
    break
  }
  Start-Sleep -Seconds 2
} while ((Get-Date) -lt $urlDeadline)

if (!$url) {
  throw "Cloudflare tunnel URL was not found in cloudflared logs"
}

$env:SUPABASE_ACCESS_TOKEN = $accessToken
$tmp = Join-Path $env:TEMP ("smartkit-supabase-secrets-" + [guid]::NewGuid().ToString("N") + ".env")

try {
  [System.IO.File]::WriteAllLines(
    $tmp,
    @(
      "OLLAMA_BASE_URL=$url",
      "OLLAMA_MODEL=$model",
      "OLLAMA_API_KEY=$proxyToken",
      "OLLAMA_KEEP_ALIVE=$keepAlive",
      "OLLAMA_NUM_CTX_MAX=$numCtxMax",
      "OLLAMA_NUM_PREDICT_MAX=$numPredictMax",
      "OLLAMA_SYSTEM_MAX=$systemMax",
      "OLLAMA_MESSAGE_MAX=$messageMax"
    ),
    [System.Text.UTF8Encoding]::new($false)
  )

  npx -y supabase@latest secrets set --env-file $tmp --project-ref $ProjectRef --log-level error
} finally {
  if (Test-Path $tmp) {
    Remove-Item -LiteralPath $tmp -Force
  }
}

Write-Output "SmartKit server is running."
Write-Output "Cloudflare URL: $url"
