defmodule MyAppWeb.ConsentController do
  @moduledoc """
  Example controller for handling consent form submissions in traditional Phoenix apps.

  This demonstrates:
  - Parsing consent form parameters
  - Validating and building consent data
  - Saving consent to cookies and session
  - Optionally saving to database for authenticated users
  - Redirecting back to the referring page
  """

  use MyAppWeb, :controller
  alias AshCookieConsent.{Cookie, Storage}

  @doc """
  Handle consent form submission.

  Expected form params:
  - terms: version string (e.g., "v1.0")
  - groups: list of consented cookie group IDs (e.g., ["essential", "analytics"])
  - _csrf_token: CSRF protection token
  """
  def update(conn, params) do
    # Parse consent groups from params
    groups = parse_groups(params)

    # Build consent data with timestamps
    consent = build_consent(groups, params)

    # Save consent using the Storage module (writes to all tiers)
    conn =
      Storage.put_consent(
        conn,
        consent,
        resource: MyApp.Consent.ConsentSettings,
        cookie_name: "_consent",
        session_key: "consent"
      )

    # Redirect back to where the user came from
    redirect_url = get_redirect_url(conn, params)

    conn
    |> put_flash(:info, "Your cookie preferences have been saved.")
    |> redirect(to: redirect_url)
  end

  @doc """
  Clear consent (e.g., for testing or user-requested deletion).
  """
  def delete(conn, params) do
    conn = Storage.delete_consent(conn)

    redirect_url = get_redirect_url(conn, params)

    conn
    |> put_flash(:info, "Your cookie preferences have been cleared.")
    |> redirect(to: redirect_url)
  end

  # Private helpers

  defp parse_groups(%{"groups" => groups}) when is_list(groups) do
    # Groups already as list
    groups
  end

  defp parse_groups(%{"groups" => groups_json}) when is_binary(groups_json) do
    # Groups as JSON string (from JavaScript)
    case Jason.decode(groups_json) do
      {:ok, groups} when is_list(groups) -> groups
      _ -> ["essential"]  # Fallback to essential only
    end
  end

  defp parse_groups(_params) do
    # No groups provided, default to essential only
    ["essential"]
  end

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
    # Try to redirect back to referring page
    cond do
      redirect = Map.get(params, "redirect_to") ->
        redirect

      referer = get_req_header(conn, "referer") |> List.first() ->
        # Extract path from referer URL
        URI.parse(referer).path || "/"

      true ->
        "/"
    end
  end
end
