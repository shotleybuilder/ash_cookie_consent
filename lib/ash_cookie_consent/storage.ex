defmodule AshCookieConsent.Storage do
  @moduledoc """
  Three-tier storage management for consent data.

  Implements a hierarchical storage system with the following priority:

  ## Read Priority (fastest to slowest)
  1. Connection/Socket assigns (request-scoped, in-memory)
  2. Session (server-side, encrypted)
  3. Cookie (client-side, signed)
  4. Database (persistent, audit trail)

  ## Write Strategy
  When consent is updated, it's written to all applicable tiers:
  1. Database (if user is authenticated)
  2. Cookie (always, for persistence)
  3. Session (always, for performance)
  4. Assigns (always, for immediate access)

  ## Examples

      # Get consent from any available tier
      consent = AshCookieConsent.Storage.get_consent(conn)

      # Save consent to all tiers
      conn = AshCookieConsent.Storage.put_consent(conn, consent, resource: MyApp.ConsentSettings)

      # Delete consent from all tiers
      conn = AshCookieConsent.Storage.delete_consent(conn)
  """

  alias AshCookieConsent.Cookie

  @default_session_key "consent"

  @doc """
  Gets consent from the highest priority available tier.

  Checks in order: assigns → session → cookie → database

  Returns the consent map or nil if no consent found.

  ## Examples

      consent = AshCookieConsent.Storage.get_consent(conn)
      # => %{"terms" => "v1.0", "groups" => ["essential", "analytics"], ...}
  """
  def get_consent(conn, opts \\ []) do
    # 1. Check assigns first (fastest)
    case Map.get(conn.assigns, :consent) do
      nil ->
        # 2. Check session
        case get_from_session(conn, opts) do
          nil ->
            # 3. Check cookie
            case Cookie.get_consent(conn, opts) do
              nil ->
                # 4. Check database (if authenticated)
                get_from_database(conn, opts)

              cookie_consent ->
                cookie_consent
            end

          session_consent ->
            session_consent
        end

      assigns_consent ->
        assigns_consent
    end
  end

  @doc """
  Saves consent to all applicable storage tiers.

  ## Options

    - `:resource` - Ash resource module for database storage
    - `:user_id_key` - Key in assigns for user ID (default: :current_user_id)
    - `:session_key` - Session key for consent (default: "consent")
    - `:cookie_name` - Cookie name (default: "_consent")
    - `:skip_database` - Skip database save even if authenticated (default: false)

  ## Examples

      conn = AshCookieConsent.Storage.put_consent(conn, consent,
        resource: MyApp.ConsentSettings
      )
  """
  def put_consent(conn, consent, opts \\ []) do
    conn
    |> put_to_assigns(consent)
    |> put_to_session(consent, opts)
    |> put_to_cookie(consent, opts)
    |> put_to_database(consent, opts)
  end

  @doc """
  Deletes consent from all storage tiers.

  ## Examples

      conn = AshCookieConsent.Storage.delete_consent(conn)
  """
  def delete_consent(conn, opts \\ []) do
    conn
    |> delete_from_assigns()
    |> delete_from_session(opts)
    |> Cookie.delete_consent(opts)

    # Note: We don't delete from database - we keep audit trail
  end

  @doc """
  Syncs consent from cookie to database on user login.

  Merges existing cookie consent with database consent, preferring database.

  ## Examples

      conn = AshCookieConsent.Storage.sync_on_login(conn,
        resource: MyApp.ConsentSettings,
        user_id: user.id
      )
  """
  def sync_on_login(conn, opts) do
    resource = Keyword.fetch!(opts, :resource)
    user_id = Keyword.fetch!(opts, :user_id)

    # Load consent from database
    db_consent = load_user_consent(resource, user_id)

    # Get cookie consent
    cookie_consent = Cookie.get_consent(conn, opts)

    # Merge strategy: DB wins if it exists and is newer
    merged_consent = merge_consents(db_consent, cookie_consent)

    # Update all tiers with merged consent
    put_consent(conn, merged_consent, opts)
  end

  @doc """
  Syncs consent from database to cookie when consent is loaded.

  Useful for ensuring cookie is up-to-date with latest database consent.

  ## Examples

      conn = AshCookieConsent.Storage.sync_from_database(conn,
        resource: MyApp.ConsentSettings,
        user_id: user.id
      )
  """
  def sync_from_database(conn, opts) do
    resource = Keyword.fetch!(opts, :resource)
    user_id = Keyword.fetch!(opts, :user_id)

    case load_user_consent(resource, user_id) do
      nil ->
        conn

      db_consent ->
        put_consent(conn, db_consent, opts)
    end
  end

  # Private functions

  defp get_from_session(conn, opts) do
    session_key = Keyword.get(opts, :session_key, @default_session_key)

    try do
      Plug.Conn.get_session(conn, session_key)
    rescue
      ArgumentError -> nil
    end
  end

  defp put_to_assigns(conn, consent) do
    Plug.Conn.assign(conn, :consent, consent)
  end

  defp put_to_session(conn, consent, opts) do
    session_key = Keyword.get(opts, :session_key, @default_session_key)

    try do
      Plug.Conn.put_session(conn, session_key, consent)
    rescue
      ArgumentError -> conn
    end
  end

  defp put_to_cookie(conn, consent, opts) do
    Cookie.put_consent(conn, consent, opts)
  end

  defp put_to_database(conn, consent, opts) do
    skip_database = Keyword.get(opts, :skip_database, false)

    if skip_database do
      conn
    else
      case get_user_id(conn, opts) do
        nil ->
          # Not authenticated, skip database
          conn

        user_id ->
          resource = Keyword.get(opts, :resource)

          if resource do
            save_user_consent(resource, user_id, consent)
          end

          conn
      end
    end
  end

  defp get_from_database(conn, opts) do
    case get_user_id(conn, opts) do
      nil ->
        nil

      user_id ->
        resource = Keyword.get(opts, :resource)

        if resource do
          load_user_consent(resource, user_id)
        else
          nil
        end
    end
  end

  defp delete_from_assigns(conn) do
    Map.update!(conn, :assigns, &Map.delete(&1, :consent))
  end

  defp delete_from_session(conn, opts) do
    session_key = Keyword.get(opts, :session_key, @default_session_key)

    try do
      Plug.Conn.delete_session(conn, session_key)
    rescue
      ArgumentError -> conn
    end
  end

  defp get_user_id(conn, opts) do
    user_id_key = Keyword.get(opts, :user_id_key, :current_user_id)
    Map.get(conn.assigns, user_id_key)
  end

  defp load_user_consent(_resource, _user_id) do
    # TODO: Implement user-specific consent loading
    # This requires the ConsentSettings resource to have a user relationship
    # For now, we rely on cookie/session storage
    # Implementing apps can add custom logic by extending Storage module
    nil
  end

  defp save_user_consent(_resource, _user_id, _consent) do
    # TODO: Implement saving consent to database
    # This requires the ConsentSettings resource to have a user relationship
    # Implementing apps can extend this module with custom logic
    {:ok, nil}
  end

  defp merge_consents(nil, cookie_consent), do: cookie_consent
  defp merge_consents(db_consent, nil), do: db_consent

  defp merge_consents(db_consent, cookie_consent) do
    # Compare timestamps to determine which is newer
    db_time = get_timestamp(db_consent, "consented_at")
    cookie_time = get_timestamp(cookie_consent, "consented_at")

    cond do
      is_nil(db_time) -> cookie_consent
      is_nil(cookie_time) -> db_consent
      DateTime.compare(db_time, cookie_time) == :gt -> db_consent
      true -> cookie_consent
    end
  end

  defp get_timestamp(consent, field) do
    case Map.get(consent, field) || Map.get(consent, String.to_atom(field)) do
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
end
