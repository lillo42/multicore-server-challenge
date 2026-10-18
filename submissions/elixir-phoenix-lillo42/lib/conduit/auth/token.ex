defmodule Conduit.Auth.Token do
  @moduledoc """
  JWT HS256, signed with JWT_SECRET. Claims: {"sub": "<user id, decimal string>",
  "iat": now, "exp": now + 30 days}. Every request verifies the signature, the
  alg and exp - there is no verification cache.
  """

  @ttl_seconds 30 * 86_400

  def sign(user_id, secret) do
    now = System.system_time(:second)
    header = b64(Jason.encode!(%{"alg" => "HS256", "typ" => "JWT"}))
    payload = b64(Jason.encode!(%{"sub" => Integer.to_string(user_id), "iat" => now, "exp" => now + @ttl_seconds}))
    header <> "." <> payload <> "." <> b64(mac(secret, header <> "." <> payload))
  end

  @doc "{:ok, user_id} | :error - any deviation (format, alg, signature, exp) is :error."
  def verify(token, secret) when is_binary(token) do
    with [header, payload, sig] <- String.split(token, "."),
         {:ok, %{"alg" => "HS256"}} <- decode_json(header),
         true <- secure_compare(b64(mac(secret, header <> "." <> payload)), sig),
         {:ok, claims} <- decode_json(payload),
         true <- valid_exp?(claims["exp"]),
         {:ok, user_id} <- parse_sub(claims["sub"]) do
      {:ok, user_id}
    else
      _ -> :error
    end
  end

  def verify(_, _), do: :error

  defp mac(secret, data), do: :crypto.mac(:hmac, :sha256, secret, data)

  defp b64(bin), do: Base.url_encode64(bin, padding: false)

  defp decode_json(part) do
    with {:ok, raw} <- Base.url_decode64(part, padding: false),
         {:ok, json} <- Jason.decode(raw) do
      {:ok, json}
    else
      _ -> :error
    end
  end

  defp valid_exp?(exp) when is_integer(exp), do: exp > System.system_time(:second)
  defp valid_exp?(_), do: false

  defp parse_sub(sub) when is_binary(sub) do
    case Integer.parse(sub) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> :error
    end
  end

  defp parse_sub(sub) when is_integer(sub) and sub > 0, do: {:ok, sub}
  defp parse_sub(_), do: :error

  defp secure_compare(a, b) when is_binary(a) and is_binary(b) and byte_size(a) == byte_size(b),
    do: Plug.Crypto.secure_compare(a, b)

  defp secure_compare(_, _), do: false
end
