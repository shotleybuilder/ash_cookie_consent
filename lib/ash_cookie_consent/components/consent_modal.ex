defmodule AshCookieConsent.Components.ConsentModal do
  @moduledoc """
  Phoenix Component for rendering a cookie consent modal.

  Provides both a summary view (Accept All / Reject All) and a detailed view
  for granular cookie category selection.

  ## Features

  - Two-view modal: summary and details
  - AlpineJS-powered interactivity
  - Keyboard navigation (Tab, Enter, Escape)
  - ARIA labels for accessibility
  - Responsive design with Tailwind CSS
  - Customizable text and styling

  ## Usage

  ### Basic Usage

      <.consent_modal
        current_consent={@consent}
        cookie_groups={@cookie_groups}
        privacy_url="/privacy"
      />

  ### With Custom Text

      <.consent_modal
        current_consent={@consent}
        cookie_groups={@cookie_groups}
        title="Cookie Settings"
        description="We use cookies to improve your experience"
        accept_all_label="Accept All Cookies"
        reject_all_label="Essential Only"
      />

  ### With Custom CSS Classes

      <.consent_modal
        current_consent={@consent}
        cookie_groups={@cookie_groups}
        modal_class="custom-modal"
        button_class="custom-button"
      />

  ## AlpineJS Setup

  This component requires AlpineJS. Include it in your application:

      // assets/js/app.js
      import Alpine from 'alpinejs'
      window.Alpine = Alpine
      Alpine.start()

  ## Tailwind Configuration

  Add the library path to your Tailwind config to include component styles:

      // assets/tailwind.config.js
      module.exports = {
        content: [
          // ...existing content
          '../deps/ash_cookie_consent/lib/**/*.ex'
        ]
      }
  """

  use Phoenix.Component

  attr(:current_consent, :map, default: nil, doc: "Current consent settings map")
  attr(:cookie_groups, :list, required: true, doc: "List of cookie group configurations")
  attr(:privacy_url, :string, default: "/privacy", doc: "URL to privacy policy page")

  # Text customization
  attr(:title, :string, default: "Cookie Consent", doc: "Modal title")

  attr(:description, :string,
    default: "We use cookies to improve your experience and analyze site usage.",
    doc: "Modal description text"
  )

  attr(:accept_all_label, :string, default: "Accept All", doc: "Accept all button label")
  attr(:reject_all_label, :string, default: "Essential Only", doc: "Reject all button label")
  attr(:customize_label, :string, default: "Customize", doc: "Customize button label")
  attr(:save_preferences_label, :string, default: "Save Preferences", doc: "Save button label")
  attr(:back_label, :string, default: "Back", doc: "Back button label")

  # CSS customization
  attr(:modal_class, :string, default: "", doc: "Additional CSS classes for modal container")
  attr(:button_class, :string, default: "", doc: "Additional CSS classes for buttons")

  # Form action
  attr(:action, :string, default: "/consent", doc: "Form submission URL")
  attr(:method, :string, default: "post", doc: "Form submission method")

  def consent_modal(assigns) do
    # Determine if modal should show (no consent given yet)
    assigns =
      assign(
        assigns,
        :show_modal,
        is_nil(assigns.current_consent) || assigns.current_consent == %{}
      )

    # Get currently selected groups from consent
    selected_groups =
      if assigns.current_consent && assigns.current_consent[:groups] do
        assigns.current_consent.groups
      else
        # Default to essential only
        Enum.filter(assigns.cookie_groups, & &1.required) |> Enum.map(& &1.id)
      end

    assigns = assign(assigns, :selected_groups, selected_groups)

    ~H"""
    <div
      x-data={"{ showModal: true, view: 'summary', selectedGroups: #{Jason.encode!(@selected_groups)}, cookieGroups: #{Jason.encode!(@cookie_groups)}, acceptAll() { this.selectedGroups = this.cookieGroups.map(g => g.id); this.submitConsent(); }, rejectAll() { this.selectedGroups = this.cookieGroups.filter(g => g.required).map(g => g.id); this.submitConsent(); }, toggleGroup(groupId) { const group = this.cookieGroups.find(g => g.id === groupId); if (group && group.required) return; if (this.selectedGroups.includes(groupId)) { this.selectedGroups = this.selectedGroups.filter(id => id !== groupId); } else { this.selectedGroups.push(groupId); } }, isSelected(groupId) { return this.selectedGroups.includes(groupId); }, submitConsent() { this.$refs.consentForm.submit(); this.showModal = false; } }"}
      x-show="showModal"
      x-cloak
      @keydown.escape.window="showModal = false"
      class={"fixed inset-0 z-50 overflow-y-auto #{@modal_class}"}
      role="dialog"
      aria-modal="true"
      aria-labelledby="consent-modal-title"
    >
      <!-- Backdrop -->
      <div
        class="fixed inset-0 bg-black bg-opacity-50 transition-opacity"
        aria-hidden="true"
        x-show="showModal"
        x-transition:enter="ease-out duration-300"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="ease-in duration-200"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0"
      >
      </div>
      <!-- Modal Content -->
      <div class="flex min-h-screen items-center justify-center p-4">
        <div
          class="relative w-full max-w-2xl rounded-lg bg-white shadow-xl"
          x-show="showModal"
          x-transition:enter="ease-out duration-300"
          x-transition:enter-start="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
          x-transition:enter-end="opacity-100 translate-y-0 sm:scale-100"
          x-transition:leave="ease-in duration-200"
          x-transition:leave-start="opacity-100 translate-y-0 sm:scale-100"
          x-transition:leave-end="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
        >
          <!-- Summary View -->
          <div x-show="view === 'summary'" class="p-6">
            <h2 id="consent-modal-title" class="text-2xl font-semibold text-gray-900 mb-4">
              <%= @title %>
            </h2>

            <p class="text-gray-600 mb-6">
              <%= @description %>
            </p>

            <p class="text-sm text-gray-500 mb-6">
              We respect your privacy. You can change your preferences at any time.
              <a
                href={@privacy_url}
                class="text-blue-600 hover:text-blue-800 underline"
                target="_blank"
                rel="noopener noreferrer"
              >
                Learn more in our Privacy Policy
              </a>
            </p>

            <div class="flex flex-col sm:flex-row gap-3">
              <button
                type="button"
                @click="acceptAll()"
                class={"flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors font-medium #{@button_class}"}
              >
                <%= @accept_all_label %>
              </button>

              <button
                type="button"
                @click="rejectAll()"
                class={"flex-1 px-6 py-3 bg-gray-200 text-gray-800 rounded-lg hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors font-medium #{@button_class}"}
              >
                <%= @reject_all_label %>
              </button>

              <button
                type="button"
                @click="view = 'details'"
                class={"flex-1 px-6 py-3 bg-white border-2 border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors font-medium #{@button_class}"}
              >
                <%= @customize_label %>
              </button>
            </div>
          </div>
          <!-- Details View -->
          <div x-show="view === 'details'" class="p-6">
            <div class="flex items-center justify-between mb-6">
              <h2 class="text-2xl font-semibold text-gray-900">
                Customize Cookie Preferences
              </h2>

              <button
                type="button"
                @click="view = 'summary'"
                class="text-gray-400 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-gray-500 rounded"
                aria-label="Close details"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>

            <p class="text-gray-600 mb-6">
              Select which types of cookies you want to accept. Essential cookies cannot be disabled as they are necessary for the site to function.
            </p>

            <div class="space-y-4 mb-6">
              <%= for group <- @cookie_groups do %>
                <div class="border border-gray-200 rounded-lg p-4">
                  <div class="flex items-start">
                    <div class="flex items-center h-6">
                      <input
                        type="checkbox"
                        id={"group-#{group.id}"}
                        x-model="selectedGroups"
                        value={group.id}
                        disabled={group.required}
                        class="w-5 h-5 text-blue-600 border-gray-300 rounded focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
                      />
                    </div>

                    <div class="ml-3 flex-1">
                      <label for={"group-#{group.id}"} class="font-medium text-gray-900 cursor-pointer">
                        <%= group.label %>
                      </label>

                      <p class="text-sm text-gray-600 mt-1"><%= group.description %></p>

                      <%= if group.required do %>
                        <span class="inline-block mt-2 px-2 py-1 text-xs font-semibold text-gray-700 bg-gray-200 rounded">
                          Required
                        </span>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>

            <div class="flex flex-col sm:flex-row gap-3">
              <button
                type="button"
                @click="submitConsent()"
                class={"flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors font-medium #{@button_class}"}
              >
                <%= @save_preferences_label %>
              </button>

              <button
                type="button"
                @click="view = 'summary'"
                class={"flex-1 px-6 py-3 bg-gray-200 text-gray-800 rounded-lg hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors font-medium #{@button_class}"}
              >
                <%= @back_label %>
              </button>
            </div>
          </div>
          <!-- Hidden Form for Submission -->
          <form x-ref="consentForm" action={@action} method={@method} class="hidden">
            <input type="hidden" name="terms" value="v1.0" />
            <input type="hidden" name="groups" x-bind:value="JSON.stringify(selectedGroups)" />
          </form>
        </div>
      </div>
    </div>
    """
  end
end
