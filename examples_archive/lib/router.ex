defmodule MyAppWeb.Router do
  @moduledoc """
  Example router configuration showing AshCookieConsent.Plug integration.

  This demonstrates:
  - Adding the consent Plug to the browser pipeline
  - Configuring the Plug with your ConsentSettings resource
  - Custom cookie and session configuration options
  """

  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    # Add the AshCookieConsent Plug
    # This will:
    # 1. Load consent from cookie/session/database
    # 2. Set assigns: :consent, :show_consent_modal, :cookie_groups
    # 3. Cache consent in session for performance
    plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
  end

  # Alternative: Custom configuration
  pipeline :browser_with_custom_config do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    # Custom cookie name and session key
    plug AshCookieConsent.Plug,
      resource: MyApp.Consent.ConsentSettings,
      cookie_name: "my_app_consent",
      session_key: "user_consent",
      user_id_key: :current_user_id
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/privacy", PageController, :privacy

    # Traditional form-based consent handling (optional)
    post "/consent", ConsentController, :update

    # Settings page with consent management
    live "/settings", SettingsLive
  end

  # LiveView routes with consent
  scope "/", MyAppWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/about", AboutLive
  end

  # Example: Protected routes that require consent
  # You can create a custom plug to enforce consent on specific routes
  pipeline :require_consent do
    plug :browser
    plug :check_consent_given
  end

  # Custom plug to check if consent has been given
  defp check_consent_given(conn, _opts) do
    if AshCookieConsent.has_consent?(conn) do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:info, "Please accept our cookie policy to continue.")
      |> Phoenix.Controller.redirect(to: "/")
      |> halt()
    end
  end
end
