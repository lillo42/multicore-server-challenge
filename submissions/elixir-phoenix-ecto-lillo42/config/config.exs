import Config

config :conduit, ConduitWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [formats: [json: ConduitWeb.ErrorJSON], layout: false]

config :phoenix, :json_library, Jason

config :logger, level: :warning

import_config "#{config_env()}.exs"
