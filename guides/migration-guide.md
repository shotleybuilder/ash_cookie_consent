# Migration Guide

This guide walks you through integrating AshCookieConsent into your Phoenix application, whether you're starting fresh or migrating from an existing setup.

## Table of Contents

- [Prerequisites](#prerequisites)
- [New Phoenix Application](#new-phoenix-application)
- [Existing Phoenix Application](#existing-phoenix-application)
- [Migrating from Other Libraries](#migrating-from-other-libraries)
- [Adding User Relationships](#adding-user-relationships)
- [Verification & Testing](#verification--testing)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before you begin, ensure you have:

- **Elixir 1.14+** and **Erlang/OTP 25+**
- **Phoenix 1.7+** with LiveView
- **Ash 3.0+** installed and configured
- A working Phoenix application (or ready to create one)
- Basic familiarity with Ash Framework

Check your versions:

```bash
elixir --version    # Should show Elixir 1.14+
mix phx.new --version  # Should show Phoenix v1.7+
```

## New Phoenix Application

Starting fresh? This is the easiest path.

### Step 1: Create Phoenix App

```bash
# Create new Phoenix app with Ecto
mix phx.new my_app --database postgres

cd my_app

# Set up database
mix ecto.create
```

### Step 2: Add Dependencies

Add to `mix.exs`:

```elixir
defp deps do
  [
    # ... existing dependencies
    {:ash, "~> 3.0"},
    {:ash_postgres, "~> 2.0"},
    {:ash_cookie_consent, "~> 0.1"}
  ]
end
```

Install dependencies:

```bash
mix deps.get
```

### Step 3: Configure Ash

If you don't have Ash configured yet:

```elixir
# config/config.exs
config :my_app, :ash_domains, [MyApp.Consent]
```

### Step 4: Create Consent Domain

```elixir
# lib/my_app/consent.ex
defmodule MyApp.Consent do
  use Ash.Domain

  resources do
    resource MyApp.Consent.ConsentSettings
  end
end
```

### Step 5: Create ConsentSettings Resource

```elixir
# lib/my_app/consent/consent_settings.ex
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
      description "Terms version the user consented to"
    end

    attribute :groups, {:array, :string} do
      default []
      description "Cookie groups the user consented to"
    end

    attribute :consented_at, :utc_datetime do
      description "When consent was given"
    end

    attribute :expires_at, :utc_datetime do
      description "When consent expires"
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:terms, :groups, :consented_at, :expires_at]

      change fn changeset, _context ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        expires = DateTime.add(now, 365, :day) |> DateTime.truncate(:second)

        changeset
        |> Ash.Changeset.change_attribute(:consented_at, now)
        |> Ash.Changeset.change_attribute(:expires_at, expires)
      end
    end

    update :update do
      primary? true
      accept [:terms, :groups, :expires_at]
    end

    create :grant_consent do
      accept [:terms, :groups]

      change fn changeset, _context ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        expires = DateTime.add(now, 365, :day) |> DateTime.truncate(:second)

        changeset
        |> Ash.Changeset.change_attribute(:consented_at, now)
        |> Ash.Changeset.change_attribute(:expires_at, expires)
      end
    end

    update :revoke_consent do
      accept [:groups]
    end

    read :active_consents do
      filter expr(expires_at > ^DateTime.utc_now())
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :grant_consent
    define :revoke_consent
    define :active_consents
  end
end
```

### Step 6: Generate Migration

```bash
# Generate migration for consent_settings table
mix ash_postgres.generate_migrations --name add_consent_settings
mix ecto.migrate
```

### Step 7: Configure Router

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    # Add consent plug (MUST come after :fetch_session)
    plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    # Add other routes
  end
end
```

### Step 8: Configure LiveView Hook

```elixir
# lib/my_app_web.ex
defmodule MyAppWeb do
  # ...

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {MyAppWeb.Layouts, :app}

      # Add consent hook
      on_mount {AshCookieConsent.LiveView.Hook, :load_consent}

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # ... existing helpers

      # Import consent components
      import AshCookieConsent.Components.ConsentModal
      import AshCookieConsent.Components.ConsentScript
    end
  end
end
```

### Step 9: Add Consent Modal to Layout

```heex
<!-- lib/my_app_web/components/layouts/root.html.heex -->
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <title><%= assigns[:page_title] || "MyApp" %></title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static src={~p"/assets/app.js"}></script>

    <!-- Conditional analytics scripts -->
    <.consent_script
      consent={assigns[:consent]}
      group="analytics"
      src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"
      async={true}
    />
  </head>
  <body>
    <%= @inner_content %>

    <!-- Consent Modal -->
    <.consent_modal
      current_consent={assigns[:consent]}
      cookie_groups={assigns[:cookie_groups] || AshCookieConsent.cookie_groups()}
      privacy_url="/privacy"
    />

    <!-- LiveView Cookie Update Handler -->
    <script>
      window.addEventListener("phx:update-consent-cookie", (e) => {
        const consent = e.detail.consent;
        const expires = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toUTCString();
        document.cookie = `_consent=${encodeURIComponent(consent)}; expires=${expires}; path=/; SameSite=Lax`;
      });
    </script>
  </body>
</html>
```

### Step 10: Install AlpineJS

The consent modal requires AlpineJS for interactivity:

```bash
cd assets
npm install alpinejs --save
```

Update `assets/js/app.js`:

```javascript
// Import AlpineJS
import Alpine from 'alpinejs'
window.Alpine = Alpine
Alpine.start()

// ... rest of your app.js
```

### Step 11: Configure Tailwind

Add the library path to Tailwind config:

```javascript
// assets/tailwind.config.js
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex',
    '../deps/ash_cookie_consent/lib/**/*.ex'  // Add this line
  ],
  // ... rest of config
}
```

### Step 12: Test Your Setup

Start your server:

```bash
mix phx.server
```

Visit `http://localhost:4000` - you should see the consent modal on first visit!

✅ **New Phoenix app setup complete!**

---

## Existing Phoenix Application

Adding AshCookieConsent to an existing Phoenix application.

### Assessment

First, understand what you have:

1. **Do you have Ash Framework installed?**
   - Check `mix.exs` for `{:ash, "~> 3.0"}`
   - If not, see [Ash installation guide](https://hexdocs.pm/ash/get-started.html)

2. **Do you have a data layer configured?**
   - AshPostgres, AshSqlite, etc.
   - ConsentSettings needs a data layer

3. **Are you using LiveView?**
   - Required for best experience
   - Traditional controllers also supported

### Step 1: Add Dependency

```elixir
# mix.exs
defp deps do
  [
    # ... existing dependencies
    {:ash_cookie_consent, "~> 0.1"}
  ]
end
```

```bash
mix deps.get
```

### Step 2: Create Consent Domain (If Needed)

If you don't have a suitable domain for consent:

```elixir
# lib/my_app/consent.ex
defmodule MyApp.Consent do
  use Ash.Domain

  resources do
    resource MyApp.Consent.ConsentSettings
  end
end
```

Add to your Ash domains config:

```elixir
# config/config.exs
config :my_app, :ash_domains, [
  MyApp.YourExistingDomain,
  MyApp.Consent  # Add this
]
```

### Step 3: Create ConsentSettings Resource

Use the same resource definition from the [New Application](#step-5-create-consentsettings-resource) section above.

### Step 4: Generate and Run Migration

```bash
mix ash_postgres.generate_migrations --name add_consent_settings
mix ecto.migrate
```

### Step 5: Add Plug to Router

**Important**: The consent plug MUST come after `:fetch_session`:

```elixir
# lib/my_app_web/router.ex
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session        # Must come before consent plug
  plug :fetch_live_flash
  plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers

  # Add consent plug here
  plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
end
```

### Step 6: Update Web Module

If using LiveView, add the hook to your web module:

```elixir
# lib/my_app_web.ex
def live_view do
  quote do
    use Phoenix.LiveView,
      layout: {MyAppWeb.Layouts, :app}

    # Add this line
    on_mount {AshCookieConsent.LiveView.Hook, :load_consent}

    unquote(html_helpers())
  end
end

defp html_helpers do
  quote do
    # ... existing helpers

    # Add these imports
    import AshCookieConsent.Components.ConsentModal
    import AshCookieConsent.Components.ConsentScript
  end
end
```

### Step 7: Add Modal to Layout

Add the consent modal to your root layout (see [Step 9](#step-9-add-consent-modal-to-layout) above for full code).

**Key points:**
- Modal should be in `root.html.heex`, not `app.html.heex`
- Add cookie update handler script
- Import consent components

### Step 8: Install AlpineJS (If Not Already Installed)

Check if you have AlpineJS:

```bash
cd assets
cat package.json | grep alpinejs
```

If not found:

```bash
npm install alpinejs --save
```

And add to `assets/js/app.js`:

```javascript
import Alpine from 'alpinejs'
window.Alpine = Alpine
Alpine.start()
```

### Step 9: Update Tailwind Config

```javascript
// assets/tailwind.config.js
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex',
    '../deps/ash_cookie_consent/lib/**/*.ex'  // Add this
  ],
  // ...
}
```

Rebuild assets:

```bash
cd assets
npm run build
# Or just restart: mix phx.server
```

### Step 10: Test Integration

1. Clear your browser cookies
2. Visit your app
3. You should see the consent modal
4. Accept/customize consent
5. Refresh - modal should not reappear
6. Check cookie in DevTools (Application → Cookies → `_consent`)

✅ **Existing app migration complete!**

---

## Migrating from Other Libraries

### From phx_cookie_consent

If you're migrating from `phx_cookie_consent`:

#### Database Migration

The schemas are similar but not identical. Here's a migration path:

```elixir
# priv/repo/migrations/XXXXXX_migrate_to_ash_cookie_consent.exs
defmodule MyApp.Repo.Migrations.MigrateToAshCookieConsent do
  use Ecto.Migration

  def up do
    # Rename existing table
    rename table("phx_cookie_consents"), to: table("consent_settings")

    # Update column names if needed
    alter table("consent_settings") do
      # phx_cookie_consent used different column names
      # Adjust based on your actual schema
    end

    # Update data format
    execute """
    UPDATE consent_settings
    SET groups = CASE
      WHEN groups IS NULL THEN '[]'::jsonb
      ELSE groups
    END
    """
  end

  def down do
    rename table("consent_settings"), to: table("phx_cookie_consents")
  end
end
```

#### Code Migration

Replace phx_cookie_consent components:

**Before:**
```elixir
<PhxCookieConsent.Modal.render consent={@consent} />
```

**After:**
```elixir
<.consent_modal
  current_consent={@consent}
  cookie_groups={AshCookieConsent.cookie_groups()}
/>
```

#### Configuration Migration

**Before (phx_cookie_consent):**
```elixir
# config/config.exs
config :phx_cookie_consent,
  categories: [:essential, :analytics, :marketing]
```

**After (ash_cookie_consent):**
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
      label: "Analytics Cookies",
      description: "Help us understand how you use our site",
      required: false
    },
    %{
      id: "marketing",
      label: "Marketing Cookies",
      description: "Used to show you relevant advertisements",
      required: false
    }
  ]
```

### From Custom Cookie Implementation

If you have a custom cookie consent implementation:

#### Step 1: Map Your Data Model

Create a mapping from your current schema to ConsentSettings:

| Your Field | ConsentSettings Field | Notes |
|------------|----------------------|-------|
| `user_id` | `user_id` (if adding relationship) | See [Adding User Relationships](#adding-user-relationships) |
| `accepted_at` | `consented_at` | Rename during migration |
| `categories` | `groups` | May need JSON transformation |
| `policy_version` | `terms` | String field |
| `valid_until` | `expires_at` | DateTime field |

#### Step 2: Create Data Migration

```elixir
# lib/my_app/release.ex
defmodule MyApp.Release do
  def migrate_consent_data do
    # Load your old consent records
    old_consents = MyApp.Repo.all(MyApp.OldConsent)

    # Transform and create new records
    Enum.each(old_consents, fn old ->
      MyApp.Consent.ConsentSettings
      |> Ash.Changeset.for_create(:create, %{
        terms: old.policy_version,
        groups: transform_categories(old.categories),
        consented_at: old.accepted_at,
        expires_at: old.valid_until
      })
      |> Ash.create!()
    end)
  end

  defp transform_categories(categories) do
    # Transform your old category format to groups array
    # Example: [:analytics, :marketing] -> ["analytics", "marketing"]
    Enum.map(categories, &to_string/1)
  end
end
```

Run migration:

```bash
mix run -e "MyApp.Release.migrate_consent_data()"
```

#### Step 3: Update Your Code

Replace your custom consent checking code:

**Before:**
```elixir
if MyApp.Consent.has_category?(conn, :analytics) do
  # ...
end
```

**After:**
```elixir
if AshCookieConsent.consent_given?(conn, "analytics") do
  # ...
end
```

### From GDPR Tracking Library

If you're using a different GDPR library:

1. **Export existing consent records** to CSV/JSON
2. **Create import script** to transform to ConsentSettings format
3. **Test import** on staging environment first
4. **Run import** on production during maintenance window
5. **Verify data integrity** with audit queries

Example import script:

```elixir
# lib/mix/tasks/import_consents.ex
defmodule Mix.Tasks.ImportConsents do
  use Mix.Task

  def run([file_path]) do
    Mix.Task.run("app.start")

    file_path
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Enum.each(&import_consent/1)
  end

  defp import_consent(row) do
    MyApp.Consent.ConsentSettings
    |> Ash.Changeset.for_create(:create, %{
      terms: row["policy_version"],
      groups: String.split(row["groups"], ","),
      consented_at: parse_datetime(row["consented_at"]),
      expires_at: parse_datetime(row["expires_at"])
    })
    |> Ash.create!()
  end

  defp parse_datetime(str) do
    {:ok, dt, _} = DateTime.from_iso8601(str)
    dt
  end
end
```

Run import:

```bash
mix import_consents consents_export.csv
```

---

## Adding User Relationships

For authenticated users, you may want to link consent records to user accounts. This enables:

- Cross-device consent synchronization
- User-specific consent history
- GDPR data export for users
- Consent management in user settings

### Step 1: Update ConsentSettings Resource

```elixir
# lib/my_app/consent/consent_settings.ex
defmodule MyApp.Consent.ConsentSettings do
  use Ash.Resource,
    domain: MyApp.Consent,
    data_layer: AshPostgres.DataLayer

  # ... existing postgres config

  attributes do
    # ... existing attributes
  end

  relationships do
    # Add user relationship
    belongs_to :user, MyApp.Accounts.User do
      allow_nil? true  # Allow anonymous consent (no user)
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:terms, :groups, :consented_at, :expires_at, :user_id]  # Add user_id

      # ... existing change
    end

    update :update do
      primary? true
      accept [:terms, :groups, :expires_at]
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

    # ... other actions
  end

  identities do
    # Optional: Ensure only one active consent per user
    identity :unique_user_consent, [:user_id], pre_check_with: MyApp.Consent
  end

  # ... code_interface
end
```

### Step 2: Update User Resource

```elixir
# lib/my_app/accounts/user.ex
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

### Step 3: Generate Migration

```bash
mix ash_postgres.generate_migrations --name add_user_to_consent_settings
```

This will generate:

```elixir
# priv/repo/migrations/XXXXXX_add_user_to_consent_settings.exs
defmodule MyApp.Repo.Migrations.AddUserToConsentSettings do
  use Ecto.Migration

  def change do
    alter table(:consent_settings) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all)
    end

    create index(:consent_settings, [:user_id])
  end
end
```

Run migration:

```bash
mix ecto.migrate
```

### Step 4: Create Custom Storage Module

Implement database sync for authenticated users:

```elixir
# lib/my_app/consent/storage.ex
defmodule MyApp.Consent.Storage do
  @moduledoc """
  Custom storage implementation with database sync for authenticated users.
  """

  alias AshCookieConsent.Storage, as: BaseStorage
  alias MyApp.Consent.ConsentSettings

  def get_consent(conn, opts \\ []) do
    # Try base storage first (assigns/session/cookie)
    case BaseStorage.get_consent(conn, opts) do
      nil ->
        # No consent in storage, check database for authenticated users
        case get_user_id(conn, opts) do
          nil -> nil
          user_id -> load_from_database(user_id)
        end

      consent ->
        consent
    end
  end

  def put_consent(conn, consent, opts \\ []) do
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

### Step 5: Create Custom Plug

```elixir
# lib/my_app_web/plugs/consent_plug.ex
defmodule MyAppWeb.Plugs.ConsentPlug do
  @moduledoc """
  Custom consent plug with database sync for authenticated users.
  """

  import Plug.Conn
  alias MyApp.Consent.Storage

  def init(opts), do: opts

  def call(conn, opts) do
    config = %{
      resource: opts[:resource],
      cookie_name: opts[:cookie_name] || "_consent",
      session_key: opts[:session_key] || "consent",
      user_id_key: opts[:user_id_key] || :current_user_id
    }

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

### Step 6: Use Custom Plug in Router

```elixir
# lib/my_app_web/router.ex
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  # ... other plugs

  # Use your custom plug instead of the default
  plug MyAppWeb.Plugs.ConsentPlug, resource: MyApp.Consent.ConsentSettings
end
```

### Step 7: Test User-Linked Consent

1. **Logged out**: Consent stored in cookie only
2. **Log in**: Consent synced to database with user_id
3. **Log out and back in**: Consent restored from database
4. **Different device**: Consent available after login

✅ **User relationships complete!**

---

## Verification & Testing

### Manual Testing Checklist

- [ ] **First Visit**: Modal appears for new users
- [ ] **Accept All**: Modal closes, consent saved
- [ ] **Refresh Page**: Modal doesn't reappear
- [ ] **Check Cookie**: `_consent` cookie present in DevTools
- [ ] **Analytics Load**: Scripts load only with consent
- [ ] **Customize**: Can select individual categories
- [ ] **Reject All**: Only essential cookies consented
- [ ] **Session**: Consent persists across pages
- [ ] **Expiration**: Modal reappears after 365 days (test with modified expiry)

### Database Verification

Check that consent records are being created:

```elixir
# In iex -S mix
MyApp.Consent.ConsentSettings
|> Ash.Query.for_action(:read)
|> Ash.read!()
```

You should see your consent records.

### Automated Testing

Add tests to your application:

```elixir
# test/my_app_web/integration/consent_test.exs
defmodule MyAppWeb.Integration.ConsentTest do
  use MyAppWeb.ConnCase

  test "consent modal appears on first visit", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Cookie Preferences"
  end

  test "consent persists across requests", %{conn: conn} do
    # Grant consent
    conn = post(conn, "/consent", %{
      "terms" => "v1.0",
      "groups" => ["essential", "analytics"]
    })

    # Make another request
    conn = get(conn, "/")
    assert conn.assigns.consent["groups"] == ["essential", "analytics"]
  end

  test "analytics script loads with consent", %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, %{
      "consent" => %{
        "terms" => "v1.0",
        "groups" => ["essential", "analytics"]
      }
    })

    conn = get(conn, "/")
    html = html_response(conn, 200)

    assert html =~ "googletagmanager.com"
  end
end
```

### Performance Testing

The consent plug should add minimal overhead:

```elixir
# Benchmark consent checking
Benchee.run(%{
  "consent check" => fn ->
    AshCookieConsent.consent_given?(conn, "analytics")
  end
})
```

Should be < 1ms per check.

---

## Troubleshooting

### Modal Doesn't Appear

**Problem**: Consent modal not showing on first visit.

**Checklist**:

1. **Verify Plug Order**: Plug must come after `:fetch_session`
   ```elixir
   plug :fetch_session
   plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
   ```

2. **Check Assigns**: In your controller/LiveView:
   ```elixir
   IO.inspect(conn.assigns.show_consent_modal)  # Should be true
   IO.inspect(conn.assigns.consent)              # Should be nil
   ```

3. **Verify Modal in Layout**: Modal must be in `root.html.heex`, not `app.html.heex`

4. **Check AlpineJS**: Look for JavaScript errors in console
   ```javascript
   // Should see Alpine in console
   window.Alpine
   ```

5. **Verify Tailwind**: Check if styles are applied
   ```bash
   cd assets && npm run build
   ```

### Consent Not Persisting

**Problem**: User has to accept cookies on every visit.

**Checklist**:

1. **Check Cookie in Browser**: DevTools → Application → Cookies → `_consent`

2. **Verify Session Configuration**:
   ```elixir
   # config/config.exs
   config :my_app, MyAppWeb.Endpoint,
     # ... other config
     live_view: [signing_salt: "..."]
   ```

3. **Test Cookie Writing**:
   ```elixir
   # In IEx
   consent = %{"terms" => "v1.0", "groups" => ["essential"]}
   encoded = Jason.encode!(consent)
   # Should produce valid JSON
   ```

4. **Check Browser Settings**: Ensure cookies aren't blocked

### Migration Fails

**Problem**: `mix ecto.migrate` fails with errors.

**Solutions**:

1. **Check Resource Config**: Ensure `repo` is correctly set:
   ```elixir
   postgres do
     table "consent_settings"
     repo MyApp.Repo  # Must match your repo
   end
   ```

2. **Run Generate Again**:
   ```bash
   mix ash_postgres.generate_migrations --name add_consent_settings --drop
   ```

3. **Check Table Doesn't Exist**:
   ```bash
   mix ecto.rollback
   mix ecto.migrate
   ```

4. **Manual Migration**: If auto-generation fails, create manual migration:
   ```elixir
   defmodule MyApp.Repo.Migrations.CreateConsentSettings do
     use Ecto.Migration

     def change do
       create table(:consent_settings, primary_key: false) do
         add :id, :uuid, primary_key: true
         add :terms, :string, null: false
         add :groups, {:array, :string}, default: []
         add :consented_at, :utc_datetime
         add :expires_at, :utc_datetime

         timestamps()
       end
     end
   end
   ```

### User Relationship Issues

**Problem**: User consent not syncing to database.

**Checklist**:

1. **Verify User ID in Assigns**:
   ```elixir
   IO.inspect(conn.assigns.current_user_id)  # Should be present when logged in
   ```

2. **Check Custom Storage**: If using custom storage module, verify it's being called:
   ```elixir
   # Add logging
   require Logger
   Logger.debug("Saving consent for user #{user_id}")
   ```

3. **Test Database Write**:
   ```elixir
   # In IEx
   MyApp.Consent.ConsentSettings.create(%{
     user_id: "some-uuid",
     terms: "v1.0",
     groups: ["essential"]
   })
   ```

4. **Check Foreign Key**: Ensure user_id references valid user

### AlpineJS Not Working

**Problem**: Modal doesn't respond to clicks.

**Solutions**:

1. **Verify Installation**:
   ```bash
   cd assets
   cat package.json | grep alpinejs
   npm list alpinejs
   ```

2. **Check Import**:
   ```javascript
   // assets/js/app.js
   import Alpine from 'alpinejs'
   window.Alpine = Alpine
   Alpine.start()
   ```

3. **Check for Errors**: Browser console should show no AlpineJS errors

4. **Test Alpine**: In browser console:
   ```javascript
   window.Alpine  // Should return object
   ```

### Tailwind Styles Missing

**Problem**: Consent modal has no styling.

**Solutions**:

1. **Add Library to Config**:
   ```javascript
   // assets/tailwind.config.js
   content: [
     '../deps/ash_cookie_consent/lib/**/*.ex'
   ]
   ```

2. **Rebuild Assets**:
   ```bash
   cd assets
   npm run build
   # Or restart server
   ```

3. **Check for CSS Purging**: Ensure Tailwind isn't purging library styles

4. **Verify CSS Import**:
   ```css
   /* assets/css/app.css */
   @import "tailwindcss/base";
   @import "tailwindcss/components";
   @import "tailwindcss/utilities";
   ```

### Performance Issues

**Problem**: App feels slower after adding consent management.

**Checklist**:

1. **Profile Plug Overhead**:
   ```elixir
   # Plug should be < 1ms
   :timer.tc(fn -> AshCookieConsent.Plug.call(conn, opts) end)
   ```

2. **Check Database Queries**: If using user relationships, ensure no N+1 queries

3. **Review Session Size**: Consent data should be small (< 1KB)

4. **Check Cookie Size**: Large cookies slow down requests

5. **Optimize Database Sync**: Only sync on consent change, not every request

### Getting Help

If you're still stuck:

1. **Check Documentation**: Read [Getting Started](getting-started.html) and [Examples](examples.html)
2. **Review Tests**: Look at `test/` directory for working examples
3. **Check GitHub Issues**: [github.com/shotleybuilder/ash_cookie_consent/issues](https://github.com/shotleybuilder/ash_cookie_consent/issues)
4. **Ask on Discord**: Ash Framework Discord server
5. **Open an Issue**: Provide minimal reproduction case

---

## Next Steps

After successful migration:

1. **Customize UI**: See [Extending Guide](extending.html) for custom styling
2. **Configure Groups**: Define your cookie categories in config
3. **Add Analytics**: Use `ConsentScript` component for conditional loading
4. **Test GDPR Compliance**: Verify audit trail and consent management
5. **Deploy**: Test in staging before production

✅ **Migration complete! Your app now has GDPR-compliant cookie consent management.**
