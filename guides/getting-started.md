# Getting Started with AshCookieConsent

This guide will help you add GDPR-compliant cookie consent management to your Phoenix application.

## Prerequisites

- Elixir 1.14+
- Phoenix 1.7+
- Phoenix LiveView 1.0+
- Ash Framework 3.0+

## Installation

### 1. Add the Dependency

Add `ash_cookie_consent` to your `mix.exs`:

```elixir
def deps do
  [
    {:ash_cookie_consent, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

### 2. Install AlpineJS

The consent modal requires AlpineJS for interactivity. Add it to your `assets/js/app.js`:

```javascript
import Alpine from 'alpinejs'
window.Alpine = Alpine
Alpine.start()
```

Install via npm:

```bash
cd assets && npm install alpinejs --save
```

### 3. Configure Tailwind CSS

Add the library path to your `assets/tailwind.config.js`:

```javascript
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex',
    '../deps/ash_cookie_consent/lib/**/*.ex'  // Add this line
  ],
  // ...
}
```

## Basic Setup

### Step 1: Add the Plug to Your Router

The Plug loads consent data and sets assigns for use in your templates.

For lightweight cookie/session storage (no database), the `:resource` parameter is **optional**:

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_cookies  # Required: fetches request cookies for consent reading
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    # Add the consent plug AFTER :fetch_cookies (resource is optional for Phase 1)
    plug AshCookieConsent.Plug
  end

  # ... your routes
end
```

> **Important**: The `plug :fetch_cookies` line is **required** before `AshCookieConsent.Plug`. Phoenix's `:fetch_session` only fetches the session cookie, but the consent library needs access to all request cookies via `conn.req_cookies` to read the `_consent` cookie.

> **Note**: For database persistence and user-specific consent tracking, add `resource: MyApp.Consent.ConsentSettings` to the plug options. See the [Database Integration](database-integration.md) guide for details.

### Step 2: Create the Consent Controller

The consent modal submits to a controller that saves the user's preferences. Create the controller:

```elixir
# lib/my_app_web/controllers/consent_controller.ex
defmodule MyAppWeb.ConsentController do
  use MyAppWeb, :controller
  alias AshCookieConsent.Storage

  def create(conn, params) do
    # Parse consent groups from JSON
    groups = parse_groups(params)

    # Build consent data with expiration
    consent = build_consent(groups, params)

    # Save to cookie and session (no resource needed for Phase 1)
    conn = Storage.put_consent(conn, consent)

    # Redirect back to the referring page or home
    redirect_url = get_redirect_url(conn, params)

    conn
    |> put_flash(:info, "Your cookie preferences have been saved.")
    |> redirect(to: redirect_url)
  end

  defp parse_groups(%{"groups" => groups}) when is_list(groups), do: groups

  defp parse_groups(%{"groups" => json}) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, groups} when is_list(groups) -> groups
      _ -> ["essential"]
    end
  end

  defp parse_groups(_), do: ["essential"]

  defp build_consent(groups, params) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires = DateTime.add(now, 365, :day) |> DateTime.truncate(:second)

    %{
      "terms" => Map.get(params, "terms", "v1.0"),
      "groups" => groups,
      "consented_at" => now,
      "expires_at" => expires
    }
  end

  defp get_redirect_url(conn, params) do
    # Try params first, then referer header, then fallback to "/"
    Map.get(params, "redirect_to") ||
      get_req_header(conn, "referer") |> List.first() ||
      "/"
  end
end
```

Then add the route to your router:

```elixir
# lib/my_app_web/router.ex
scope "/", MyAppWeb do
  pipe_through :browser

  # Add this route for consent form submission
  post "/consent", ConsentController, :create

  # ... your other routes
end
```

### Step 3: Configure LiveView (If Using LiveView)

Add the Hook to your application web module:

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
end
```

Or add it globally in your router:

```elixir
live_session :default,
  on_mount: [{AshCookieConsent.LiveView.Hook, :load_consent}] do
  live "/", HomeLive
  # ... other routes
