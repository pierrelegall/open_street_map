defmodule OpenStreetMap do
  @moduledoc """
  Functions for requests to OpenStreetMap API
  """

  @doc """
  Search objects by query
  """
  @spec search(keyword()) :: tuple()

  def search(args) do
    call("search", args)
  end

  @doc """
  Reverse geocoding generates an address from a latitude and longitude
  """
  @spec reverse(keyword()) :: tuple()

  def reverse(args) do
    call("reverse", args)
  end

  defp call(type, args) do
    type
    |> generate_url(args)
    |> prepare_url(type)
    |> fetch(args)
    |> parse(args[:format])
  end

  defp generate_url(type, args) do
    Enum.filter(args, fn({key, _value}) -> Enum.member?(valid_args(type), key) end)
    |> List.foldl("", fn({key, value}, acc) -> acc <> add_to_options(key, to_string(value), acc) end)
  end

  defp valid_args(type) do
    case type do
      "search" -> [:q, :format, :addressdetails, :extratags, :namedetails, :viewbox, :bounded, :exclude_place_ids, :limit, :accept_language, :email]
      "reverse" -> [:format, :lat, :lon, :zoom, :addressdetails, :extratags, :namedetails, :accept_language, :email]
      _ -> []
    end
  end

  defp add_to_options(key, value, "") do
    "?" <> key_value_param(key, modify_search(value))
  end

  defp add_to_options(key, value, _acc) do
    "&" <> key_value_param(key, modify_search(value))
  end

  defp modify_search(value) do
    String.replace(value, ~r/\s+/, "+")
  end

  defp key_value_param(:accept_language, value) do
    "accept-language=" <> value
  end

  defp key_value_param(key, value) do
    "#{key}=#{value}"
  end

  defp prepare_url(url, type) do
    type <> url
  end

  defp fetch(url, args) do
    base_url = args[:hostname] || "https://nominatim.openstreetmap.org/"
    headers = [{"Content-Type", "application/json"}, {"User-Agent", user_agent(args[:user_agent])}, {"Accept", "Application/json; Charset=utf-8"}]
    options = [ssl: [{:versions, [:'tlsv1.2']}], recv_timeout: 500]
    case HTTPoison.get(base_url <> url, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> {:ok, body}
      {:ok, %HTTPoison.Response{status_code: 400, body: body}} -> {:error, body}
      {:ok, %HTTPoison.Response{status_code: 404}} -> {:error, "Page not found"}
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
    end
  end

  defp parse({result, response}, format) when result == :ok do
    if parse_valid?(format) do
      {:ok, Poison.Parser.parse!(response)}
    else
      {:ok, response}
    end
  end

  defp parse(response, _format) do
    response
  end

  defp parse_valid?(format) do
    format == "json" || format == "jsonv2"
  end

  defp user_agent(nil) do
    "hex/open_street_map/#{random_string(16)}"
  end

  defp user_agent(value) do
    value
  end

  defp random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64
    |> binary_part(0, length)
  end
end
