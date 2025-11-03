defmodule AshCookieConsent.Config do
  @moduledoc """
  Configuration management for AshCookieConsent.

  Provides default cookie group configurations and allows applications to
  customize cookie categories.

  ## Configuration

  In your config/config.exs:

      config :ash_cookie_consent,
        cookie_groups: [
          %{
            id: "essential",
            label: "Essential Cookies",
            description: "Required for the website to function properly",
            required: true
          },
          %{
            id: "analytics",
            label: "Analytics",
            description: "Help us understand how you use our site",
            required: false
          },
          %{
            id: "marketing",
            label: "Marketing",
            description: "Used to deliver personalized advertisements",
            required: false
          }
        ]

  ## Default Groups

  If no configuration is provided, the following default groups are used:
  - Essential (required)
  - Analytics (optional)
  - Marketing (optional)
  """

  @default_cookie_groups [
    %{
      id: "essential",
      label: "Essential Cookies",
      description:
        "These cookies are necessary for the website to function and cannot be disabled. They are usually set in response to actions you take, such as setting privacy preferences or logging in.",
      required: true
    },
    %{
      id: "analytics",
      label: "Analytics Cookies",
      description:
        "These cookies help us understand how visitors interact with our website by collecting and reporting information anonymously. This helps us improve our website.",
      required: false
    },
    %{
      id: "marketing",
      label: "Marketing Cookies",
      description:
        "These cookies are used to track visitors across websites to display relevant advertisements. They may be set by advertising partners through our site.",
      required: false
    }
  ]

  @doc """
  Returns the configured cookie groups.

  Falls back to default groups if no configuration is provided.

  ## Examples

      iex> AshCookieConsent.Config.cookie_groups()
      [
        %{id: "essential", label: "Essential Cookies", ...},
        %{id: "analytics", label: "Analytics Cookies", ...},
        %{id: "marketing", label: "Marketing Cookies", ...}
      ]
  """
  def cookie_groups do
    Application.get_env(:ash_cookie_consent, :cookie_groups, @default_cookie_groups)
  end

  @doc """
  Returns a specific cookie group by ID.

  ## Examples

      iex> AshCookieConsent.Config.get_group("analytics")
      %{id: "analytics", label: "Analytics Cookies", ...}

      iex> AshCookieConsent.Config.get_group("nonexistent")
      nil
  """
  def get_group(group_id) do
    Enum.find(cookie_groups(), &(&1.id == group_id))
  end

  @doc """
  Returns all required cookie groups.

  ## Examples

      iex> AshCookieConsent.Config.required_groups()
      [%{id: "essential", label: "Essential Cookies", required: true, ...}]
  """
  def required_groups do
    Enum.filter(cookie_groups(), & &1.required)
  end

  @doc """
  Returns all optional cookie groups.

  ## Examples

      iex> AshCookieConsent.Config.optional_groups()
      [
        %{id: "analytics", label: "Analytics Cookies", required: false, ...},
        %{id: "marketing", label: "Marketing Cookies", required: false, ...}
      ]
  """
  def optional_groups do
    Enum.filter(cookie_groups(), &(!&1.required))
  end

  @doc """
  Validates cookie group configuration.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> AshCookieConsent.Config.validate_groups([
      ...>   %{id: "essential", label: "Essential", required: true}
      ...> ])
      :ok

      iex> AshCookieConsent.Config.validate_groups([
      ...>   %{label: "Missing ID"}
      ...> ])
      {:error, "Cookie group missing required field: id"}
  """
  def validate_groups(groups) when is_list(groups) do
    required_fields = [:id, :label, :description, :required]

    Enum.reduce_while(groups, :ok, fn group, _acc ->
      case validate_group(group, required_fields) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_group(group, required_fields) do
    missing_fields =
      Enum.reject(required_fields, fn field ->
        Map.has_key?(group, field) || Map.has_key?(group, to_string(field))
      end)

    case missing_fields do
      [] ->
        :ok

      [field | _] ->
        {:error, "Cookie group missing required field: #{field}"}
    end
  end
end
