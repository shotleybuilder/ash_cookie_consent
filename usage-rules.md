# AshCookieConsent Usage Rules

**Version**: 0.1.0
**Purpose**: Guide AI assistants in correctly implementing GDPR-compliant cookie consent management

## Understanding AshCookieConsent

AshCookieConsent is a lightweight, Ash-native library for Phoenix applications that provides:
- GDPR-compliant cookie consent management
- Three-tier storage (assigns → session → cookie → database)
- Phoenix Plug and LiveView Hook integration
- Configurable cookie groups (essential, analytics, marketing, etc.)
- Conditional script loading based on consent
- Audit trail support through Ash resources

**Core Philosophy**: Minimal overhead, maximum flexibility. Store consent in browser cookies for anonymous users, with optional database persistence for authenticated users.

## Project Setup

### Adding the Dependency

```elixir
# mix.exs
def deps do
  [
    {:ash_cookie_consent, "~> 0.1"}
  ]
end
```

### Creating the ConsentSettings Resource

The ConsentSettings resource tracks consent decisions. It MUST use these attribute names:

```elixir
# GOOD: Standard ConsentSettings resource
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

    # REQUIRED attributes with exact names
    attribute :terms, :string, allow_nil?: false
    attribute :groups, {:array, :string}, default: []
    attribute :consented_at, :utc_datetime
    attribute :expires_at, :utc_datetime

    timestamps()
  end

  # REQUIRED actions
  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:terms, :groups, :consented_at, :expires_at]

      # Auto-set timestamps
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
  end
end
```

**WRONG**: Don't rename core attributes or omit required actions:
```elixir
# WRONG: Using different attribute names
attribute :policy_version, :string  # Should be :terms
attribute :categories, {:array, :string}  # Should be :groups
attribute :accepted_at, :utc_datetime  # Should be :consented_at
```

### Adding User Relationships (Optional)

For authenticated users, add a `belongs_to :user` relationship:

```elixir
# GOOD: Optional user relationship
relationships do
  belongs_to :user, MyApp.Accounts.User do
    allow_nil? true  # Allow anonymous consent
    attribute_writable? true
  end
end

actions do
  create :create do
    accept [:terms, :groups, :consented_at, :expires_at, :user_id]  # Add user_id
  end
end
```

## Phoenix Integration

### Router Configuration

The consent Plug MUST come after `:fetch_session`:

```elixir
# GOOD: Correct plug order
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session  # MUST come first
  plug :fetch_live_flash
  plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers

  # Add consent plug after session
  plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
end
```

**WRONG**: Plug before session fetch will fail:
```elixir
# WRONG: Consent plug before fetch_session
plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
plug :fetch_session  # Too late - plug needs session
```

### LiveView Integration

Add the consent hook to your `live_view/0` macro in the web module:

```elixir
# GOOD: Add to web module
# lib/my_app_web.ex
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
    # Import consent components
    import AshCookieConsent.Components.ConsentModal
    import AshCookieConsent.Components.ConsentScript
  end
end
```

**Alternatively**, add to specific LiveViews or live_session:

```elixir
# GOOD: Per-LiveView
defmodule MyAppWeb.HomeLive do
  use MyAppWeb, :live_view
  on_mount {AshCookieConsent.LiveView.Hook, :load_consent}
end

# GOOD: Per live_session
live_session :default,
  on_mount: [{AshCookieConsent.LiveView.Hook, :load_consent}] do
  live "/", HomeLive
end
```

## Layout Configuration

### Adding the Consent Modal

The modal MUST be in `root.html.heex`, not `app.html.heex`:

```heex
<!-- GOOD: In root.html.heex -->
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <!-- ... other head elements ... -->
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

**WRONG**: Don't put in app.html.heex (won't show on first load):
```heex
<!-- WRONG: In app.html.heex -->
<main>
  <%= @inner_content %>
  <.consent_modal ... />  <!-- Won't show properly -->
</main>
```

### Conditional Script Loading

Use `ConsentScript` component for analytics/marketing scripts:

```heex
<!-- GOOD: Conditional script loading -->
<head>
  <!-- Only loads if analytics consent given -->
  <.consent_script
    consent={assigns[:consent]}
    group="analytics"
    src="https://www.googletagmanager.com/gtag/js?id=GA_ID"
    async={true}
  />

  <!-- Inline script with consent check -->
  <.consent_script consent={assigns[:consent]} group="analytics">
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', 'GA_MEASUREMENT_ID');
  </.consent_script>
