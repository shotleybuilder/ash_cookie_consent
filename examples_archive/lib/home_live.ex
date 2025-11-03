defmodule MyAppWeb.HomeLive do
  @moduledoc """
  Example LiveView demonstrating consent integration.

  This shows how to:
  - Use the AshCookieConsent.LiveView.Hook
  - Access consent data from socket assigns
  - Handle consent update events
  - Display the consent modal
  - Show/hide content based on consent status
  """

  use MyAppWeb, :live_view

  # The AshCookieConsent.LiveView.Hook is loaded via on_mount in MyAppWeb.live_view/0
  # This sets the following assigns automatically:
  # - @consent
  # - @show_consent_modal
  # - @cookie_groups

  @impl true
  def mount(_params, _session, socket) do
    # Consent is already available via the hook
    analytics_enabled = AshCookieConsent.consent_given?(socket, "analytics")
    marketing_enabled = AshCookieConsent.consent_given?(socket, "marketing")

    socket =
      socket
      |> assign(:page_title, "Welcome")
      |> assign(:analytics_enabled, analytics_enabled)
      |> assign(:marketing_enabled, marketing_enabled)

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
    # Show the consent modal programmatically
    {:noreply, AshCookieConsent.LiveView.Hook.show_modal(socket)}
  end

  @impl true
  def handle_event("accept_all", _params, socket) do
    # Accept all cookie groups
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
    # Reject all except essential
    params = %{
      "terms" => "v1.0",
      "groups" => ["essential"]
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
    <div class="mx-auto max-w-4xl px-4 py-8">
      <h1 class="text-4xl font-bold mb-4">Welcome to Our Site</h1>

      <!-- Show consent status -->
      <div class="mb-8 p-4 bg-gray-100 rounded">
        <h2 class="text-xl font-semibold mb-2">Your Cookie Preferences</h2>

        <div class="space-y-2">
          <p>
            <strong>Consent given:</strong>
            <%= if AshCookieConsent.has_consent?(@socket) do %>
              <span class="text-green-600">Yes</span>
            <% else %>
              <span class="text-red-600">No</span>
            <% end %>
          </p>

          <%= if @consent do %>
            <p>
              <strong>Consented groups:</strong>
              <%= Enum.join(@consent["groups"] || [], ", ") %>
            </p>
            <%= if @consent["consented_at"] do %>
              <p>
                <strong>Consent given at:</strong>
                <%= Calendar.strftime(@consent["consented_at"], "%Y-%m-%d %H:%M:%S") %>
              </p>
            <% end %>
          <% end %>

          <div class="mt-4">
            <button
              phx-click="show_consent_modal"
              class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              Manage Cookie Preferences
            </button>
          </div>
        </div>
      </div>

      <!-- Content that depends on consent -->
      <div class="mb-8">
        <h2 class="text-2xl font-semibold mb-4">Analytics Demo</h2>

        <%= if @analytics_enabled do %>
          <div class="p-4 bg-green-100 rounded">
            <p class="text-green-800">
              ✓ Analytics enabled - We can track page views and user behavior
            </p>
          </div>
        <% else %>
          <div class="p-4 bg-yellow-100 rounded">
            <p class="text-yellow-800">
              ⚠ Analytics disabled - Enable analytics cookies to help us improve the site
            </p>
          </div>
        <% end %>
      </div>

      <div class="mb-8">
        <h2 class="text-2xl font-semibold mb-4">Marketing Demo</h2>

        <%= if @marketing_enabled do %>
          <div class="p-4 bg-green-100 rounded">
            <p class="text-green-800">
              ✓ Marketing enabled - We can show personalized content and ads
            </p>
          </div>
        <% else %>
          <div class="p-4 bg-yellow-100 rounded">
            <p class="text-yellow-800">
              ⚠ Marketing disabled - Enable marketing cookies for personalized content
            </p>
          </div>
        <% end %>
      </div>

      <!-- Quick action buttons -->
      <div class="flex gap-4">
        <button
          phx-click="accept_all"
          class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"
        >
          Accept All Cookies
        </button>

        <button
          phx-click="reject_all"
          class="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
        >
          Essential Cookies Only
        </button>
      </div>
    </div>
    """
  end
end
