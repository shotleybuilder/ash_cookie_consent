defmodule AshCookieConsentHelpersTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias AshCookieConsent

  # Helper to build a conn with assigns
  defp build_conn(assigns \\ %{}) do
    conn(:get, "/")
    |> Map.put(:assigns, assigns)
  end

  describe "cookie_groups/0" do
    test "returns configured cookie groups" do
      groups = AshCookieConsent.cookie_groups()

      assert is_list(groups)
      assert length(groups) > 0
    end
  end

  describe "consent_given?/2" do
    test "returns true for essential cookies" do
      conn = build_conn()

      assert AshCookieConsent.consent_given?(conn, "essential")
    end

    test "returns true when consent exists and group is in list" do
      consent = %{groups: ["essential", "analytics"]}
      conn = build_conn(%{consent: consent})

      assert AshCookieConsent.consent_given?(conn, "analytics")
    end

    test "returns false when consent exists but group not in list" do
      consent = %{groups: ["essential"]}
      conn = build_conn(%{consent: consent})

      refute AshCookieConsent.consent_given?(conn, "marketing")
    end

    test "returns false when no consent exists" do
      conn = build_conn()

      refute AshCookieConsent.consent_given?(conn, "analytics")
    end

    test "returns false when consent is nil" do
      conn = build_conn(%{consent: nil})

      refute AshCookieConsent.consent_given?(conn, "analytics")
    end

    test "returns false when consent groups is nil" do
      consent = %{groups: nil}
      conn = build_conn(%{consent: consent})

      refute AshCookieConsent.consent_given?(conn, "analytics")
    end
  end

  describe "get_consent/1" do
    test "returns consent from assigns" do
      consent = %{terms: "v1.0", groups: ["essential", "analytics"]}
      conn = build_conn(%{consent: consent})

      assert AshCookieConsent.get_consent(conn) == consent
    end

    test "returns nil when no consent in assigns" do
      conn = build_conn()

      assert AshCookieConsent.get_consent(conn) == nil
    end

    test "returns nil for invalid input" do
      assert AshCookieConsent.get_consent(nil) == nil
      assert AshCookieConsent.get_consent(%{}) == nil
    end
  end

  describe "has_consent?/1" do
    test "returns true when consent exists" do
      consent = %{terms: "v1.0", groups: ["essential"]}
      conn = build_conn(%{consent: consent})

      assert AshCookieConsent.has_consent?(conn)
    end

    test "returns false when consent is nil" do
      conn = build_conn(%{consent: nil})

      refute AshCookieConsent.has_consent?(conn)
    end

    test "returns false when consent is empty map" do
      conn = build_conn(%{consent: %{}})

      refute AshCookieConsent.has_consent?(conn)
    end

    test "returns false when no consent in assigns" do
      conn = build_conn()

      refute AshCookieConsent.has_consent?(conn)
    end
  end

  describe "consent_expired?/1" do
    test "returns true for nil consent" do
      assert AshCookieConsent.consent_expired?(nil)
    end

    test "returns false when expires_at is nil" do
      consent = %{expires_at: nil}

      refute AshCookieConsent.consent_expired?(consent)
    end

    test "returns false when consent has not expired" do
      future_date = DateTime.utc_now() |> DateTime.add(30, :day)
      consent = %{expires_at: future_date}

      refute AshCookieConsent.consent_expired?(consent)
    end

    test "returns true when consent has expired" do
      past_date = DateTime.utc_now() |> DateTime.add(-30, :day)
      consent = %{expires_at: past_date}

      assert AshCookieConsent.consent_expired?(consent)
    end

    test "returns true for invalid consent format" do
      assert AshCookieConsent.consent_expired?(%{expires_at: "invalid"})
      assert AshCookieConsent.consent_expired?("invalid")
    end
  end

  describe "needs_consent?/1" do
    test "returns true when no consent exists" do
      conn = build_conn()

      assert AshCookieConsent.needs_consent?(conn)
    end

    test "returns true when consent is nil" do
      conn = build_conn(%{consent: nil})

      assert AshCookieConsent.needs_consent?(conn)
    end

    test "returns true when consent has expired" do
      past_date = DateTime.utc_now() |> DateTime.add(-30, :day)
      consent = %{expires_at: past_date, groups: ["essential"]}
      conn = build_conn(%{consent: consent})

      assert AshCookieConsent.needs_consent?(conn)
    end

    test "returns false when valid consent exists" do
      future_date = DateTime.utc_now() |> DateTime.add(30, :day)
      consent = %{expires_at: future_date, groups: ["essential"]}
      conn = build_conn(%{consent: consent})

      refute AshCookieConsent.needs_consent?(conn)
    end

    test "returns false when consent has no expiration" do
      consent = %{expires_at: nil, groups: ["essential"]}
      conn = build_conn(%{consent: consent})

      refute AshCookieConsent.needs_consent?(conn)
    end
  end
end