</head>
```

**WRONG**: Don't use regular script tags (they load regardless of consent):
```heex
<!-- WRONG: Loads without checking consent -->
<script src="https://www.googletagmanager.com/gtag/js?id=GA_ID"></script>
```

## Helper Functions

### Checking Consent

Use the helper functions to check consent status:

```elixir
# GOOD: Check specific group consent
def home(conn, _params) do
  if AshCookieConsent.consent_given?(conn, "analytics") do
    # Load analytics
  end

  render(conn, :home)
end

# GOOD: In LiveView
def mount(_params, _session, socket) do
  analytics_enabled = AshCookieConsent.consent_given?(socket, "analytics")
  {:ok, assign(socket, analytics_enabled: analytics_enabled)}
end
```

**Available Helper Functions**:
- `consent_given?(conn_or_socket, group)` - Check if consent given for group
- `get_consent(conn_or_socket)` - Get full consent map
- `has_consent?(conn_or_socket)` - Check if any consent exists
- `consent_expired?(consent)` - Check if consent has expired
- `needs_consent?(conn_or_socket)` - Check if consent modal should show
- `cookie_groups()` - Get configured cookie groups

### Consent Data Structure

Consent data is a map with these keys (can be atom or string keys):

```elixir
%{
  "terms" => "v1.0",              # Policy version
  "groups" => ["essential", "analytics"],  # Consented groups
  "consented_at" => ~U[2024-01-01 12:00:00Z],
  "expires_at" => ~U[2025-01-01 12:00:00Z]
}

