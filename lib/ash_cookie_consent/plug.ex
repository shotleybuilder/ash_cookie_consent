defmodule AshCookieConsent.Plug do
  @moduledoc """
  Phoenix Plug for cookie consent management in traditional controller-based applications.

  This plug loads consent from the three-tier storage system and sets assigns
  for use in templates and controllers.

  ## Usage

  Add to your router pipeline:

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_flash
        plug :protect_from_forgery
        plug :put_secure_browser_headers
        plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
      end

  ## Configuration

  The plug accepts the following options:

    - `:resource` - (required) Ash resource module for consent storage
    - `:cookie_name` - Cookie name (default: "_consent")
    - `:session_key` - Session key (default: "consent")
    - `:user_id_key` - Key in assigns for user ID (default: :current_user_id)
    - `:cookie_opts` - Additional cookie options (see `AshCookieConsent.Cookie`)

  ## Assigns Set

  The plug sets the following assigns:

    - `:consent` - The consent data map (or nil)
    - `:show_consent_modal` - Boolean flag indicating if modal should show
    - `:cookie_groups` - Configured cookie groups

  ## Examples

      # In your router
      plug AshCookieConsent.Plug,
        resource: MyApp.Consent.ConsentSettings,
        cookie_name: "my_consent",
        user_id_key: :user_id

      # In your templates
      <%= if @show_consent_modal do %>
        <.consent_modal
          current_consent={@consent}
          cookie_groups={@cookie_groups}
        />
      <% end %>

      # In your controllers
      if AshCookieConsent.consent_given?(conn, "analytics") do
        # Load analytics
      end
  """

  @behaviour Plug

  alias AshCookieConsent.Storage
  import Plug.Conn

  @impl true
  def init(opts) do
    resource = Keyword.fetch!(opts, :resource)

    %{
      resource: resource,
      cookie_name: Keyword.get(opts, :cookie_name, "_consent"),
      session_key: Keyword.get(opts, :session_key, "consent"),
      user_id_key: Keyword.get(opts, :user_id_key, :current_user_id),
      cookie_opts: Keyword.get(opts, :cookie_opts, [])
    }
  end

  @impl true
  def call(conn, config) do
    # Build options for storage operations
    storage_opts = [
      resource: config.resource,
      cookie_name: config.cookie_name,
      session_key: config.session_key,
      user_id_key: config.user_id_key
    ]

    # Get consent from storage
    consent = Storage.get_consent(conn, storage_opts)

    # Cache consent in session if loaded from cookie (for performance)
    conn =
      if consent && !get_session_consent(conn, storage_opts) do
        put_session(conn, config.session_key, consent)
      else
        conn
      end

    # Check if user is authenticated
    user_id = Map.get(conn.assigns, config.user_id_key)

    # If authenticated and consent exists in cookie but not DB, sync it
    conn =
      if user_id && consent do
        sync_consent_if_needed(conn, consent, user_id, storage_opts)
      else
        conn
      end

    # Reload consent after potential sync
    consent = Storage.get_consent(conn, storage_opts)

    # Determine if consent modal should be shown
    show_modal = should_show_modal?(consent)

    # Set assigns
    conn
    |> assign(:consent, consent)
    |> assign(:show_consent_modal, show_modal)
    |> assign(:cookie_groups, AshCookieConsent.cookie_groups())
  end

  # Private functions

  defp get_session_consent(conn, opts) do
    session_key = Keyword.get(opts, :session_key, "consent")

    try do
      get_session(conn, session_key)
    rescue
      ArgumentError -> nil
    end
  end

  defp sync_consent_if_needed(conn, consent, user_id, opts) do
    # Check if we need to sync from database
    # This happens on login or when user_id is first available
    resource = Keyword.fetch!(opts, :resource)

    # Try to load existing database consent
    db_consent = load_user_consent(resource, user_id)

    cond do
      # No DB consent exists - save cookie consent to DB
      is_nil(db_consent) ->
        save_cookie_to_db(resource, user_id, consent)
        conn

      # DB consent exists and is newer - update cookie
      is_newer?(db_consent, consent) ->
        Storage.put_consent(conn, db_consent, opts)

      # Cookie consent is newer or same - keep cookie
      true ->
        conn
    end
  end

  defp should_show_modal?(nil), do: true

  defp should_show_modal?(consent) when is_map(consent) do
    # Check if consent has groups
    groups = get_field(consent, "groups")

    cond do
      # No groups or empty groups - need consent
      is_nil(groups) -> true
      groups == [] -> true
      # Has groups but expired - need new consent
      consent_expired?(consent) -> true
      # Has valid groups and not expired - don't need consent
      true -> false
    end
  end

  defp should_show_modal?(_), do: true

  # Check if consent has expired (handles both string and atom keys)
  defp consent_expired?(consent) do
    expires_at = get_field(consent, "expires_at")

    case expires_at do
      nil ->
        false

      %DateTime{} = dt ->
        DateTime.compare(DateTime.utc_now(), dt) == :gt

      timestamp when is_binary(timestamp) ->
        case parse_datetime(timestamp) do
          nil -> false
          dt -> DateTime.compare(DateTime.utc_now(), dt) == :gt
        end

      _ ->
        false
    end
  end

  defp load_user_consent(_resource, _user_id) do
    # TODO: Implement user-specific consent loading
    # This requires the ConsentSettings resource to have a user relationship
    # For now, we rely on cookie/session storage
    # Implementing apps can override this by creating custom plug
    nil
  end

  defp save_cookie_to_db(_resource, _user_id, _consent) do
    # TODO: Implement saving consent to database
    # This requires the ConsentSettings resource to have a user relationship
    # Implementing apps can override this behavior
    {:ok, nil}
  end

  defp is_newer?(consent1, consent2) do
    time1 = get_timestamp(consent1, "consented_at")
    time2 = get_timestamp(consent2, "consented_at")

    cond do
      is_nil(time1) -> false
      is_nil(time2) -> true
      true -> DateTime.compare(time1, time2) == :gt
    end
  end

  defp get_timestamp(consent, field) do
    case get_field(consent, field) do
      %DateTime{} = dt -> dt
      timestamp when is_binary(timestamp) -> parse_datetime(timestamp)
      _ -> nil
    end
  end

  defp parse_datetime(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp get_field(consent, field) when is_map(consent) do
    Map.get(consent, field) || Map.get(consent, String.to_atom(field))
  end

  defp get_field(_, _), do: nil
end
