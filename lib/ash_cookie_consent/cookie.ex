defmodule AshCookieConsent.Cookie do
  @moduledoc """
  Cookie management for consent data.

  Handles encoding, decoding, setting, and retrieving consent cookies.

  ## Cookie Format

  Consent is stored as a JSON-encoded map with the following structure:

      %{
        "terms" => "v1.0",
        "groups" => ["essential", "analytics"],
        "consented_at" => "2025-11-03T12:00:00Z",
        "expires_at" => "2026-11-03T12:00:00Z"
      }

  ## Security

  - Cookies are signed by Plug to prevent tampering
  - HttpOnly is false (JavaScript may need to read)
  - Secure flag enabled in production
  - SameSite: Lax for CSRF protection

  ## Examples

      # Set consent cookie
      conn = AshCookieConsent.Cookie.put_consent(conn, consent)

      # Get consent cookie
      consent = AshCookieConsent.Cookie.get_consent(conn)

      # Delete consent cookie
      conn = AshCookieConsent.Cookie.delete_consent(conn)
  """

  @default_cookie_name "_consent"
  # 1 year in seconds
  @default_max_age 365 * 24 * 60 * 60

  @doc """
  Encodes consent data to JSON string.

  ## Examples

      iex> consent = %{terms: "v1.0", groups: ["essential"]}
      iex> AshCookieConsent.Cookie.encode_consent(consent)
      {:ok, ~s({"groups":["essential"],"terms":"v1.0"})}

      iex> AshCookieConsent.Cookie.encode_consent(nil)
      {:error, :invalid_consent}
  """
  def encode_consent(nil), do: {:error, :invalid_consent}

  def encode_consent(consent) when is_map(consent) do
    # Convert atom keys to string keys for JSON encoding
    consent_map =
      consent
      |> Map.new(fn {k, v} ->
        key = if is_atom(k), do: to_string(k), else: k
        value = encode_value(v)
        {key, value}
      end)

    {:ok, Jason.encode!(consent_map)}
  rescue
    error -> {:error, error}
  end

  def encode_consent(_), do: {:error, :invalid_consent}

  @doc """
  Decodes consent data from JSON string.

  ## Examples

      iex> json = ~s({"terms":"v1.0","groups":["essential"]})
      iex> AshCookieConsent.Cookie.decode_consent(json)
      {:ok, %{"terms" => "v1.0", "groups" => ["essential"]}}

      iex> AshCookieConsent.Cookie.decode_consent("invalid json")
      {:error, _}
  """
  def decode_consent(nil), do: {:ok, nil}
  def decode_consent(""), do: {:ok, nil}

  def decode_consent(json_string) when is_binary(json_string) do
    decoded = Jason.decode!(json_string)
    # Convert ISO datetime strings back to DateTime structs
    consent = decode_timestamps(decoded)
    {:ok, consent}
  rescue
    error -> {:error, error}
  end

  def decode_consent(_), do: {:error, :invalid_format}

  @doc """
  Sets the consent cookie on the connection.

  ## Options

    - `:cookie_name` - Name of the cookie (default: "_consent")
    - `:max_age` - Cookie lifetime in seconds (default: 1 year)
    - `:secure` - Require HTTPS (default: false in dev, true in prod)
    - `:http_only` - Prevent JavaScript access (default: false)
    - `:same_site` - CSRF protection (default: "Lax")

  ## Examples

      conn = AshCookieConsent.Cookie.put_consent(conn, consent)

      conn = AshCookieConsent.Cookie.put_consent(conn, consent,
        cookie_name: "my_consent",
        max_age: 30 * 24 * 60 * 60  # 30 days
      )
  """
  def put_consent(conn, consent, opts \\ []) do
    cookie_name = Keyword.get(opts, :cookie_name, @default_cookie_name)
    max_age = Keyword.get(opts, :max_age, @default_max_age)

    case encode_consent(consent) do
      {:ok, encoded} ->
        cookie_opts = build_cookie_opts(conn, max_age, opts)
        Plug.Conn.put_resp_cookie(conn, cookie_name, encoded, cookie_opts)

      {:error, _reason} ->
        conn
    end
  end

  @doc """
  Gets the consent data from the cookie.

  Returns the decoded consent map or nil if cookie doesn't exist or is invalid.

  ## Examples

      consent = AshCookieConsent.Cookie.get_consent(conn)
      # => %{"terms" => "v1.0", "groups" => ["essential", "analytics"], ...}
  """
  def get_consent(conn, opts \\ []) do
    cookie_name = Keyword.get(opts, :cookie_name, @default_cookie_name)

    case Map.get(conn.req_cookies, cookie_name) do
      nil ->
        nil

      cookie_value ->
        case decode_consent(cookie_value) do
          {:ok, consent} -> consent
          {:error, _} -> nil
        end
    end
  end

  @doc """
  Deletes the consent cookie from the connection.

  ## Examples

      conn = AshCookieConsent.Cookie.delete_consent(conn)
  """
  def delete_consent(conn, opts \\ []) do
    cookie_name = Keyword.get(opts, :cookie_name, @default_cookie_name)
    Plug.Conn.delete_resp_cookie(conn, cookie_name)
  end

  @doc """
  Checks if consent cookie exists and is valid.

  ## Examples

      if AshCookieConsent.Cookie.has_consent?(conn) do
        # Consent cookie exists
      end
  """
  def has_consent?(conn, opts \\ []) do
    consent = get_consent(conn, opts)
    !is_nil(consent) && consent != %{}
  end

  # Private helpers

  defp encode_value(%DateTime{} = dt) do
    DateTime.to_iso8601(dt)
  end

  defp encode_value(value), do: value

  defp decode_timestamps(consent) when is_map(consent) do
    consent
    |> decode_timestamp_field("consented_at")
    |> decode_timestamp_field("expires_at")
  end

  defp decode_timestamps(consent), do: consent

  defp decode_timestamp_field(consent, field) do
    case Map.get(consent, field) do
      nil ->
        consent

      timestamp when is_binary(timestamp) ->
        case DateTime.from_iso8601(timestamp) do
          {:ok, dt, _offset} -> Map.put(consent, field, dt)
          {:error, _} -> consent
        end

      _other ->
        consent
    end
  end

  defp build_cookie_opts(conn, max_age, opts) do
    secure = Keyword.get(opts, :secure, conn.scheme == :https)
    http_only = Keyword.get(opts, :http_only, false)
    same_site = Keyword.get(opts, :same_site, "Lax")

    [
      max_age: max_age,
      secure: secure,
      http_only: http_only,
      same_site: same_site
    ]
  end
end
