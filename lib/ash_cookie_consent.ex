defmodule AshCookieConsent do
  @moduledoc """
  GDPR-compliant cookie consent management for Ash Framework applications.

  This module provides helper functions for checking and managing user consent
  for different cookie categories.

  ## Usage

  ### Checking Consent

      # In a controller or LiveView
      if AshCookieConsent.consent_given?(conn, "analytics") do
        # Load analytics scripts
      end

  ### Getting Consent Data

      consent = AshCookieConsent.get_consent(conn)
      # => %{terms: "v1.0", groups: ["essential", "analytics"], consented_at: ~U[...], ...}

  ### Cookie Groups

      groups = AshCookieConsent.cookie_groups()
      # Returns configured cookie groups for display in modal

  ## Configuration

  See `AshCookieConsent.Config` for configuration options.
  """

  alias AshCookieConsent.Config

  @doc """
  Returns the configured cookie groups.

  Returns a list of configured cookie groups. Each group is a map with:
  - `:id` - String identifier for the group (e.g., "essential", "analytics")
  - `:label` - Display label for the group
  - `:description` - Description text
  - `:required` - Boolean indicating if the group is required

  ## Examples

      groups = AshCookieConsent.cookie_groups()
      # Returns list of group maps like:
      # [%{id: "essential", label: "Essential Cookies", ...}]

  """
  defdelegate cookie_groups(), to: Config

  @doc """
  Checks if consent has been given for a specific cookie group.

  ## Parameters

    - `conn_or_socket` - A `Plug.Conn` or `Phoenix.LiveView.Socket`
    - `group` - The cookie group ID to check (e.g., "analytics", "marketing")

  ## Examples

      # In a controller
      if AshCookieConsent.consent_given?(conn, "analytics") do
        # Load analytics scripts
      end

      # In a LiveView
      if AshCookieConsent.consent_given?(socket, "marketing") do
        # Load marketing pixels
      end

  ## Returns

    - `true` if consent has been given for the specified group
    - `false` if consent has not been given or no consent exists
    - `true` for "essential" group (always considered consented)
  """
  def consent_given?(conn_or_socket, group) when is_binary(group) do
    # Essential cookies are always considered consented
    if group == "essential" do
      true
    else
      consent = get_consent(conn_or_socket)

      if consent do
        groups = consent[:groups] || consent["groups"]
        groups && group in groups
      else
        false
      end
    end
  end

  @doc """
  Retrieves the current consent data.

  Checks the following sources in order:
  1. Socket/connection assigns
  2. Session
  3. Cookie

  ## Parameters

    - `conn_or_socket` - A `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Returns

    - A map with consent data (`:terms`, `:groups`, `:consented_at`, `:expires_at`)
    - `nil` if no consent has been given

  ## Examples

      consent = AshCookieConsent.get_consent(conn)
      # => %{terms: "v1.0", groups: ["essential", "analytics"], ...}
  """
  def get_consent(%Plug.Conn{} = conn) do
    # Try assigns first, then session
    conn.assigns[:consent] || get_session(conn, "consent")
  end

  def get_consent(%Phoenix.LiveView.Socket{} = socket) do
    # Get from socket assigns
    socket.assigns[:consent]
  end

  def get_consent(_), do: nil

  @doc """
  Checks if consent exists (any consent has been given).

  ## Parameters

    - `conn_or_socket` - A `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Examples

      if AshCookieConsent.has_consent?(conn) do
        # User has made a consent choice
      else
        # Show consent modal
      end
  """
  def has_consent?(conn_or_socket) do
    consent = get_consent(conn_or_socket)
    !is_nil(consent) && consent != %{}
  end

  @doc """
  Checks if consent has expired.

  ## Parameters

    - `consent` - Consent map with `:expires_at` field

  ## Returns

    - `true` if consent has expired
    - `false` if consent is still valid
    - `false` if no expiration date is set

  ## Examples

      consent = AshCookieConsent.get_consent(conn)
      if AshCookieConsent.consent_expired?(consent) do
        # Show consent modal again
      end
  """
  def consent_expired?(nil), do: true
  def consent_expired?(%{expires_at: nil}), do: false

  def consent_expired?(%{expires_at: expires_at}) when is_struct(expires_at, DateTime) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  def consent_expired?(_), do: true

  @doc """
  Checks if consent needs to be refreshed (doesn't exist or has expired).

  ## Parameters

    - `conn_or_socket` - A `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Examples

      if AshCookieConsent.needs_consent?(conn) do
        # Show consent modal
      end
  """
  def needs_consent?(conn_or_socket) do
    consent = get_consent(conn_or_socket)
    is_nil(consent) || consent_expired?(consent)
  end

  # Private helper to get session data
  # Works with both Plug.Conn (has get_session/2) and Phoenix.LiveView.Socket
  defp get_session(%Plug.Conn{} = conn, key) do
    # Try to get session, but don't fail if session wasn't fetched
    try do
      Plug.Conn.get_session(conn, key)
    rescue
      ArgumentError -> nil
    end
  end

  defp get_session(_, _), do: nil
end
