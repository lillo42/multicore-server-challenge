#!/usr/bin/env bash
# Runs the server in the foreground. Config comes only from the environment
# (DATABASE_URL, JWT_SECRET, HOST, PORT) via config/runtime.exs.
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/_build/prod/rel/conduit/bin/conduit" start
