defmodule AshCookieConsent.Components.ConsentModalTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias AshCookieConsent.Components.ConsentModal

  @cookie_groups [
    %{
      id: "essential",
      label: "Essential Cookies",
      description: "Required cookies",
      required: true
    },
    %{
      id: "analytics",
      label: "Analytics Cookies",
      description: "Analytics cookies",
      required: false
    }
  ]

  describe "consent_modal/1 visibility logic" do
    test "renders with showModal: false when consent exists" do
      consent = %{"terms" => "v1.0", "groups" => ["essential", "analytics"]}
      assigns = %{consent: consent, cookie_groups: @cookie_groups}

      html =
        rendered_to_string(~H"""
        <ConsentModal.consent_modal
          current_consent={@consent}
          cookie_groups={@cookie_groups}
        />
        """)

      # Should initialize Alpine with showModal: false
      assert html =~ ~s(showModal: false)
      refute html =~ ~s(showModal: true)
    end

    test "renders with showModal: true when no consent exists" do
      assigns = %{cookie_groups: @cookie_groups}

      html =
        rendered_to_string(~H"""
        <ConsentModal.consent_modal
          current_consent={nil}
          cookie_groups={@cookie_groups}
        />
        """)

      # Should initialize Alpine with showModal: true
      assert html =~ ~s(showModal: true)
    end

    test "renders with showModal: true when consent is empty map" do
      assigns = %{cookie_groups: @cookie_groups}

      html =
        rendered_to_string(~H"""
        <ConsentModal.consent_modal
          current_consent={%{}}
          cookie_groups={@cookie_groups}
        />
        """)

      # Should initialize Alpine with showModal: true
      assert html =~ ~s(showModal: true)
    end

    test "renders with showModal: false when consent has groups" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}
      assigns = %{consent: consent, cookie_groups: @cookie_groups}

      html =
        rendered_to_string(~H"""
        <ConsentModal.consent_modal
          current_consent={@consent}
          cookie_groups={@cookie_groups}
        />
        """)

      # Should initialize Alpine with showModal: false
      assert html =~ ~s(showModal: false)
    end
  end

  describe "consent_modal/1 selected groups initialization" do
    test "initializes with user's selected groups when consent exists" do
      # Use atom keys for access pattern in component
      consent = %{terms: "v1.0", groups: ["essential", "analytics"]}
      assigns = %{consent: consent, cookie_groups: @cookie_groups}

      html =
        rendered_to_string(~H"""
        <ConsentModal.consent_modal
          current_consent={@consent}
          cookie_groups={@cookie_groups}
        />
        """)

      # Should initialize selectedGroups with consent groups (HTML escaped)
      assert html =~ ~s(selectedGroups: [&quot;essential&quot;,&quot;analytics&quot;])
    end

    test "initializes with only essential groups when no consent exists" do
      assigns = %{cookie_groups: @cookie_groups}

      html =
        rendered_to_string(~H"""
        <ConsentModal.consent_modal
          current_consent={nil}
          cookie_groups={@cookie_groups}
        />
        """)

      # Should initialize selectedGroups with only required groups (HTML escaped)
      assert html =~ ~s(selectedGroups: [&quot;essential&quot;])
    end
  end

  describe "consent_modal/1 CSRF protection" do
    test "includes CSRF token in form" do
      assigns = %{cookie_groups: @cookie_groups}

      html =
        rendered_to_string(~H"""
        <ConsentModal.consent_modal
          current_consent={nil}
          cookie_groups={@cookie_groups}
        />
        """)

      # Should include CSRF token input
      assert html =~ ~s(name="_csrf_token")
    end
  end

  describe "consent_modal/1 customization" do
    test "respects custom action URL" do
      assigns = %{cookie_groups: @cookie_groups}

      html =
        rendered_to_string(~H"""
        <ConsentModal.consent_modal
          current_consent={nil}
          cookie_groups={@cookie_groups}
          action="/custom-consent"
        />
        """)

      assert html =~ ~s(action="/custom-consent")
    end

    test "respects custom text labels" do
      assigns = %{cookie_groups: @cookie_groups}

      html =
        rendered_to_string(~H"""
        <ConsentModal.consent_modal
          current_consent={nil}
          cookie_groups={@cookie_groups}
          title="Custom Title"
          accept_all_label="Custom Accept"
        />
        """)

      assert html =~ "Custom Title"
      assert html =~ "Custom Accept"
    end
  end
end
