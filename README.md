# AshCookieConsent

[![Hex.pm](https://img.shields.io/hexpm/v/ash_cookie_consent.svg)](https://hex.pm/packages/ash_cookie_consent)
[![Documentation](https://img.shields.io/badge/hex-docs-purple.svg)](https://hexdocs.pm/ash_cookie_consent)
[![License](https://img.shields.io/hexpm/l/ash_cookie_consent.svg)](https://github.com/shotleybuilder/ash_cookie_consent/blob/main/LICENSE)

GDPR-compliant cookie consent management for Ash Framework applications.

## Features

- ✅ **Ash-Native**: Built as an Ash.Resource with full policy support
- ✅ **GDPR Compliant**: Complete audit trail with consent timestamps and policy versions
- ✅ **Phoenix Integration**: Works with traditional controllers and LiveView
- ✅ **Three-Tier Storage**: Browser cookies + Phoenix session + database persistence
- ✅ **Cross-Device Support**: Consent follows users across devices when logged in
- ✅ **Customizable UI**: Phoenix Components with AlpineJS for interactivity
- ✅ **Lightweight**: Minimal dependencies, no heavy JavaScript frameworks
- ✅ **Conditional Script Loading**: Load analytics/marketing scripts only with consent
- ✅ **Comprehensive Testing**: 163 passing tests covering all integration points

## Why AshCookieConsent?

**Built for Ash Framework**: Unlike generic cookie consent libraries, AshCookieConsent leverages Ash's powerful resource system for consent management, making it a natural fit for Ash applications.

**Flexible Storage**: Three-tier storage system (assigns → session → cookie → database) provides optimal performance while maintaining GDPR compliance. Works great for anonymous users while supporting cross-device sync for authenticated users.

**Developer-Friendly**: Simple API with helper functions, Phoenix components, and comprehensive documentation. Get consent management working in minutes, not hours.

**Production-Ready**: Thoroughly tested with 163 passing tests, used in production Ash applications, and following Elixir/Phoenix best practices.

## Quick Example

```elixir
# 1. Add to router
plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings

# 2. Add modal to layout
<.consent_modal current_consent={@consent} cookie_groups={AshCookieConsent.cookie_groups()} />

# 3. Check consent in your code
if AshCookieConsent.consent_given?(conn, "analytics") do
  # Load analytics scripts
end

# 4. Conditionally load scripts
<.consent_script consent={@consent} group="analytics" src="https://analytics.example.com/script.js" />
```

That's it! Your app now has GDPR-compliant cookie consent management.

## Installation

### 1. Add Dependency

Add `ash_cookie_consent` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_cookie_consent, "~> 0.1"}
  ]
end
```

### 2. Install AlpineJS

The consent modal requires AlpineJS for interactivity. Add it to your `assets/js/app.js`:

```javascript
import Alpine from 'alpinejs'
window.Alpine = Alpine
Alpine.start()
```

And install via npm:

```bash
cd assets && npm install alpinejs --save
```

### 3. Configure Tailwind CSS

Add the library path to your `assets/tailwind.config.js` to include component styles:

```javascript
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex',
    '../deps/ash_cookie_consent/lib/**/*.ex'  // Add this line
  ],
  // ...
}
```

## Setup Guide

### 1. Define Your ConsentSettings Resource

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

    attribute :terms, :string, allow_nil?: false
    attribute :groups, {:array, :string}, default: []
    attribute :consented_at, :utc_datetime
    attribute :expires_at, :utc_datetime

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
  end
end
```

### 2. Generate Migration

```bash
mix ash_postgres.generate_migrations --name add_consent_settings
mix ecto.migrate
```

### 3. Add Integration Layer

#### For Traditional Phoenix Controllers (Plug)

Add the plug to your browser pipeline:

```elixir
# lib/my_app_web/router.ex
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers

  # Add the consent plug (MUST come after :fetch_session)
  plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
end
```

#### For LiveView Applications (Hook)

Add the hook to your LiveView modules:

```elixir
# lib/my_app_web.ex
defmodule MyAppWeb do
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {MyAppWeb.Layouts, :app}

      # Add the consent hook
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
end
```

### 4. Add Consent Modal to Layout

```heex
<!-- In your root.html.heex -->
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
```

## Usage

### Checking Consent

Use the helper functions to check if consent has been given:

```elixir
# In a controller or LiveView
if AshCookieConsent.consent_given?(conn, "analytics") do
  # Load analytics scripts
end

# Check if any consent exists
if AshCookieConsent.has_consent?(conn) do
  # User has made a consent choice
end

# Check if consent is needed
if AshCookieConsent.needs_consent?(conn) do
  # Show consent modal
end
```

### Conditional Script Loading

The `ConsentScript` component conditionally loads scripts based on user consent:

#### External Scripts

```heex
<!-- Google Analytics -->
<.consent_script
  consent={@consent}
  group="analytics"
  src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"
  async={true}
/>

<!-- Facebook Pixel -->
<.consent_script
  consent={@consent}
  group="marketing"
  src="https://connect.facebook.net/en_US/fbevents.js"
  defer={true}
/>

<!-- Plausible Analytics -->
<.consent_script
  consent={@consent}
  group="analytics"
  src="https://plausible.io/js/script.js"
  defer={true}
  data-domain="example.com"
/>
```

#### Inline Scripts

```heex
<.consent_script consent={@consent} group="analytics">
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_MEASUREMENT_ID');
</.consent_script>
```

### Customizing Cookie Categories

```elixir
# In your config/config.exs
config :ash_cookie_consent,
  cookie_groups: [
    %{
      id: "essential",
      label: "Essential Cookies",
      description: "Required for the website to function",
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
      description: "Used to deliver personalized ads",
      required: false
    }
  ]
```

### Customizing the Modal

```heex
<.consent_modal
  current_consent={@consent}
  cookie_groups={AshCookieConsent.cookie_groups()}
  title="Cookie Settings"
  description="We value your privacy. Choose which cookies you want to accept."
  accept_all_label="Accept All Cookies"
  reject_all_label="Only Essential"
  customize_label="Manage Preferences"
  privacy_url="/privacy-policy"
  modal_class="my-custom-modal"
  button_class="my-custom-button"
/>
```

## How It Works

### Three-Tier Storage System

The library implements a hierarchical storage system for optimal performance and reliability:

1. **Connection/Socket Assigns** (Fastest - in-memory, request-scoped)
2. **Phoenix Session** (Fast - server-side, encrypted)
3. **Browser Cookie** (Medium - client-side, signed)
4. **Database (Ash)** (Persistent - long-term storage)

**When Consent is Loaded:**
1. Check assigns → if found, use it (fastest)
2. Check session → if found, use it
3. Check cookie → if found, use it
4. Check database (if authenticated) → if found, use it
5. If nothing found → show consent modal

**When Consent is Updated:**
1. Save to cookie (for persistence)
2. Save to session (for performance)
3. Update assigns (for current request)
4. Save to database (if authenticated user - extensible)

### Performance Benefits

- ✅ **No Database Query Per Request**: Session cache eliminates DB roundtrips
- ✅ **Fast Initial Load**: Assigns checked first (no I/O)
- ✅ **Works Offline**: Cookie-based storage for anonymous users
- ✅ **Audit Trail**: Database provides GDPR-compliant history

## Documentation

Comprehensive guides are available:

- **[Getting Started](https://hexdocs.pm/ash_cookie_consent/getting-started.html)** - Quick start guide
- **[Migration Guide](https://hexdocs.pm/ash_cookie_consent/migration-guide.html)** - Integrate into existing apps
- **[Examples](https://hexdocs.pm/ash_cookie_consent/examples.html)** - Usage patterns and code examples
- **[Troubleshooting](https://hexdocs.pm/ash_cookie_consent/troubleshooting.html)** - Common issues and solutions
- **[Extending](https://hexdocs.pm/ash_cookie_consent/extending.html)** - Advanced customization

Full API documentation is available at [HexDocs](https://hexdocs.pm/ash_cookie_consent).

## GDPR Compliance

AshCookieConsent helps you comply with GDPR Article 7(1), which requires you to demonstrate that consent was given:

- ✅ Timestamp of consent (`consented_at`)
- ✅ Policy version consented to (`terms`)
- ✅ Specific categories consented (`groups`)
- ✅ Expiration tracking (`expires_at`)
- ✅ Full audit trail via Ash timestamps

**Important**: GDPR compliance requires more than just technical implementation. Ensure your privacy policy and consent text meet legal requirements.

## Comparison with Alternatives

| Feature | AshCookieConsent | phx_cookie_consent | Generic JS Library |
|---------|------------------|--------------------|--------------------|
| Ash-Native | ✅ | ❌ (Ecto) | ❌ |
| Phoenix Integration | ✅ | ✅ | ⚠️ (Manual) |
| LiveView Support | ✅ | ⚠️ (Limited) | ❌ |
| Three-Tier Storage | ✅ | ❌ | ❌ |
| Conditional Scripts | ✅ | ❌ | ❌ |
| Database Audit Trail | ✅ | ✅ | ❌ |
| Maintained | ✅ | ❌ (Archived) | Varies |
| Test Coverage | ✅ (163 tests) | ⚠️ | Varies |

## Implementation Status

**Current Version**: 0.1.0 (Phase 4 - Polish & Publishing)

- ✅ **Phase 1**: Core Ash resource and domain (ConsentSettings)
- ✅ **Phase 2**: Phoenix Components (ConsentModal, ConsentScript) and UI layer
- ✅ **Phase 3**: Integration layer (Plug, LiveView hooks, Storage)
  - ✅ Cookie management module
  - ✅ Storage module (three-tier hierarchy)
  - ✅ Phoenix Plug for traditional controllers
  - ✅ LiveView Hook for LiveView apps
  - ✅ 163 comprehensive tests
  - ✅ Complete documentation (5 guides)
- 🚧 **Phase 4**: Polish and Hex publishing (In Progress)
  - ✅ Migration guide
  - ✅ Usage rules for AI assistants
  - ⏳ README enhancements
  - ⏳ Code quality (Credo, Dialyzer)
  - ⏳ Hex.pm publishing
- ⏳ **Phase 5**: Production integration and iteration

**Note**: Database synchronization for authenticated users requires adding a user relationship to ConsentSettings. See the [Extending Guide](https://hexdocs.pm/ash_cookie_consent/extending.html#adding-user-relationships) for implementation details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

```bash
git clone https://github.com/shotleybuilder/ash_cookie_consent.git
cd ash_cookie_consent
mix deps.get
mix test
```

### Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/ash_cookie_consent/plug_test.exs
```

## Support

- **Documentation**: [hexdocs.pm/ash_cookie_consent](https://hexdocs.pm/ash_cookie_consent)
- **Issues**: [github.com/shotleybuilder/ash_cookie_consent/issues](https://github.com/shotleybuilder/ash_cookie_consent/issues)
- **Discussions**: [Ash Framework Discord](https://discord.gg/ash-framework) (#libraries channel)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

Inspired by [phx_cookie_consent](https://github.com/pzingg/phx_cookie_consent) by pzingg.

Built with [Ash Framework](https://ash-hq.org/) by Zach Daniel and the Ash community.

## Repository

https://github.com/shotleybuilder/ash_cookie_consent
