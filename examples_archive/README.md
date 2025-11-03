# AshCookieConsent - Examples

This directory contains example implementations showing how to integrate AshCookieConsent into your Phoenix application.

## Overview

The examples demonstrate:
- **Router configuration** with the Plug
- **Traditional controller** integration
- **LiveView** integration with the Hook
- **Layout templates** with the consent modal
- **Event handling** for consent updates

## Files

### Configuration

- **`router.ex`** - Example router configuration with the consent Plug
- **`application_web.ex`** - Example web module configuration for LiveView

### Controllers

- **`page_controller.ex`** - Example controller showing consent checking
- **`consent_controller.ex`** - Example controller for handling consent form submissions

### LiveViews

- **`home_live.ex`** - Example LiveView with consent modal integration
- **`settings_live.ex`** - Example LiveView for managing consent preferences

### Templates

- **`root.html.heex`** - Root layout with consent modal
- **`app.html.heex`** - App layout example
- **`page_html/home.html.heex`** - Example page template

## Quick Start

### 1. Add the Plug to Your Router

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    # Add the consent plug
    plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
  end

  # ... your routes
end
```

### 2. Configure LiveView (Optional)

If using LiveView, add the hook to your application web module:

```elixir
# lib/my_app_web.ex
defmodule MyAppWeb do
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {MyAppWeb.Layouts, :app}

      # Add the consent hook
      on_mount {AshCookieConsent.LiveView.Hook, :load_consent}

      unquote(html_helpers())
    end
  end

  # Or add globally to a live_session in your router
end
```

### 3. Add the Modal to Your Layout

```heex
<!-- lib/my_app_web/components/layouts/root.html.heex -->
<!DOCTYPE html>
<html lang="en">
  <head>
    <!-- ... head content ... -->
  </head>
  <body>
    <%= @inner_content %>

    <!-- Consent Modal -->
    <AshCookieConsent.Components.ConsentModal.consent_modal
      current_consent={assigns[:consent]}
      cookie_groups={AshCookieConsent.cookie_groups()}
      privacy_url="/privacy"
    />
  </body>
</html>
```

### 4. Check Consent in Your Code

#### In Controllers

```elixir
def index(conn, _params) do
  if AshCookieConsent.consent_given?(conn, "analytics") do
    # Load analytics scripts
  end

  render(conn, :index)
end
```

#### In Templates

```heex
<!-- Conditional script loading -->
<AshCookieConsent.Components.ConsentScript.consent_script
  consent={@consent}
  group="analytics"
  src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"
  async={true}
/>
```

#### In LiveViews

```elixir
def mount(_params, _session, socket) do
  # Consent is already available via the hook
  analytics_enabled =
    AshCookieConsent.consent_given?(socket, "analytics")

  {:ok, assign(socket, analytics_enabled: analytics_enabled)}
end
```

## Example Scenarios

### Scenario 1: Traditional Phoenix App (Controllers)

See `page_controller.ex` and the layout templates for a complete example of:
- Loading consent in the Plug
- Checking consent in controllers
- Rendering the consent modal
- Conditionally loading scripts based on consent

### Scenario 2: LiveView App

See `home_live.ex` and `settings_live.ex` for examples of:
- Using the LiveView Hook
- Handling consent updates via events
- Showing/hiding the consent modal
- Managing consent preferences in a settings page

### Scenario 3: Hybrid App (Controllers + LiveView)

You can use both approaches in the same app:
- The Plug runs for all requests and sets the session
- LiveView Hook reads from the session
- Consent state is consistent across both

## Handling Consent Updates

### In LiveView

```elixir
@impl true
def handle_event("update_consent", params, socket) do
  AshCookieConsent.LiveView.Hook.handle_consent_update(
    socket,
    params,
    resource: MyApp.Consent.ConsentSettings
  )
end

@impl true
def handle_event("show_consent_modal", _params, socket) do
  {:noreply, AshCookieConsent.LiveView.Hook.show_modal(socket)}
end
```

### In Traditional Forms

See `consent_controller.ex` for an example of handling form submissions with:
- Parsing consent parameters
- Validating and saving consent
- Setting cookies and session
- Redirecting back to the referring page

## Customization

### Custom Cookie Groups

```elixir
# In your config/config.exs
config :ash_cookie_consent,
  cookie_groups: [
    %{
      id: "essential",
      label: "Essential Cookies",
      description: "Required for the website to function properly",
      required: true
    },
    %{
      id: "analytics",
      label: "Analytics & Performance",
      description: "Help us understand how visitors use our website",
      required: false
    },
    %{
      id: "marketing",
      label: "Marketing & Advertising",
      description: "Used to deliver personalized advertisements",
      required: false
    },
    %{
      id: "social",
      label: "Social Media",
      description: "Enable social media features and integrations",
      required: false
    }
  ]
```

### Custom Modal Text

```heex
<.consent_modal
  current_consent={@consent}
  cookie_groups={AshCookieConsent.cookie_groups()}
  title="Privacy Settings"
  description="We care about your privacy. Choose which cookies you're comfortable with."
  accept_all_label="Accept All"
  reject_all_label="Essential Only"
  customize_label="Customize"
  privacy_url="/privacy-policy"
/>
```

## Testing

All examples include inline documentation and are designed to be copy-pasted into your application and adapted to your needs.

## Need Help?

- Check the [main README](../README.md) for detailed documentation
- Review the [module documentation](../lib/ash_cookie_consent/) for API details
- See the [test files](../test/) for additional usage examples
