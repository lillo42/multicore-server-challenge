import Config

# Runtime contract (SPEC.md): DATABASE_URL, JWT_SECRET, HOST, PORT.
# Evaluated at release boot (and once at build time by `mix release`, where
# build.sh exports placeholders).
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "environment variable DATABASE_URL is missing"

  jwt_secret =
    System.get_env("JWT_SECRET") ||
      raise "environment variable JWT_SECRET is missing"

  host = System.get_env("HOST") || "127.0.0.1"
  port = String.to_integer(System.get_env("PORT") || "3000")

  {:ok, ip} = :inet.parse_address(String.to_charlist(host))

  config :conduit, Conduit.Repo,
    url: database_url,
    # Postgres on the box has max_connections = 100; stay under 95 (rule: shared box).
    pool_size: 90,
    # No query logging in prod: it costs real throughput.
    log: false,
    timeout: 15_000

  config :conduit, :jwt_secret, jwt_secret

  config :conduit, ConduitWeb.Endpoint,
    http: [
      ip: ip,
      port: port,
      # Behind the benchmark Nginx, upstream keep-alive is 60 s; keep idle
      # connections open well past that so Nginx never reuses a closing socket.
      thousand_island_options: [read_timeout: 90_000]
    ],
    secret_key_base: String.pad_trailing(jwt_secret, 64, "."),
    server: true
end
