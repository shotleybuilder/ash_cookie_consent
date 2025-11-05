defmodule AshCookieConsent.StorageTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias AshCookieConsent.Cookie
  alias AshCookieConsent.Storage

  describe "get_consent/2" do
    test "returns consent from assigns when available" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> assign(:consent, consent)

      assert Storage.get_consent(conn) == consent
    end

    test "returns consent from session when assigns is nil" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{"consent" => consent})

      assert Storage.get_consent(conn) == consent
    end

    test "returns consent from cookie when assigns and session are nil" do
      consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{"_consent" => json})

      result = Storage.get_consent(conn)
      assert result["terms"] == "v1.0"
      assert result["groups"] == ["essential"]
    end

    test "returns nil when no consent in any tier" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{})

      assert Storage.get_consent(conn) == nil
    end

    test "prioritizes assigns over session" do
      assigns_consent = %{"terms" => "v2.0", "groups" => ["analytics"]}
      session_consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> assign(:consent, assigns_consent)
        |> init_test_session(%{"consent" => session_consent})

      # Should return assigns consent (higher priority)
      assert Storage.get_consent(conn) == assigns_consent
    end

    test "prioritizes session over cookie" do
      session_consent = %{"terms" => "v2.0", "groups" => ["analytics"]}
      cookie_consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(cookie_consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{"consent" => session_consent})
        |> Map.put(:req_cookies, %{"_consent" => json})

      # Should return session consent (higher priority)
      assert Storage.get_consent(conn) == session_consent
    end

    test "uses custom session key when provided" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{"my_consent" => consent})

      result = Storage.get_consent(conn, session_key: "my_consent")
      assert result == consent
    end
  end

  describe "put_consent/3" do
    test "sets consent in assigns" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.put_consent(consent)

      assert conn.assigns.consent == consent
    end

    test "sets consent in session" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.put_consent(consent)

      assert get_session(conn, "consent") == consent
    end

    test "sets consent in cookie" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.put_consent(consent)

      # Cookie should be set in resp_cookies
      assert Map.has_key?(conn.resp_cookies, "_consent")
      cookie = conn.resp_cookies["_consent"]

      # Decode and verify
      {:ok, decoded} = Cookie.decode_consent(cookie.value)
      assert decoded["terms"] == "v1.0"
    end

    test "uses custom cookie name when provided" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.put_consent(consent, cookie_name: "my_consent")

      assert Map.has_key?(conn.resp_cookies, "my_consent")
      refute Map.has_key?(conn.resp_cookies, "_consent")
    end

    test "uses custom session key when provided" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.put_consent(consent, session_key: "my_consent")

      assert get_session(conn, "my_consent") == consent
    end

    test "skips database when user not authenticated" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.put_consent(consent, resource: DummyResource)

      # Should not crash even though no user_id in assigns
      assert conn.assigns.consent == consent
    end

    test "skips database when skip_database option is true" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> assign(:current_user_id, "user123")
        |> Storage.put_consent(consent, resource: DummyResource, skip_database: true)

      # Should still set consent but not attempt database save
      assert conn.assigns.consent == consent
    end
  end

  describe "delete_consent/2" do
    test "removes consent from assigns" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> assign(:consent, consent)
        |> Storage.delete_consent()

      assert Map.get(conn.assigns, :consent) == nil
    end

    test "removes consent from session" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{"consent" => consent})
        |> Storage.delete_consent()

      assert get_session(conn, "consent") == nil
    end

    test "sets cookie deletion (max_age: 0)" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.delete_consent()

      # Should have delete instruction
      assert Map.has_key?(conn.resp_cookies, "_consent")
      assert conn.resp_cookies["_consent"].max_age == 0
    end

    test "uses custom cookie name when provided" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.delete_consent(cookie_name: "my_consent")

      assert Map.has_key?(conn.resp_cookies, "my_consent")
      assert conn.resp_cookies["my_consent"].max_age == 0
    end

    test "uses custom session key when provided" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{"my_consent" => %{"terms" => "v1.0"}})
        |> Storage.delete_consent(session_key: "my_consent")

      assert get_session(conn, "my_consent") == nil
    end
  end

  describe "sync_on_login/2" do
    test "merges cookie consent when no database consent exists" do
      cookie_consent = %{terms: "v1.0", groups: ["essential", "analytics"]}
      {:ok, json} = Cookie.encode_consent(cookie_consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{"_consent" => json})
        |> Storage.sync_on_login(resource: DummyResource, user_id: "user123")

      # Should have consent in assigns
      assert conn.assigns.consent["terms"] == "v1.0"
      assert conn.assigns.consent["groups"] == ["essential", "analytics"]
    end

    test "handles missing cookie consent gracefully" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.sync_on_login(resource: DummyResource, user_id: "user123")

      # Should not crash, consent should be nil
      assert conn.assigns.consent == nil
    end
  end

  describe "sync_from_database/2" do
    test "handles no database consent gracefully" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{})

      result = Storage.sync_from_database(conn, resource: DummyResource, user_id: "user123")

      # Should return unchanged conn when no DB consent
      assert result == conn
    end
  end

  describe "merge_consents/2 (via sync_on_login)" do
    test "prefers cookie consent when database consent is nil" do
      cookie_consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(cookie_consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{"_consent" => json})
        |> Storage.sync_on_login(resource: DummyResource, user_id: "user123")

      assert conn.assigns.consent["terms"] == "v1.0"
    end

    test "handles both consents being nil" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.sync_on_login(resource: DummyResource, user_id: "user123")

      assert conn.assigns.consent == nil
    end
  end

  describe "three-tier integration" do
    test "full write-then-read cycle" do
      consent = %{"terms" => "v1.0", "groups" => ["essential", "analytics"]}

      # Write to all tiers
      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.put_consent(consent)

      # Verify we can read back from assigns
      assert Storage.get_consent(conn) == consent

      # Verify each tier individually
      assert conn.assigns.consent == consent
      assert get_session(conn, "consent") == consent
      assert Map.has_key?(conn.resp_cookies, "_consent")
    end

    test "delete removes from all tiers" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Storage.put_consent(consent)
        |> Storage.delete_consent()

      # Verify all tiers are cleared
      assert Map.get(conn.assigns, :consent) == nil
      assert get_session(conn, "consent") == nil
      assert conn.resp_cookies["_consent"].max_age == 0
    end
  end
end

# Dummy module for testing
defmodule DummyResource do
end
