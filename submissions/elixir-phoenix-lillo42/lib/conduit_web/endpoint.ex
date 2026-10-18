defmodule ConduitWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :conduit

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug ConduitWeb.Router
end
