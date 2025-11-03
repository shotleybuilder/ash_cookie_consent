defmodule MyAppWeb.SettingsLive do
  @moduledoc """
  Example LiveView for a dedicated consent settings/preferences page.

  This demonstrates:
  - Building a custom consent management UI
  - Allowing users to toggle individual cookie groups
  - Saving consent preferences without using the modal
  - Showing current consent status
  """

  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Get current consent
    consent = socket.assigns[:consent] || %{}
    consented_groups = Map.get(consent, "groups", ["essential"])

    # Get all available cookie groups
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

    # Toggle the group
    new_groups =
      if group_id in consented_groups do
        # Don't allow removing essential cookies
        if group_id == "essential" do
          consented_groups
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
    socket = assign(socket, saving: true)

    # Build consent params
    params = %{
      "terms" => "v1.0",
      "groups" => socket.assigns.consented_groups
    }

    # Save using the Hook helper
    AshCookieConsent.LiveView.Hook.handle_consent_update(
      socket,
      params,
      resource: MyApp.Consent.ConsentSettings
    )
  end

  @impl true
  def handle_event("reset_to_defaults", _params, socket) do
    # Reset to only essential cookies
    {:noreply, assign(socket, consented_groups: ["essential"])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 py-8">
      <h1 class="text-3xl font-bold mb-6">Cookie Settings</h1>

      <div class="mb-6 p-4 bg-blue-50 rounded">
        <p class="text-sm text-blue-800">
          We use cookies to improve your experience on our website. You can choose which cookies you're comfortable with. Essential cookies are always enabled as they're required for the site to function.
        </p>
      </div>

      <!-- Cookie Groups -->
      <div class="space-y-4 mb-8">
        <%= for group <- @cookie_groups do %>
          <div class="border rounded-lg p-4">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="flex items-center gap-2 mb-2">
                  <h3 class="text-lg font-semibold"><%= group.label %></h3>
                  <%= if group.required do %>
                    <span class="px-2 py-1 text-xs bg-gray-200 text-gray-700 rounded">
                      Required
                    </span>
                  <% end %>
                </div>
                <p class="text-sm text-gray-600 mb-3">
                  <%= group.description %>
                </p>

                <%= if Map.has_key?(group, :examples) do %>
                  <details class="text-xs text-gray-500">
                    <summary class="cursor-pointer hover:text-gray-700">
                      Show examples
                    </summary>
                    <ul class="mt-2 ml-4 list-disc">
                      <%= for example <- group.examples do %>
                        <li><%= example %></li>
                      <% end %>
                    </ul>
                  </details>
                <% end %>
              </div>

              <div class="ml-4">
                <label class="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={group.id in @consented_groups}
                    disabled={group.required}
                    phx-click="toggle_group"
                    phx-value-group={group.id}
                    class="sr-only peer"
                  />
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600 peer-disabled:opacity-50 peer-disabled:cursor-not-allowed">
                  </div>
                </label>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Current Status -->
      <%= if @consent do %>
        <div class="mb-6 p-4 bg-gray-50 rounded">
          <h3 class="font-semibold mb-2">Current Preferences</h3>
          <div class="text-sm space-y-1">
            <p>
              <strong>Enabled groups:</strong>
              <%= Enum.join(@consented_groups, ", ") %>
            </p>
            <%= if @consent["consented_at"] do %>
              <p>
                <strong>Last updated:</strong>
                <%= Calendar.strftime(@consent["consented_at"], "%Y-%m-%d %H:%M:%S") %>
              </p>
            <% end %>
            <%= if @consent["expires_at"] do %>
              <p>
                <strong>Expires:</strong>
                <%= Calendar.strftime(@consent["expires_at"], "%Y-%m-%d") %>
              </p>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Action Buttons -->
      <div class="flex gap-4">
        <button
          phx-click="save_preferences"
          disabled={@saving}
          class="px-6 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <%= if @saving do %>
            Saving...
          <% else %>
            Save Preferences
          <% end %>
        </button>

        <button
          phx-click="reset_to_defaults"
          class="px-6 py-2 bg-gray-200 text-gray-700 rounded hover:bg-gray-300"
        >
          Reset to Defaults
        </button>
      </div>

      <!-- Help Text -->
      <div class="mt-8 p-4 bg-yellow-50 rounded">
        <h3 class="font-semibold mb-2 text-yellow-800">What happens when I change settings?</h3>
        <ul class="text-sm text-yellow-700 space-y-1 list-disc ml-5">
          <li>Your preferences are saved in a cookie on your device</li>
          <li>They're also saved in our database if you're logged in</li>
          <li>Changes take effect immediately</li>
          <li>Preferences expire after 1 year (you'll be asked again)</li>
          <li>You can change your preferences at any time</li>
        </ul>
      </div>
    </div>
    """
  end
end
