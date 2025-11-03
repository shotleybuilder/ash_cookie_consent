defmodule MyAppWeb.PageController do
  @moduledoc """
  Example controller demonstrating consent checking in traditional Phoenix controllers.

  This shows how to:
  - Check if consent has been given for specific cookie groups
  - Access consent data from the connection
  - Conditionally load analytics or marketing scripts
  - Display different content based on consent status
  """

  use MyAppWeb, :controller

  def home(conn, _params) do
    # The AshCookieConsent.Plug has already set these assigns:
    # - conn.assigns.consent - The consent data (or nil)
    # - conn.assigns.show_consent_modal - Whether to show the modal
    # - conn.assigns.cookie_groups - Configured cookie groups

    # Check if specific consent has been given
    analytics_enabled = AshCookieConsent.consent_given?(conn, "analytics")
    marketing_enabled = AshCookieConsent.consent_given?(conn, "marketing")

    # Get the full consent data if you need it
    consent = AshCookieConsent.get_consent(conn)

    # Check if any consent exists
    has_consent = AshCookieConsent.has_consent?(conn)

    # Check if consent has expired
    consent_expired =
      if consent do
        AshCookieConsent.consent_expired?(consent)
      else
        false
      end

    render(conn, :home,
      analytics_enabled: analytics_enabled,
      marketing_enabled: marketing_enabled,
      has_consent: has_consent,
      consent_expired: consent_expired,
      page_title: "Welcome"
    )
  end

  def privacy(conn, _params) do
    render(conn, :privacy, page_title: "Privacy Policy")
  end

  def about(conn, _params) do
    # Example: Show different content based on consent
    show_personalized_content =
      AshCookieConsent.consent_given?(conn, "marketing")

    render(conn, :about,
      show_personalized_content: show_personalized_content,
      page_title: "About Us"
    )
  end
end
