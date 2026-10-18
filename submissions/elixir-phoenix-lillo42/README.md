# Conduit - Elixir / Phoenix / Postgrex

The RealWorld "Conduit" backend (SPEC.md) as a standard Phoenix application talking
to Postgres directly through Postgrex (no ORM).

| | |
|---|---|
| Language | Elixir 1.20.4 |
| Runtime | Erlang/OTP 29.1.2 |
| Framework | Phoenix 1.8.15 |
| HTTP server | Bandit 1.13.1 (Phoenix's default adapter) |
| Database driver | Postgrex 0.22.4 (DBConnection pool) |
| Password hashing | bcrypt_elixir 3.3.2, cost 10 |
| JWT | HS256 via `:crypto` (see `lib/conduit/auth/token.ex`) |

**Front: nginx**

## Layout

Standard Phoenix API app (no assets/HTML/LiveView):

- `lib/conduit/application.ex` - supervision tree: Postgrex pool + `ConduitWeb.Endpoint`
- `lib/conduit/db.ex` - query helpers over the Postgrex pool (transaction-aware)
- `lib/conduit/accounts.ex` - users, auth, profiles, follows
- `lib/conduit/blog.ex` - articles, feed, comments, favorites, tags
- `lib/conduit/auth/token.ex` - JWT HS256 sign/verify
- `lib/conduit_web/` - endpoint, router, auth plug, controllers (users, profiles, articles, comments, tags)

## Design choices

- **Postgrex directly, no ORM.** The schema is fixed by the rules and SPEC.md defines correctness as
  reference SQL (lateral joins, array subselects, EXISTS viewer flags, capped counts, Postgres-side
  SLUGIFY), so every statement is parameterized SQL run through Postgrex. That is byte-for-byte
  auditable against the spec and skips the ORM's query planning/mapping overhead on hot paths.
- **No caching anywhere.** Every request runs its SQL against Postgres while being served (rule 5).
  No ETS, no GenServer state, no `:persistent_term`, no JWT/bcrypt memoization. The only "caches" are
  the DBConnection pool and per-connection prepared statements, both explicitly allowed.
- **Pool size 90.** Postgres on the box has `max_connections = 100`; one BEAM node with a pool of 90
  stays under the cap with headroom.
- **Transactions thread the connection explicitly** (`Postgrex.transaction`), so statements inside a
  transaction can never escape it onto another pooled connection.
- **Keep-alive 90 s** (`thousand_island_options: [read_timeout: 90_000]`) so Nginx's 60 s upstream
  keep-alive never reuses a socket we're closing.
- **bcrypt on dirty schedulers.** bcrypt_elixir is a NIF flagged for dirty-CPU scheduling, so login
  bursts don't block the BEAM's normal schedulers; OTP 29's scheduler handles this mix well.
- **Bandit** holds keep-alive connections cheaply (one lightweight process per connection), which is
  what the workload's ~7 s think times need.
- No query logging - Postgrex doesn't log queries by default.

## Scripts

- `install.sh` - root, clean Ubuntu 24.04: Erlang/OTP 29.1.2 (official precompiled build for
  ubuntu-24.04 from repo.hex.pm) + Elixir 1.20.4 (official precompiled zip for OTP 29) into
  `/usr/local`, plus the C toolchain for the bcrypt NIF.
- `build.sh` - `mix deps.get --only prod` (direct deps pinned exactly in `mix.exs`) and
  `MIX_ENV=prod mix release`. Note: run `mix deps.get` once locally and commit the generated
  `mix.lock` before opening the PR upstream, so transitive deps are pinned too.
- `start.sh` - runs the release in the foreground; configured only by `DATABASE_URL`, `JWT_SECRET`,
  `HOST`, `PORT` (`config/runtime.exs`).

## Local check

```bash
sudo bash install.sh
bash build.sh
bash test/run.sh submissions/elixir-phoenix-lillo42   # from the repo root
```