end
```

#### ⚠️ Important: Hook Ordering with Multiple on_mount Callbacks

If you're using other LiveView hooks (like `AshAuthentication.Phoenix.LiveSession`), you **must** specify ALL hooks in your `live_session` block. The `on_mount` option in `live_session` **replaces** (not appends to) any `on_mount` defined in your `live_view` macro.

```elixir
# ❌ WRONG - Only AshAuthentication hook will run
live_session :admin,
  on_mount: AshAuthentication.Phoenix.LiveSession do
  # The consent hook from live_view macro is REPLACED and won't run!
  live "/admin", AdminDashboardLive
end

# ✅ CORRECT - Explicitly list all hooks in order
live_session :admin,
  on_mount: [
    AshAuthentication.Phoenix.LiveSession,
    {AshCookieConsent.LiveView.Hook, :load_consent}
  ] do
  # Both hooks will run in the order specified
  live "/admin", AdminDashboardLive
end
```

**Why this matters:**
- Phoenix's `live_session` `on_mount` completely replaces any `on_mount` from your `live_view` macro
- If you forget to list all hooks, some won't execute
- This can cause missing assigns (like `@consent` or `@current_user`)
- Always be explicit about hook ordering in `live_session` blocks

### Step 4: Add the Modal to Your Layout

Add the consent modal to your root layout:

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

**Optional**: Import the components in your web module for cleaner syntax:

```elixir
# In your MyAppWeb module
def html do
  quote do
    # ... existing imports
    import AshCookieConsent.Components.ConsentModal
    import AshCookieConsent.Components.ConsentScript
  end
end
```

Then use it like:

```heex
<.consent_modal
  current_consent={@consent}
  cookie_groups={AshCookieConsent.cookie_groups()}
/>
```

## Using Consent in Your Application

### Check Consent in Controllers

```elixir
def index(conn, _params) do
  if AshCookieConsent.consent_given?(conn, "analytics") do
    # Load analytics scripts
  end

  render(conn, :index)
end
```

### Check Consent in LiveViews

```elixir
def mount(_params, _session, socket) do
  analytics_enabled =
    AshCookieConsent.consent_given?(socket, "analytics")

  {:ok, assign(socket, analytics_enabled: analytics_enabled)}
end
```

### Conditional Script Loading

Use the `ConsentScript` component to load scripts only when consent is given:

```heex
<!-- Google Analytics (only loads if consent given) -->
<AshCookieConsent.Components.ConsentScript.consent_script
  consent={@consent}
  group="analytics"
  src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"
  async={true}
/>
```

Or with the imported version:

```heex
<.consent_script
  consent={@consent}
  group="analytics"
  src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"
  async={true}
/>
```

## What Happens Next?

1. **First Visit**: Users see the consent modal automatically
2. **User Choice**: They can accept all, essential only, or customize preferences
3. **Storage**: Consent is saved in a cookie (and session for performance)
4. **Expiration**: Consent expires after 1 year (configurable)
5. **Scripts**: Analytics/marketing scripts only load if user consented

## Next Steps

- **Customize Cookie Groups**: See [Customization Guide](customization.html)
- **Handle Events**: See [Examples Guide](examples.html)
- **Add User Sync**: See [Extending Guide](extending.html)
- **Troubleshooting**: See [Troubleshooting Guide](troubleshooting.html)

## Quick Reference

### Helper Functions

```elixir
# Check if any consent exists
AshCookieConsent.has_consent?(conn_or_socket)

# Check if specific group consent exists
AshCookieConsent.consent_given?(conn_or_socket, "analytics")

# Get full consent data
AshCookieConsent.get_consent(conn_or_socket)

# Check if consent expired
AshCookieConsent.consent_expired?(consent)

# Check if consent needed
AshCookieConsent.needs_consent?(conn_or_socket)
```

### Available Cookie Groups (Default)

- **essential** - Required cookies (always enabled)
- **analytics** - Analytics and performance tracking
- **marketing** - Marketing and advertising cookies

See the [Customization Guide](customization.html) to add custom cookie groups.
