# Usage Examples

This guide provides production-ready code examples for integrating AshCookieConsent into your Phoenix application.

## Table of Contents

- [Router Configuration](#router-configuration)
- [Traditional Phoenix Controllers](#traditional-phoenix-controllers)
- [LiveView Integration](#liveview-integration)
- [Layout Templates](#layout-templates)
- [Custom Consent Management](#custom-consent-management)
- [Form Submission Handling](#form-submission-handling)

## Router Configuration

### Basic Setup

Add the consent Plug to your browser pipeline:

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

  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/privacy", PageController, :privacy
    post "/consent", ConsentController, :update

    live "/settings", SettingsLive
  end
end
```

### Custom Configuration

```elixir
pipeline :browser do
  # ... other plugs

  # Custom cookie name and session key
  plug AshCookieConsent.Plug,
    resource: MyApp.Consent.ConsentSettings,
    cookie_name: "my_app_consent",
    session_key: "user_consent",
    user_id_key: :current_user_id
end
```

### Protected Routes

Create a custom pipeline that requires consent:

```elixir
pipeline :require_consent do
  plug :browser
  plug :check_consent_given
end

scope "/premium", MyAppWeb do
  pipe_through :require_consent

  get "/features", PremiumController, :index
end

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
```

## Traditional Phoenix Controllers

### Basic Consent Checking

```elixir
defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def home(conn, _params) do
    # Check if specific consent has been given
    analytics_enabled = AshCookieConsent.consent_given?(conn, "analytics")
    marketing_enabled = AshCookieConsent.consent_given?(conn, "marketing")

    # Get the full consent data
    consent = AshCookieConsent.get_consent?(conn)

    # Check if any consent exists
    has_consent = AshCookieConsent.has_consent?(conn)

    render(conn, :home,
      analytics_enabled: analytics_enabled,
      marketing_enabled: marketing_enabled,
      has_consent: has_consent
    )
  end
end
```

### Conditional Features

```elixir
def dashboard(conn, _params) do
  # Show personalized content only if marketing consent given
  show_personalized = AshCookieConsent.consent_given?(conn, "marketing")

  # Load analytics data only if analytics consent given
  analytics_data =
    if AshCookieConsent.consent_given?(conn, "analytics") do
      load_analytics_data()
    else
      nil
    end

  render(conn, :dashboard,
    show_personalized: show_personalized,
    analytics_data: analytics_data
  )
end
```

## LiveView Integration

### Application Web Module

Configure the LiveView Hook in your web module:

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

  defp html_helpers do
    quote do
      # ... existing helpers

      # Import consent components
      import AshCookieConsent.Components.ConsentModal
      import AshCookieConsent.Components.ConsentScript

      # ... other helpers
    end
  end
end
```

### Basic LiveView with Consent

```elixir
defmodule MyAppWeb.HomeLive do
  use MyAppWeb, :live_view

  # Consent is automatically loaded via the Hook
  # Available assigns: @consent, @show_consent_modal, @cookie_groups

  @impl true
  def mount(_params, _session, socket) do
    # Check consent status
    analytics_enabled = AshCookieConsent.consent_given?(socket, "analytics")

    socket =
      socket
      |> assign(:page_title, "Welcome")
      |> assign(:analytics_enabled, analytics_enabled)

    {:ok, socket}
  end

  @impl true
  def handle_event("update_consent", params, socket) do
    # Handle consent updates using the Hook's helper
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

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1>Welcome</h1>

      <%= if @analytics_enabled do %>
        <div>Analytics enabled - showing detailed stats</div>
      <% else %>
        <div>Enable analytics to see detailed statistics</div>
      <% end %>

      <button phx-click="show_consent_modal">
        Manage Cookie Preferences
      </button>
    </div>
    """
  end
end
```

### Quick Accept/Reject Actions

```elixir
@impl true
def handle_event("accept_all", _params, socket) do
  all_groups =
    AshCookieConsent.cookie_groups()
    |> Enum.map(& &1.id)

  params = %{
    "terms" => "v1.0",
    "groups" => all_groups
  }

  AshCookieConsent.LiveView.Hook.handle_consent_update(
    socket,
    params,
    resource: MyApp.Consent.ConsentSettings
  )
end

@impl true
def handle_event("reject_all", _params, socket) do
  params = %{
    "terms" => "v1.0",
    "groups" => ["essential"]  # Essential cookies only
  }

  AshCookieConsent.LiveView.Hook.handle_consent_update(
    socket,
    params,
    resource: MyApp.Consent.ConsentSettings
  )
end
```

## Layout Templates

### Root Layout with Consent Modal

```heex
<!-- lib/my_app_web/components/layouts/root.html.heex -->
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <title><%= assigns[:page_title] || "MyApp" %></title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static src={~p"/assets/app.js"}></script>

    <!-- Conditional Analytics Scripts -->
    <.consent_script
      consent={assigns[:consent]}
      group="analytics"
      src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"
      async={true}
    />

    <.consent_script consent={assigns[:consent]} group="analytics">
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());
      gtag('config', 'GA_MEASUREMENT_ID');
    </.consent_script>

    <!-- Conditional Marketing Scripts -->
    <.consent_script
      consent={assigns[:consent]}
      group="marketing"
      src="https://connect.facebook.net/en_US/fbevents.js"
      defer={true}
    />
  </head>
  <body>
    <%= @inner_content %>

    <!-- Consent Modal -->
    <.consent_modal
      current_consent={assigns[:consent]}
      cookie_groups={assigns[:cookie_groups] || AshCookieConsent.cookie_groups()}
      privacy_url="/privacy"
    />

    <!-- LiveView Cookie Update Handler -->
    <script>
      window.addEventListener("phx:update-consent-cookie", (e) => {
        const consent = e.detail.consent;
        const expires = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toUTCString();
        document.cookie = `_consent=${encodeURIComponent(consent)}; expires=${expires}; path=/; SameSite=Lax`;
      });
    </script>
  </body>
</html>
```

### App Layout with Navigation

```heex
<!-- lib/my_app_web/components/layouts/app.html.heex -->
<header class="px-4 sm:px-6 lg:px-8">
  <div class="flex items-center justify-between border-b py-3">
    <div class="flex items-center gap-4">
      <a href="/"><h1 class="text-xl font-semibold">MyApp</h1></a>
    </div>
    <nav class="flex gap-4">
      <a href="/" class="hover:text-zinc-700">Home</a>
      <a href="/privacy" class="hover:text-zinc-700">Privacy</a>
      <a href="/settings" class="hover:text-zinc-700">Cookie Settings</a>
    </nav>
  </div>
</header>

<main class="px-4 py-20 sm:px-6 lg:px-8">
  <.flash_group flash={@flash} />

  <!-- Consent Warning Banner -->
  <%= if assigns[:show_consent_modal] do %>
    <div class="mb-4 p-4 bg-yellow-50 border-l-4 border-yellow-400">
      <p class="font-medium text-yellow-700">Cookie Consent Required</p>
      <p class="text-sm text-yellow-600">
        Please review and accept our cookie policy to continue.
      </p>
    </div>
  <% end %>

  <%= @inner_content %>
</main>

<footer class="mt-16 border-t py-8 px-4">
  <div class="flex justify-between items-center">
    <div class="text-sm text-gray-600">
      &copy; <%= DateTime.utc_now().year %> MyApp
    </div>
    <div class="flex gap-4 text-sm">
      <a href="/privacy">Privacy Policy</a>
      <button phx-click="show_consent_modal" class="underline">
        Cookie Settings
      </button>
    </div>
  </div>
</footer>
```

## Custom Consent Management

### Dedicated Settings Page

```elixir
defmodule MyAppWeb.SettingsLive do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    consent = socket.assigns[:consent] || %{}
    consented_groups = Map.get(consent, "groups", ["essential"])
    cookie_groups = AshCookieConsent.cookie_groups()

    socket =
      socket
      |> assign(:page_title, "Cookie Settings")
      |> assign(:cookie_groups, cookie_groups)
      |> assign(:consented_groups, consented_groups)
      |> assign(:saving, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_group", %{"group" => group_id}, socket) do
    consented_groups = socket.assigns.consented_groups

    new_groups =
      if group_id in consented_groups do
        if group_id == "essential" do
          consented_groups  # Can't remove essential
        else
          List.delete(consented_groups, group_id)
        end
      else
        [group_id | consented_groups]
      end

    {:noreply, assign(socket, consented_groups: new_groups)}
  end

  @impl true
  def handle_event("save_preferences", _params, socket) do
    params = %{
      "terms" => "v1.0",
      "groups" => socket.assigns.consented_groups
    }

    AshCookieConsent.LiveView.Hook.handle_consent_update(
      socket,
      params,
      resource: MyApp.Consent.ConsentSettings
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <h1 class="text-3xl font-bold mb-6">Cookie Settings</h1>

      <div class="space-y-4 mb-8">
        <%= for group <- @cookie_groups do %>
          <div class="border rounded-lg p-4">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h3 class="text-lg font-semibold"><%= group.label %></h3>
                <p class="text-sm text-gray-600"><%= group.description %></p>
              </div>
              <label class="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={group.id in @consented_groups}
                  disabled={group.required}
                  phx-click="toggle_group"
                  phx-value-group={group.id}
                  class="sr-only peer"
                />
                <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-checked:bg-blue-600"></div>
              </label>
            </div>
          </div>
        <% end %>
      </div>

      <button
        phx-click="save_preferences"
        disabled={@saving}
        class="px-6 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
      >
        <%= if @saving, do: "Saving...", else: "Save Preferences" %>
      </button>
    </div>
    """
  end
end
```

## Form Submission Handling

### Traditional Form Controller

```elixir
defmodule MyAppWeb.ConsentController do
  use MyAppWeb, :controller
  alias AshCookieConsent.Storage

  def update(conn, params) do
    # Parse consent groups
    groups = parse_groups(params)

    # Build consent data
    consent = build_consent(groups, params)

    # Save to all storage tiers
    conn =
      Storage.put_consent(
        conn,
        consent,
        resource: MyApp.Consent.ConsentSettings
      )

    # Redirect back
    redirect_url = Map.get(params, "redirect_to", "/")

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
end
```

### HTML Form Example

```heex
<form action="/consent" method="post">
  <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
  <input type="hidden" name="terms" value="v1.0" />

  <%= for group <- @cookie_groups do %>
    <label>
      <input
        type="checkbox"
        name="groups[]"
        value={group.id}
        checked={group.required}
        disabled={group.required}
      />
      <%= group.label %>
    </label>
  <% end %>

  <button type="submit">Save Preferences</button>
</form>
```

## Summary

These examples cover:

- ✅ Router configuration with Plug
- ✅ Traditional controller integration
- ✅ LiveView integration with Hook
- ✅ Layout templates with conditional scripts
- ✅ Custom consent management UI
- ✅ Form submission handling

For more advanced usage, see:
- [Extending Guide](extending.html) - Adding user relationships and database sync
- [Troubleshooting Guide](troubleshooting.html) - Common issues and solutions
