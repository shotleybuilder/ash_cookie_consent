defmodule AshCookieConsent.CookieTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias AshCookieConsent.Cookie

  describe "encode_consent/1" do
    test "encodes a valid consent map to JSON" do
      consent = %{
        terms: "v1.0",
        groups: ["essential", "analytics"]
      }

      assert {:ok, json} = Cookie.encode_consent(consent)
      assert is_binary(json)

      # Verify it's valid JSON
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded["terms"] == "v1.0"
      assert decoded["groups"] == ["essential", "analytics"]
    end

    test "encodes DateTime values to ISO8601 format" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      consent = %{
        terms: "v1.0",
        groups: ["essential"],
        consented_at: now
      }

      assert {:ok, json} = Cookie.encode_consent(consent)
      assert {:ok, decoded} = Jason.decode(json)

      # DateTime should be encoded as ISO8601 string
      assert is_binary(decoded["consented_at"])
      assert {:ok, _dt, _offset} = DateTime.from_iso8601(decoded["consented_at"])
    end

    test "converts atom keys to string keys" do
      consent = %{
        terms: "v1.0",
        groups: ["essential"]
      }

      assert {:ok, json} = Cookie.encode_consent(consent)
      assert {:ok, decoded} = Jason.decode(json)

      # Keys should be strings
      assert Map.has_key?(decoded, "terms")
      assert Map.has_key?(decoded, "groups")
    end

    test "returns error for nil consent" do
      assert {:error, :invalid_consent} = Cookie.encode_consent(nil)
    end

    test "returns error for invalid consent" do
      assert {:error, :invalid_consent} = Cookie.encode_consent("not a map")
      assert {:error, :invalid_consent} = Cookie.encode_consent(123)
    end
  end

  describe "decode_consent/1" do
    test "decodes valid JSON to consent map" do
      json = ~s({"terms":"v1.0","groups":["essential","analytics"]})

      assert {:ok, consent} = Cookie.decode_consent(json)
      assert consent["terms"] == "v1.0"
      assert consent["groups"] == ["essential", "analytics"]
    end

    test "decodes ISO8601 timestamps to DateTime structs" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      iso_string = DateTime.to_iso8601(now)

      json = ~s({"terms":"v1.0","groups":["essential"],"consented_at":"#{iso_string}"})

      assert {:ok, consent} = Cookie.decode_consent(json)
      assert %DateTime{} = consent["consented_at"]
      assert DateTime.compare(consent["consented_at"], now) == :eq
    end

    test "returns ok with nil for nil input" do
      assert {:ok, nil} = Cookie.decode_consent(nil)
    end

    test "returns ok with nil for empty string" do
      assert {:ok, nil} = Cookie.decode_consent("")
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = Cookie.decode_consent("not json")
      assert {:error, _} = Cookie.decode_consent("{invalid}")
    end

    test "returns error for non-string input" do
      assert {:error, :invalid_format} = Cookie.decode_consent(123)
      assert {:error, :invalid_format} = Cookie.decode_consent(%{})
    end

    test "handles malformed timestamp gracefully" do
      json = ~s({"terms":"v1.0","consented_at":"not-a-date"})

      assert {:ok, consent} = Cookie.decode_consent(json)
      # Should not crash, just keep as string
      assert consent["consented_at"] == "not-a-date"
    end
  end

  describe "put_consent/3" do
    test "sets consent cookie on connection" do
      conn = conn(:get, "/")
      consent = %{terms: "v1.0", groups: ["essential"]}

      conn = Cookie.put_consent(conn, consent)

      # Cookie should be in resp_cookies
      assert Map.has_key?(conn.resp_cookies, "_consent")
      cookie = conn.resp_cookies["_consent"]

      assert cookie.value
      assert {:ok, decoded} = Cookie.decode_consent(cookie.value)
      assert decoded["terms"] == "v1.0"
    end

    test "uses custom cookie name when provided" do
      conn = conn(:get, "/")
      consent = %{terms: "v1.0", groups: ["essential"]}

      conn = Cookie.put_consent(conn, consent, cookie_name: "my_consent")

      assert Map.has_key?(conn.resp_cookies, "my_consent")
      refute Map.has_key?(conn.resp_cookies, "_consent")
    end

    test "sets correct cookie options" do
      conn = conn(:get, "/")
      consent = %{terms: "v1.0", groups: ["essential"]}

      conn = Cookie.put_consent(conn, consent)

      cookie = conn.resp_cookies["_consent"]

      # Default options
      # 1 year
      assert cookie.max_age == 365 * 24 * 60 * 60
      assert cookie.http_only == false
      assert cookie.same_site == "Lax"
    end

    test "allows custom max_age" do
      conn = conn(:get, "/")
      consent = %{terms: "v1.0", groups: ["essential"]}
      # 30 days
      custom_max_age = 30 * 24 * 60 * 60

      conn = Cookie.put_consent(conn, consent, max_age: custom_max_age)

      cookie = conn.resp_cookies["_consent"]
      assert cookie.max_age == custom_max_age
    end

    test "handles encoding errors gracefully" do
      conn = conn(:get, "/")
      # This should not crash even with weird consent data
      conn = Cookie.put_consent(conn, nil)

      # Should not have set a cookie
      refute Map.has_key?(conn.resp_cookies, "_consent")
    end
  end

  describe "get_consent/2" do
    test "retrieves consent from cookie" do
      consent = %{terms: "v1.0", groups: ["essential", "analytics"]}
      {:ok, json} = Cookie.encode_consent(consent)

      conn =
        conn(:get, "/")
        |> Map.put(:req_cookies, %{"_consent" => json})

      result = Cookie.get_consent(conn)

      assert result["terms"] == "v1.0"
      assert result["groups"] == ["essential", "analytics"]
    end

    test "returns nil when cookie doesn't exist" do
      conn = conn(:get, "/")

      assert Cookie.get_consent(conn) == nil
    end

    test "returns nil when cookie value is invalid JSON" do
      conn =
        conn(:get, "/")
        |> Map.put(:req_cookies, %{"_consent" => "invalid json"})

      assert Cookie.get_consent(conn) == nil
    end

    test "uses custom cookie name when provided" do
      consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(consent)

      conn =
        conn(:get, "/")
        |> Map.put(:req_cookies, %{"my_consent" => json})

      result = Cookie.get_consent(conn, cookie_name: "my_consent")

      assert result["terms"] == "v1.0"
    end
  end

  describe "delete_consent/2" do
    test "deletes the consent cookie" do
      conn = conn(:get, "/")

      conn = Cookie.delete_consent(conn)

      # Should have delete instruction in resp_cookies
      assert Map.has_key?(conn.resp_cookies, "_consent")
      assert conn.resp_cookies["_consent"].max_age == 0
    end

    test "deletes custom cookie name when provided" do
      conn = conn(:get, "/")

      conn = Cookie.delete_consent(conn, cookie_name: "my_consent")

      assert Map.has_key?(conn.resp_cookies, "my_consent")
      assert conn.resp_cookies["my_consent"].max_age == 0
    end
  end

  describe "has_consent?/2" do
    test "returns true when valid consent cookie exists" do
      consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(consent)

      conn =
        conn(:get, "/")
        |> Map.put(:req_cookies, %{"_consent" => json})

      assert Cookie.has_consent?(conn) == true
    end

    test "returns false when no consent cookie exists" do
      conn = conn(:get, "/")

      assert Cookie.has_consent?(conn) == false
    end

    test "returns false when consent cookie is invalid" do
      conn =
        conn(:get, "/")
        |> Map.put(:req_cookies, %{"_consent" => "invalid"})

      assert Cookie.has_consent?(conn) == false
    end

    test "returns false when consent is empty map" do
      {:ok, json} = Cookie.encode_consent(%{})

      conn =
        conn(:get, "/")
        |> Map.put(:req_cookies, %{"_consent" => json})

      assert Cookie.has_consent?(conn) == false
    end
  end

  describe "round-trip encoding/decoding" do
    test "preserves all consent fields" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      expires = DateTime.add(now, 365, :day) |> DateTime.truncate(:second)

      original = %{
        terms: "v1.0",
        groups: ["essential", "analytics", "marketing"],
        consented_at: now,
        expires_at: expires
      }

      assert {:ok, json} = Cookie.encode_consent(original)
      assert {:ok, decoded} = Cookie.decode_consent(json)

      assert decoded["terms"] == "v1.0"
      assert decoded["groups"] == ["essential", "analytics", "marketing"]
      assert %DateTime{} = decoded["consented_at"]
      assert %DateTime{} = decoded["expires_at"]
      assert DateTime.compare(decoded["consented_at"], now) == :eq
      assert DateTime.compare(decoded["expires_at"], expires) == :eq
    end
  end
end
