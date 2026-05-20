# SmartKit Supabase/PostgreSQL

This folder contains the PostgreSQL schema and Edge Functions for the SmartKit
Supabase backend.

## Local or hosted setup

1. Create a Supabase project or start local Supabase.
2. Apply migrations from `supabase/migrations`.
3. Copy `.env.example` to `.env` locally and provide values through
   `--dart-define-from-file=.env` or explicit `--dart-define` flags when
   running Flutter.

Flutter example:

```bash
flutter run -d chrome \
  --dart-define-from-file=.env
```

## Architecture

Flutter authenticates through Supabase Auth, reads and writes PostgreSQL through
RLS-protected tables, and calls Edge Functions for AI and transactional server
workflows.

## Edge Functions

Initial server-side functions are included in `supabase/functions`:

- `health` - deployment smoke test.
- `ai-chat` - generic Ollama/Qwen3 chat gateway.
- `business-analysis` - authenticated B2B analysis that reads organization
  data from PostgreSQL, then calls Ollama/Qwen3.

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are
reserved Supabase Edge Function secrets and are available automatically in the
hosted runtime. Set only the AI gateway secrets before production AI usage:

```bash
supabase secrets set \
  OLLAMA_BASE_URL=https://your-ollama-proxy.example.com \
  OLLAMA_MODEL=qwen3:latest \
  OLLAMA_API_KEY=$OLLAMA_PROXY_TOKEN
```

Deploy example:

```bash
supabase functions deploy health --use-api --no-verify-jwt
supabase functions deploy ai-chat business-analysis --use-api
```
