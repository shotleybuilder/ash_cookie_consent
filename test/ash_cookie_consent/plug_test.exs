defmodule AshCookieConsent.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias AshCookieConsent.Cookie
  alias AshCookieConsent.Plug, as: ConsentPlug

  describe "init/1" do
    test "initializes with default options" do
      config = ConsentPlug.init(resource: TestResource)

      assert config.resource == TestResource
      assert config.cookie_name == "_consent"
      assert config.session_key == "consent"
      assert config.user_id_key == :current_user_id
    end

    test "accepts custom cookie name" do
      config = ConsentPlug.init(resource: TestResource, cookie_name: "my_consent")

      assert config.cookie_name == "my_consent"
    end

    test "accepts custom session key" do
      config = ConsentPlug.init(resource: TestResource, session_key: "my_consent_key")

      assert config.session_key == "my_consent_key"
    end

    test "accepts custom user_id_key" do
      config = ConsentPlug.init(resource: TestResource, user_id_key: :user_id)

      assert config.user_id_key == :user_id
    end

    test "allows optional resource for lightweight cookie-only mode" do
      config = ConsentPlug.init([])

      assert config.resource == nil
      assert config.cookie_name == "_consent"
      assert config.session_key == "consent"
    end

    test "accepts skip_session_cache option" do
      config = ConsentPlug.init(resource: TestResource, skip_session_cache: true)

      assert config.skip_session_cache == true
    end

    test "defaults skip_session_cache to false" do
      config = ConsentPlug.init(resource: TestResource)

      assert config.skip_session_cache == false
    end
  end

  describe "call/2" do
    test "sets consent assign when cookie exists" do
      consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{"_consent" => json})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert conn.assigns.consent["terms"] == "v1.0"
      assert conn.assigns.consent["groups"] == ["essential"]
    end

    test "sets show_consent_modal to false when consent exists" do
      consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{"_consent" => json})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert conn.assigns.show_consent_modal == false
    end

    test "sets show_consent_modal to true when no consent exists" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert conn.assigns.show_consent_modal == true
    end

    test "sets cookie_groups assign" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert is_list(conn.assigns.cookie_groups)
      assert length(conn.assigns.cookie_groups) > 0
    end

    test "uses custom cookie name from config" do
      consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{"my_consent" => json})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource, cookie_name: "my_consent"))

      assert conn.assigns.consent["terms"] == "v1.0"
    end

    test "uses custom session key from config" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{"my_session_key" => consent})
        |> ConsentPlug.call(
          ConsentPlug.init(resource: TestResource, session_key: "my_session_key")
        )

      assert conn.assigns.consent == consent
    end

    test "handles nil consent gracefully" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert conn.assigns.consent == nil
      assert conn.assigns.show_consent_modal == true
    end

    test "loads consent from session when available" do
      consent = %{"terms" => "v1.0", "groups" => ["essential", "analytics"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{"consent" => consent})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert conn.assigns.consent == consent
      assert conn.assigns.show_consent_modal == false
    end

    test "prioritizes session over cookie" do
      session_consent = %{"terms" => "v2.0", "groups" => ["analytics"]}
      cookie_consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(cookie_consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{"consent" => session_consent})
        |> Map.put(:req_cookies, %{"_consent" => json})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      # Should use session consent (higher priority)
      assert conn.assigns.consent["terms"] == "v2.0"
    end

    test "handles malformed cookie gracefully" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{"_consent" => "invalid json"})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert conn.assigns.consent == nil
      assert conn.assigns.show_consent_modal == true
    end

    test "sets consent in session for performance" do
      consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{"_consent" => json})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      # Session should be populated
      session_consent = get_session(conn, "consent")
      assert session_consent["terms"] == "v1.0"
    end

    test "skips session cache when skip_session_cache is true" do
      consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{"_consent" => json})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource, skip_session_cache: true))

      # Session should NOT be populated
      session_consent = get_session(conn, "consent")
      assert session_consent == nil

      # But consent should still be in assigns (from cookie)
      assert conn.assigns.consent["terms"] == "v1.0"
    end

    test "still reads from session when skip_session_cache is true" do
      # skip_session_cache only prevents WRITING to session, not reading
      session_consent = %{"terms" => "v2.0", "groups" => ["analytics"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{"consent" => session_consent})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource, skip_session_cache: true))

      # Should still read from session if it's already there
      assert conn.assigns.consent["terms"] == "v2.0"
    end
  end

  describe "should_show_modal?/1" do
    test "returns false when consent has groups" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{})
        |> assign(:consent, consent)
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert conn.assigns.show_consent_modal == false
    end

    test "returns true when consent is nil" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert conn.assigns.show_consent_modal == true
    end

    test "returns true when consent is empty map" do
      conn =
        conn(:get, "/")
        |> init_test_session(%{"consent" => %{}})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert conn.assigns.show_consent_modal == true
    end

    test "returns true when groups is empty list" do
      consent = %{"terms" => "v1.0", "groups" => []}

      conn =
        conn(:get, "/")
        |> init_test_session(%{"consent" => consent})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert conn.assigns.show_consent_modal == true
    end

    test "returns true when groups is nil" do
      consent = %{"terms" => "v1.0", "groups" => nil}

      conn =
        conn(:get, "/")
        |> init_test_session(%{"consent" => consent})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      assert conn.assigns.show_consent_modal == true
    end
  end

  describe "integration with Storage" do
    test "loads consent from cookie via Storage" do
      consent = %{terms: "v1.0", groups: ["essential", "analytics"]}
      {:ok, json} = Cookie.encode_consent(consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{"_consent" => json})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      # Should have loaded from cookie
      assert conn.assigns.consent["terms"] == "v1.0"
      assert conn.assigns.consent["groups"] == ["essential", "analytics"]
    end

    test "stores consent in session after loading from cookie" do
      consent = %{terms: "v1.0", groups: ["essential"]}
      {:ok, json} = Cookie.encode_consent(consent)

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Map.put(:req_cookies, %{"_consent" => json})
        |> ConsentPlug.call(ConsentPlug.init(resource: TestResource))

      # Should now be in session for next request
      session_consent = get_session(conn, "consent")
      assert session_consent["terms"] == "v1.0"
    end
  end
end

# Dummy test resource
defmodule TestResource do
end
