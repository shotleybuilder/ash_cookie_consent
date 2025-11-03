defmodule AshCookieConsent.LiveView.Hook do
  @moduledoc """
  LiveView hook for cookie consent management.

  This hook loads consent from the session (already set by the Plug) and
  assigns it to the LiveView socket.

  ## Usage

  Add to your LiveView module or application-wide:

      defmodule MyAppWeb do
        def live_view do
          quote do
            use Phoenix.LiveView
            on_mount {AshCookieConsent.LiveView.Hook, :load_consent}
          end
        end
      end

  Or in a specific LiveView:

      defmodule MyAppWeb.PageLive do
        use MyAppWeb, :live_view
        on_mount {AshCookieConsent.LiveView.Hook, :load_consent}

        # Your LiveView code...
      end

  ## Mount Phases

  The hook supports different mount phases:

    - `:load_consent` - Loads consent and sets assigns (default)
    - `:require_consent` - Redirects if consent not given (strict mode)

  ## Assigns Set

  The hook sets the following socket assigns:

    - `:consent` - The consent data map (or nil)
    - `:show_consent_modal` - Boolean flag for showing modal
    - `:cookie_groups` - Configured cookie groups

  ## Event Handling

  The hook can handle consent update events in your LiveView:

      @impl true
      def handle_event("update_consent", params, socket) do
        AshCookieConsent.LiveView.Hook.handle_consent_update(socket, params,
          resource: MyApp.ConsentSettings
        )
      end

  ## Examples

      # Basic usage
      on_mount {AshCookieConsent.LiveView.Hook, :load_consent}

      # Require consent before accessing LiveView
      on_mount {AshCookieConsent.LiveView.Hook, :require_consent}

      # In template
      <%= if @show_consent_modal do %>
        <.consent_modal current_consent={@consent} cookie_groups={@cookie_groups} />
      <% end %>
  """

  import Phoenix.LiveView
  import Phoenix.Component

  @doc """
  LiveView on_mount callback.

  Loads consent from session and assigns to socket.
  """
  def on_mount(:load_consent, _params, session, socket) do
    consent = Map.get(session, "consent")
    show_modal = should_show_modal?(consent)

    socket =
      socket
      |> assign(:consent, consent)
      |> assign(:show_consent_modal, show_modal)
      |> assign(:cookie_groups, AshCookieConsent.cookie_groups())

    {:cont, socket}
  end

  def on_mount(:require_consent, params, session, socket) do
    consent = Map.get(session, "consent")

    if AshCookieConsent.has_consent?(%{assigns: %{consent: consent}}) &&
         !AshCookieConsent.consent_expired?(consent) do
      # Consent is valid, continue
      on_mount(:load_consent, params, session, socket)
    else
      # No valid consent, redirect to consent page
      {:halt, redirect(socket, to: get_consent_url(socket))}
    end
  end

  def on_mount(phase, _params, _session, _socket) do
    raise """
    Unknown mount phase for AshCookieConsent.LiveView.Hook: #{inspect(phase)}

    Valid phases are:
      - :load_consent (loads consent and sets assigns)
      - :require_consent (redirects if no valid consent)
    """
  end

  @doc """
  Handles consent update events from LiveView.

  Updates consent across all storage tiers and closes the modal.

  ## Options

    - `:resource` - Ash resource for database storage
    - `:user_id_key` - Key in socket assigns for user ID (default: :current_user_id)

  ## Examples

      def handle_event("update_consent", %{"groups" => groups_json}, socket) do
        AshCookieConsent.LiveView.Hook.handle_consent_update(
          socket,
          %{"groups" => groups_json, "terms" => "v1.0"},
          resource: MyApp.ConsentSettings
        )
      end
  """
  def handle_consent_update(socket, params, opts \\ []) do
    # Parse consent data
    consent = build_consent_from_params(params)

    # Get user ID if authenticated
    user_id_key = Keyword.get(opts, :user_id_key, :current_user_id)
    user_id = Map.get(socket.assigns, user_id_key)

    # Save to database if authenticated
    if user_id && Keyword.has_key?(opts, :resource) do
      resource = Keyword.fetch!(opts, :resource)
      save_consent_to_db(resource, user_id, consent)
    end

    # Update socket assigns
    socket =
      socket
      |> assign(:consent, consent)
      |> assign(:show_consent_modal, false)

    # Return with instructions to update cookie via JavaScript
    # (LiveView can't directly set cookies, so we use a hook)
    {:noreply,
     push_event(socket, "update-consent-cookie", %{
       consent: Jason.encode!(consent)
     })}
  end

  @doc """
  Helper to show the consent modal from a LiveView.

  ## Examples

      def handle_event("show_consent_modal", _params, socket) do
        {:noreply, AshCookieConsent.LiveView.Hook.show_modal(socket)}
      end
  """
  def show_modal(socket) do
    assign(socket, :show_consent_modal, true)
  end

  @doc """
  Helper to hide the consent modal from a LiveView.

  ## Examples

      def handle_event("close_consent_modal", _params, socket) do
        {:noreply, AshCookieConsent.LiveView.Hook.hide_modal(socket)}
      end
  """
  def hide_modal(socket) do
    assign(socket, :show_consent_modal, false)
  end

  # Private functions

  defp should_show_modal?(nil), do: true
  defp should_show_modal?(%{}), do: true

  defp should_show_modal?(consent) when is_map(consent) do
    AshCookieConsent.consent_expired?(consent)
  end

  defp get_consent_url(socket) do
    # Try to get from socket assigns or default
    Map.get(socket.assigns, :consent_url, "/consent")
  end

  defp build_consent_from_params(params) do
    groups =
      case Map.get(params, "groups") do
        groups_json when is_binary(groups_json) ->
          case Jason.decode(groups_json) do
            {:ok, groups} when is_list(groups) -> groups
            _ -> []
          end

        groups when is_list(groups) ->
          groups

        _ ->
          []
      end

    terms = Map.get(params, "terms", "v1.0")

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires = DateTime.add(now, 365, :day) |> DateTime.truncate(:second)

    %{
      "terms" => terms,
      "groups" => groups,
      "consented_at" => now,
      "expires_at" => expires
    }
  end

  defp save_consent_to_db(_resource, _user_id, _consent) do
    # TODO: Implement saving consent to database
    # This requires the ConsentSettings resource to have a user relationship
    # Implementing apps can handle this in their own LiveView events
    {:ok, nil}
  end
end
