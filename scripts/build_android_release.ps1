param(
  [ValidateSet("apk", "appbundle", "both")]
  [string] $Target = "apk"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot ".env"

function Read-DotEnv {
  param([string] $Path)

  $values = @{}
  foreach ($line in Get-Content -LiteralPath $Path) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
      continue
    }

    $separator = $line.IndexOf("=")
    if ($separator -le 0) {
      continue
    }

    $key = $line.Substring(0, $separator).Trim()
    $value = $line.Substring($separator + 1).Trim()
    if (
      ($value.StartsWith('"') -and $value.EndsWith('"')) -or
      ($value.StartsWith("'") -and $value.EndsWith("'"))
    ) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    $values[$key] = $value
  }

  return $values
}

function Require-EnvValue {
  param(
    [hashtable] $Values,
    [string] $Name
  )

  if (-not $Values.ContainsKey($Name) -or [string]::IsNullOrWhiteSpace($Values[$Name])) {
    throw "Missing required $Name in .env"
  }

  return $Values[$Name]
}

if (-not (Test-Path -LiteralPath $envFile)) {
  throw ".env was not found at $envFile"
}

$values = Read-DotEnv -Path $envFile

$supabaseUrl = Require-EnvValue -Values $values -Name "SUPABASE_URL"
$supabaseAnonKey = Require-EnvValue -Values $values -Name "SUPABASE_ANON_KEY"
$apiBaseUrl = if (
  $values.ContainsKey("SMARTKIT_API_BASE_URL") -and
  -not [string]::IsNullOrWhiteSpace($values["SMARTKIT_API_BASE_URL"])
) {
  $values["SMARTKIT_API_BASE_URL"]
} else {
  "$($supabaseUrl.TrimEnd('/'))/functions/v1"
}

$defines = @(
  "SUPABASE_URL=$supabaseUrl",
  "SUPABASE_ANON_KEY=$supabaseAnonKey",
  "SMARTKIT_API_BASE_URL=$apiBaseUrl"
)

if (
  $values.ContainsKey("SMARTKIT_FAMILY_INVITE_BASE_URL") -and
  -not [string]::IsNullOrWhiteSpace($values["SMARTKIT_FAMILY_INVITE_BASE_URL"])
) {
  $defines += "SMARTKIT_FAMILY_INVITE_BASE_URL=$($values["SMARTKIT_FAMILY_INVITE_BASE_URL"])"
}

$flutter = "D:\dev\flutter\bin\flutter.bat"
if (-not (Test-Path -LiteralPath $flutter)) {
  $flutter = "flutter"
}

$javaHome = "D:\dev\jdk17"
if (Test-Path -LiteralPath $javaHome) {
  $env:JAVA_HOME = $javaHome
}

$androidSdk = "D:\dev\android-sdk"
if (Test-Path -LiteralPath $androidSdk) {
  $env:ANDROID_HOME = $androidSdk
  $env:ANDROID_SDK_ROOT = $androidSdk
}

$pathParts = @(
  "D:\dev\jdk17\bin",
  "D:\dev\android-sdk\cmdline-tools\latest\bin",
  "D:\dev\android-sdk\platform-tools",
  "D:\dev\flutter\bin",
  "C:\Program Files\Git\cmd"
) | Where-Object { Test-Path -LiteralPath $_ }
$env:Path = ($pathParts -join ";") + ";" + $env:Path

$defineArgs = $defines | ForEach-Object { "--dart-define=$_" }

Push-Location $repoRoot
try {
  Write-Host "Running flutter pub get..."
  & $flutter pub get

  if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get failed"
  }

  Write-Host "Building Android $Target with public Dart defines from .env..."
  if ($Target -eq "apk" -or $Target -eq "both") {
    & $flutter build apk --release @defineArgs
    if ($LASTEXITCODE -ne 0) {
      throw "flutter build apk failed"
    }

    $apk = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-release.apk"
    $namedApk = Join-Path $repoRoot "build\app\outputs\flutter-apk\SmartKit-release.apk"
    Copy-Item -LiteralPath $apk -Destination $namedApk -Force
    Write-Host "APK ready: $namedApk"
  }

  if ($Target -eq "appbundle" -or $Target -eq "both") {
    & $flutter build appbundle --release @defineArgs
    if ($LASTEXITCODE -ne 0) {
      throw "flutter build appbundle failed"
    }

    $bundle = Join-Path $repoRoot "build\app\outputs\bundle\release\app-release.aab"
    Write-Host "App bundle ready: $bundle"
  }
} finally {
  Pop-Location
}
