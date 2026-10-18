#!/usr/bin/env bash
# Builds the app as a normal user: deps (pinned by mix.lock) -> prod release. Idempotent.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="/usr/local/elixir/bin:/usr/local/bin:$PATH"

mix local.hex --force
mix local.rebar --force

export MIX_ENV=prod
mix deps.get --only prod
mix compile

# runtime.exs is evaluated once during release assembly; the real values are
# re-read from the environment when the release boots (start.sh).
DATABASE_URL="postgres://build:build@127.0.0.1:5432/build" \
JWT_SECRET="build-time-placeholder" \
HOST=127.0.0.1 PORT=3000 \
  mix release --overwrite

echo "built _build/prod/rel/conduit ($(elixir --version | tail -1))"