# Or with atom keys:
%{
  terms: "v1.0",
  groups: ["essential", "analytics"],
  consented_at: ~U[2024-01-01 12:00:00Z],
  expires_at: ~U[2025-01-01 12:00:00Z]
}
```

**IMPORTANT**: Helper functions handle both atom and string keys automatically.

## Configuration

### Cookie Groups

Configure cookie categories in your application config:

```elixir
# config/config.exs
config :ash_cookie_consent,
  cookie_groups: [
    %{
      id: "essential",
      label: "Essential Cookies",
      description: "Required for basic site functionality",
      required: true  # Cannot be disabled
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

**IMPORTANT**: The `id` field MUST match the group name used in `consent_given?/2` and `ConsentScript` components.

### Cookie Settings

Customize cookie behavior:

```elixir
# config/config.exs
config :ash_cookie_consent,
  cookie_name: "_my_app_consent",  # Default: "_consent"
  cookie_max_age: 31_536_000,      # Default: 1 year in seconds
  cookie_secure: true,              # Default: false (use true in production)
  cookie_http_only: false,          # Default: false (JS needs access)
  cookie_same_site: "Lax"          # Default: "Lax"
```

## Frontend Requirements

### AlpineJS

The consent modal requires AlpineJS:

```bash
cd assets
npm install alpinejs --save
```

```javascript
// assets/js/app.js
import Alpine from 'alpinejs'
window.Alpine = Alpine
Alpine.start()
```

**WRONG**: Modal won't work without AlpineJS:
```javascript
// WRONG: Not imported
// Alpine features won't work
```

### Tailwind CSS

Add the library path to Tailwind config:

```javascript
// assets/tailwind.config.js
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex',
    '../deps/ash_cookie_consent/lib/**/*.ex'  // IMPORTANT: Add this
  ],
  // ...
}
```

**WRONG**: Without this, modal will have no styling:
```javascript
// WRONG: Library path not included
content: [
  './js/**/*.js',
  '../lib/*_web/**/*.*ex'
  // Missing: '../deps/ash_cookie_consent/lib/**/*.ex'
]
```

## Common Patterns

### Handling Consent Updates in LiveView

```elixir
# GOOD: Handle consent update event
defmodule MyAppWeb.SettingsLive do
  use MyAppWeb, :live_view

  @impl true
  def handle_event("update_consent", params, socket) do
    # Use the hook's helper
    AshCookieConsent.LiveView.Hook.handle_consent_update(
      socket,
      params,
      resource: MyApp.Consent.ConsentSettings
    )
  end

  @impl true
  def handle_event("show_consent_modal", _params, socket) do
    {:noreply, AshCookieConsent.LiveView.Hook.show_modal(socket)}
  end
end
```

### Custom Consent Controller (Traditional Phoenix)

```elixir
# GOOD: Traditional form submission
defmodule MyAppWeb.ConsentController do
  use MyAppWeb, :controller

  def update(conn, params) do
    groups = parse_groups(params)

    consent = %{
      "terms" => params["terms"] || "v1.0",
      "groups" => groups,
      "consented_at" => DateTime.utc_now() |> DateTime.truncate(:second),
      "expires_at" => DateTime.add(DateTime.utc_now(), 365, :day) |> DateTime.truncate(:second)
    }

    conn =
      AshCookieConsent.Storage.put_consent(
        conn,
        consent,
        resource: MyApp.Consent.ConsentSettings
      )

    conn
    |> put_flash(:info, "Consent preferences saved")
    |> redirect(to: "/")
  end

  defp parse_groups(%{"groups" => groups}) when is_list(groups), do: groups
  defp parse_groups(_), do: ["essential"]
end
```

### Accept All / Reject All Shortcuts

```elixir
# GOOD: Quick accept/reject actions
def handle_event("accept_all", _params, socket) do
  all_groups =
    AshCookieConsent.cookie_groups()
    |> Enum.map(& &1.id)

  params = %{
    "terms" => "v1.0",
    "groups" => all_groups
  }

  AshCookieConsent.LiveView.Hook.handle_consent_update(
    socket,
    params,
    resource: MyApp.Consent.ConsentSettings
  )
end

def handle_event("reject_all", _params, socket) do
  params = %{
    "terms" => "v1.0",
    "groups" => ["essential"]  # Only essential
  }

  AshCookieConsent.LiveView.Hook.handle_consent_update(
    socket,
    params,
    resource: MyApp.Consent.ConsentSettings
  )
end
```

## Advanced: Database Sync for Authenticated Users

### Custom Storage Module

Create custom storage to sync consent to database for logged-in users:

```elixir
# GOOD: Custom storage with DB sync
defmodule MyApp.Consent.Storage do
  alias AshCookieConsent.Storage, as: BaseStorage
  alias MyApp.Consent.ConsentSettings

  def get_consent(conn, opts \\ []) do
    # Try base storage first
    case BaseStorage.get_consent(conn, opts) do
      nil ->
        # Check database for authenticated users
        case get_user_id(conn, opts) do
          nil -> nil
          user_id -> load_from_database(user_id)
        end

      consent ->
        consent
    end
  end

  def put_consent(conn, consent, opts \\ []) do
    # Save to base storage (cookie/session)
    conn = BaseStorage.put_consent(conn, consent, opts)

    # Also save to database if authenticated
    if user_id = get_user_id(conn, opts) do
      save_to_database(user_id, consent)
    end

    conn
  end

  defp get_user_id(conn, opts) do
    user_id_key = Keyword.get(opts, :user_id_key, :current_user_id)
    Map.get(conn.assigns, user_id_key)
  end

  defp load_from_database(user_id) do
    case ConsentSettings
         |> Ash.Query.for_action(:latest_for_user, %{user_id: user_id})
         |> Ash.read_one() do
      {:ok, nil} -> nil
      {:ok, record} ->
        %{
          "terms" => record.terms,
          "groups" => record.groups,
          "consented_at" => record.consented_at,
          "expires_at" => record.expires_at
        }
      {:error, _} -> nil
    end
  end

  defp save_to_database(user_id, consent) do
    ConsentSettings
    |> Ash.Changeset.for_create(:create, %{
      user_id: user_id,
      terms: consent["terms"] || consent[:terms],
      groups: consent["groups"] || consent[:groups],
      consented_at: consent["consented_at"] || consent[:consented_at],
      expires_at: consent["expires_at"] || consent[:expires_at]
    })
    |> Ash.create()
  end
end
```

Then use a custom plug that calls your storage module.

## Common Mistakes

### 1. Plug Order

**WRONG**: Consent plug before `:fetch_session`
```elixir
plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
plug :fetch_session  # Too late!
```

**GOOD**: Session must be fetched first
```elixir
plug :fetch_session
plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
```

### 2. Modal Placement

**WRONG**: Modal in `app.html.heex`
```heex
<!-- app.html.heex -->
<main>
  <.consent_modal ... />  <!-- Won't work -->
</main>
```

**GOOD**: Modal in `root.html.heex`
```heex
<!-- root.html.heex -->
<body>
  <%= @inner_content %>
  <.consent_modal ... />  <!-- Correct -->
</body>
```

### 3. Script Loading

**WRONG**: Regular script tag (loads regardless of consent)
```heex
<script src="https://analytics.example.com/script.js"></script>
```

**GOOD**: Conditional loading with ConsentScript
```heex
<.consent_script
  consent={@consent}
  group="analytics"
  src="https://analytics.example.com/script.js"
/>
```

### 4. Attribute Names

**WRONG**: Custom attribute names
```elixir
attribute :policy_version, :string  # Should be :terms
attribute :categories, {:array, :string}  # Should be :groups
```

**GOOD**: Standard attribute names
```elixir
attribute :terms, :string
attribute :groups, {:array, :string}
```

### 5. Missing AlpineJS

**WRONG**: Modal doesn't work without AlpineJS
```javascript
// No Alpine import
```

**GOOD**: AlpineJS properly imported
```javascript
import Alpine from 'alpinejs'
window.Alpine = Alpine
Alpine.start()
```

### 6. Tailwind Configuration

**WRONG**: Library path not in Tailwind content
```javascript
content: [
  '../lib/*_web/**/*.*ex'
  // Missing library path
]
```

**GOOD**: Include library in content array
```javascript
content: [
  '../lib/*_web/**/*.*ex',
  '../deps/ash_cookie_consent/lib/**/*.ex'
]
```

## Testing

### Unit Tests

```elixir
# GOOD: Test consent checking
test "consent_given?/2 returns true for consented groups", %{conn: conn} do
  conn = Plug.Conn.assign(conn, :consent, %{
    "groups" => ["essential", "analytics"]
  })

  assert AshCookieConsent.consent_given?(conn, "analytics")
  refute AshCookieConsent.consent_given?(conn, "marketing")
end
```

### Integration Tests

```elixir
# GOOD: Test full consent flow
test "consent persists across requests", %{conn: conn} do
  # Grant consent
  conn = post(conn, "/consent", %{
    "terms" => "v1.0",
    "groups" => ["essential", "analytics"]
  })

  # Check cookie was set
  assert conn.resp_cookies["_consent"]

  # Make new request
  conn = get(conn, "/")
  assert conn.assigns.consent["groups"] == ["essential", "analytics"]
end
```

## Performance Considerations

- **Plug Overhead**: Should be <1ms per request (consent checked from assigns/session/cookie)
- **Cookie Size**: Consent cookie is typically <500 bytes
- **Database Sync**: Only occurs on consent change, not every request
- **Session Caching**: Consent cached in session after first load

## Migration Notes

When adding to an existing application:

1. **Check Plug Order**: Consent plug MUST come after `:fetch_session`
2. **Update Layouts**: Add modal to `root.html.heex`
3. **Install AlpineJS**: Required for modal interactivity
4. **Configure Tailwind**: Add library path to content array
5. **Run Migrations**: Generate and run `consent_settings` table migration
6. **Test Integration**: Verify modal appears and consent persists

## Security Considerations

- **HttpOnly**: Cookie is NOT HttpOnly (JavaScript needs access for client-side consent checks)
- **Secure**: Set `cookie_secure: true` in production (HTTPS only)
- **SameSite**: Default is "Lax" (appropriate for consent cookies)
- **XSS Protection**: ConsentScript component escapes all user input
- **Cookie Size**: Consent data is minimal (<1KB), reducing attack surface

## GDPR Compliance

AshCookieConsent helps with GDPR compliance by:

1. **Explicit Consent**: Users must actively grant consent (no pre-checked boxes)
2. **Granular Control**: Users can consent to specific cookie categories
3. **Easy Withdrawal**: Users can revoke consent at any time
4. **Audit Trail**: Database persistence provides consent history
5. **Expiration**: Consent expires after 365 days (configurable)

**Note**: GDPR compliance requires more than just technical implementation. Ensure your privacy policy and consent text meet legal requirements.

## Quick Reference

### Essential Files Checklist

- [ ] ConsentSettings resource created with required attributes
- [ ] Plug added to router (after `:fetch_session`)
- [ ] LiveView hook added (if using LiveView)
- [ ] Modal added to `root.html.heex`
- [ ] AlpineJS installed and imported
- [ ] Tailwind config updated with library path
- [ ] Cookie update handler script added
- [ ] Database migration run

### Required Attributes

- `terms` (string) - Policy version
- `groups` (array of strings) - Consented categories
- `consented_at` (utc_datetime) - When consent given
- `expires_at` (utc_datetime) - When consent expires

### Required Actions

- `create` (primary) - Create consent record
- `update` (primary) - Update consent
- `read` - Read consent records
- `destroy` - Delete consent

### Helper Functions

- `consent_given?(conn_or_socket, group)` - Check consent
- `get_consent(conn_or_socket)` - Get full consent
- `has_consent?(conn_or_socket)` - Check if any consent
- `needs_consent?(conn_or_socket)` - Should show modal?
- `cookie_groups()` - Get configured groups

### Component Usage

```heex
<!-- Modal -->
<.consent_modal
  current_consent={@consent}
  cookie_groups={AshCookieConsent.cookie_groups()}
  privacy_url="/privacy"
/>

<!-- Conditional Script -->
<.consent_script
  consent={@consent}
  group="analytics"
  src="https://analytics.example.com/script.js"
/>
```

## Support

For issues or questions:
- GitHub: https://github.com/shotleybuilder/ash_cookie_consent
- Documentation: https://hexdocs.pm/ash_cookie_consent
- Ash Discord: #libraries channel
