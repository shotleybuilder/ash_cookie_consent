# Extending AshCookieConsent

This guide shows you how to extend and customize AshCookieConsent for advanced use cases.

## Table of Contents

- [Adding User Relationships](#adding-user-relationships)
- [Implementing Database Sync](#implementing-database-sync)
- [Custom Cookie Groups](#custom-cookie-groups)
- [Custom Modal Styling](#custom-modal-styling)
- [Custom Storage Backend](#custom-storage-backend)
- [Audit Trail Implementation](#audit-trail-implementation)

## Adding User Relationships

The default ConsentSettings resource doesn't include a user relationship. Here's how to add it.

### Step 1: Define User Relationship

```elixir
defmodule MyApp.Consent.ConsentSettings do
  use Ash.Resource,
    domain: MyApp.Consent,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "consent_settings"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :terms, :string do
      allow_nil? false
    end

    attribute :groups, {:array, :string} do
      default []
    end

    attribute :consented_at, :utc_datetime
    attribute :expires_at, :utc_datetime

    timestamps()
  end

  relationships do
    # Add user relationship
    belongs_to :user, MyApp.Accounts.User do
      allow_nil? false  # Make it required
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:terms, :groups, :consented_at, :expires_at, :user_id]
    end

    update :update do
      primary? true
      accept [:terms, :groups, :consented_at, :expires_at]
    end

    # Add action to find consent by user
    read :for_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
    end

    # Add action to get latest consent for user
    read :latest_for_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))

      prepare build(sort: [consented_at: :desc], limit: 1)
    end
  end

  identities do
    # Ensure only one active consent per user
    identity :unique_user_consent, [:user_id], pre_check_with: MyApp.Consent
  end
end
```

### Step 2: Create Migration

```elixir
# priv/repo/migrations/XXXXXX_add_user_to_consent_settings.exs
defmodule MyApp.Repo.Migrations.AddUserToConsentSettings do
  use Ecto.Migration

  def change do
    alter table(:consent_settings) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all)
    end

    create index(:consent_settings, [:user_id])
    create unique_index(:consent_settings, [:user_id], name: :unique_user_consent)
  end
end
```

### Step 3: Update User Resource

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    domain: MyApp.Accounts,
    data_layer: AshPostgres.DataLayer

  # ... existing attributes

  relationships do
    # ... existing relationships

    has_many :consent_settings, MyApp.Consent.ConsentSettings do
      destination_attribute :user_id
    end
  end
end
```

## Implementing Database Sync

Now implement the stubbed database functions in the Storage module.

### Option 1: Extend Storage Module

Create a custom storage module that wraps the default one:

```elixir
defmodule MyApp.Consent.Storage do
  @moduledoc """
  Custom storage implementation with database sync for authenticated users.
  """

  alias AshCookieConsent.Storage, as: BaseStorage
  alias MyApp.Consent.ConsentSettings

  @doc """
  Get consent with database fallback for authenticated users.
  """
  def get_consent(conn, opts \\\\ []) do
    # Try base storage first (assigns/session/cookie)
    case BaseStorage.get_consent(conn, opts) do
      nil ->
        # No consent in storage, check database
        case get_user_id(conn, opts) do
          nil -> nil
          user_id -> load_from_database(user_id)
        end

      consent ->
        consent
    end
  end

  @doc """
  Save consent to all tiers including database for authenticated users.
  """
  def put_consent(conn, consent, opts \\\\ []) do
    # Save to base storage (assigns/session/cookie)
    conn = BaseStorage.put_consent(conn, consent, opts)

    # Also save to database if authenticated
    case get_user_id(conn, opts) do
      nil ->
        conn

      user_id ->
        save_to_database(user_id, consent)
        conn
    end
  end

  defp get_user_id(conn, opts) do
    user_id_key = Keyword.get(opts, :user_id_key, :current_user_id)
    Map.get(conn.assigns, user_id_key)
  end

  defp load_from_database(user_id) do
    case ConsentSettings
         |> Ash.Query.for_action(:latest_for_user, %{user_id: user_id})
         |> Ash.read_one() do
      {:ok, nil} ->
        nil

      {:ok, consent_record} ->
        %{
          "terms" => consent_record.terms,
          "groups" => consent_record.groups,
          "consented_at" => consent_record.consented_at,
          "expires_at" => consent_record.expires_at
        }

      {:error, _} ->
        nil
    end
  end

  defp save_to_database(user_id, consent) do
    # Create or update consent record
    attrs = %{
      user_id: user_id,
      terms: consent["terms"] || consent[:terms],
      groups: consent["groups"] || consent[:groups] || [],
      consented_at: consent["consented_at"] || consent[:consented_at],
      expires_at: consent["expires_at"] || consent[:expires_at]
    }

    ConsentSettings
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end
end
```

### Option 2: Custom Plug

Create a custom plug that uses your storage implementation:

```elixir
defmodule MyApp.Consent.Plug do
  @moduledoc """
  Custom consent plug with database sync.
  """

  import Plug.Conn
  alias MyApp.Consent.Storage

  def init(opts), do: AshCookieConsent.Plug.init(opts)

  def call(conn, config) do
    # Use custom storage
    storage_opts = [
      resource: config.resource,
      cookie_name: config.cookie_name,
      session_key: config.session_key,
      user_id_key: config.user_id_key
    ]

    consent = Storage.get_consent(conn, storage_opts)
    show_modal = should_show_modal?(consent)

    conn
    |> assign(:consent, consent)
    |> assign(:show_consent_modal, show_modal)
    |> assign(:cookie_groups, AshCookieConsent.cookie_groups())
  end

  defp should_show_modal?(nil), do: true
  defp should_show_modal?(consent) do
    groups = consent["groups"] || consent[:groups]
    is_nil(groups) || groups == [] || is_expired?(consent)
  end

  defp is_expired?(consent) do
    expires_at = consent["expires_at"] || consent[:expires_at]
    case expires_at do
      %DateTime{} = dt -> DateTime.compare(DateTime.utc_now(), dt) == :gt
      _ -> false
    end
  end
end
```

Then use your custom plug in the router:

```elixir
pipeline :browser do
  # ... other plugs
  plug MyApp.Consent.Plug, resource: MyApp.Consent.ConsentSettings
end
```

## Custom Cookie Groups

Define your own cookie categories to match your application's needs.

### Basic Custom Groups

```elixir
# config/config.exs
config :ash_cookie_consent,
  cookie_groups: [
    %{
      id: "essential",
      label: "Essential Cookies",
      description: "Required for basic site functionality",
      required: true
    },
    %{
      id: "analytics",
      label: "Analytics & Performance",
      description: "Help us understand how you use our site",
      required: false
    },
    %{
      id: "marketing",
      label: "Marketing & Advertising",
      description: "Used to show you relevant advertisements",
      required: false
    },
    %{
      id: "social",
      label: "Social Media",
      description: "Enable social sharing features",
      required: false
    },
    %{
      id: "preferences",
      label: "Preference Cookies",
      description: "Remember your settings and preferences",
      required: false
    }
  ]
```

### Groups with Examples

```elixir
config :ash_cookie_consent,
  cookie_groups: [
    %{
      id: "essential",
      label: "Essential Cookies",
      description: "Required for the website to function properly",
      required: true,
      examples: [
        "Session cookies",
        "CSRF protection",
        "Load balancing"
      ]
    },
    %{
      id: "analytics",
      label: "Analytics Cookies",
      description: "Help us improve our website",
      required: false,
      examples: [
        "Google Analytics",
        "Plausible Analytics",
        "Page view tracking"
      ]
    }
  ]
```

## Custom Modal Styling

Customize the appearance of the consent modal.

### Override Modal Classes

```heex
<.consent_modal
  current_consent={@consent}
  cookie_groups={@cookie_groups}
  modal_class="bg-white/95 backdrop-blur-sm"
  button_class="bg-purple-600 hover:bg-purple-700"
  title="🍪 Cookie Settings"
  description="We value your privacy. Choose which cookies work for you."
/>
```

### Complete Custom Modal

If you need full control, create your own modal component:

```elixir
defmodule MyAppWeb.CustomConsentModal do
  use Phoenix.Component
  import Phoenix.HTML.Form

  def custom_modal(assigns) do
    ~H"""
    <div
      x-data={"{ showModal: #{@show_modal}, selectedGroups: #{Jason.encode!(@selected_groups)} }"}
      x-show="showModal"
      class="your-custom-classes"
    >
      <!-- Your custom modal HTML -->
      <form phx-submit="save_consent">
        <%= for group <- @cookie_groups do %>
          <input
            type="checkbox"
            name="groups[]"
            value={group.id}
            checked={group.id in @selected_groups}
          />
          <%= group.label %>
        <% end %>

        <button type="submit">Save My Choices</button>
      </form>
    </div>
    """
  end
end
```

## Custom Storage Backend

Implement a completely custom storage backend.

```elixir
defmodule MyApp.CustomStorage do
  @behaviour MyApp.ConsentStorageBehaviour

  @impl true
  def get_consent(conn, _opts) do
    # Your custom logic
    # Could use Redis, Memcached, etc.
  end

  @impl true
  def put_consent(conn, consent, _opts) do
    # Your custom logic
    conn
  end

  @impl true
  def delete_consent(conn, _opts) do
    # Your custom logic
    conn
  end
end
```

## Audit Trail Implementation

Track consent changes over time for compliance.

### Create Consent History Resource

```elixir
defmodule MyApp.Consent.ConsentHistory do
  use Ash.Resource,
    domain: MyApp.Consent,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "consent_history"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :terms, :string, allow_nil?: false
    attribute :groups, {:array, :string}, default: []
    attribute :action, :atom, constraints: [one_of: [:granted, :revoked, :updated]]
    attribute :ip_address, :string
    attribute :user_agent, :string
    attribute :consented_at, :utc_datetime

    timestamps()
  end

  relationships do
    belongs_to :user, MyApp.Accounts.User
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
      prepare build(sort: [consented_at: :desc])
    end
  end
end
```

### Track Consent Changes

```elixir
defmodule MyApp.Consent.Tracker do
  alias MyApp.Consent.ConsentHistory

  def track_consent_change(user_id, consent, action, conn) do
    attrs = %{
      user_id: user_id,
      terms: consent["terms"],
      groups: consent["groups"],
      action: action,
      ip_address: get_ip_address(conn),
      user_agent: get_user_agent(conn),
      consented_at: DateTime.utc_now()
    }

    ConsentHistory
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  defp get_ip_address(conn) do
    conn.remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      [] -> "Unknown"
    end
  end
end
```

### Use in Custom Storage

```elixir
def put_consent(conn, consent, opts) do
  conn = BaseStorage.put_consent(conn, consent, opts)

  if user_id = get_user_id(conn, opts) do
    MyApp.Consent.Tracker.track_consent_change(
      user_id,
      consent,
      :updated,
      conn
    )
  end

  conn
end
```

## Advanced Customization

### Custom Expiration Logic

```elixir
defmodule MyApp.Consent.Expiration do
  def calculate_expiration(consent_type) do
    base_date = DateTime.utc_now()

    days =
      case consent_type do
        :full_consent -> 365      # 1 year
        :partial_consent -> 180   # 6 months
        :minimal_consent -> 90    # 3 months
      end

    DateTime.add(base_date, days, :day)
  end
end
```

### Geo-specific Compliance

```elixir
defmodule MyApp.Consent.GeoCompliance do
  def required_groups_for_region(region) do
    case region do
      :eu -> ["essential"]  # GDPR - explicit consent required
      :us -> []             # No mandatory groups
      :uk -> ["essential"]  # UK GDPR
      _ -> ["essential"]
    end
  end

  def consent_expiration_for_region(region) do
    case region do
      :eu -> 365   # 1 year
      :california -> 365  # CCPA
      _ -> 730  # 2 years default
    end
  end
end
```

## Next Steps

- Review [Examples](examples.html) for implementation patterns
- Check [Troubleshooting](troubleshooting.html) if you encounter issues
- Contribute your extensions back to the project!
