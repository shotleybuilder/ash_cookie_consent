# AshCookieConsent

GDPR-compliant cookie consent management for Ash Framework applications.

## Features

- ✅ **Ash-Native**: Built as an Ash.Resource with full policy support
- ✅ **GDPR Compliant**: Complete audit trail with consent timestamps and policy versions
- ✅ **Phoenix Integration**: Works with traditional controllers and LiveView
- ✅ **Three-Tier Storage**: Browser cookies + Phoenix session + database persistence
- ✅ **Cross-Device Support**: Consent follows users across devices when logged in
- ✅ **Customizable UI**: Phoenix Components with AlpineJS for interactivity
- ✅ **Lightweight**: Minimal dependencies, no heavy JavaScript frameworks

## Installation

### 1. Add Dependency

Add `ash_cookie_consent` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_cookie_consent, "~> 0.1.0"}
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

## Quick Start

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

    attribute :terms, :string do
      description "Policy version identifier"
      allow_nil? false
    end

    attribute :groups, {:array, :string} do
      description "Consented cookie categories"
      default []
    end

    attribute :consented_at, :utc_datetime do
      description "When user provided consent"
    end

    attribute :expires_at, :utc_datetime do
      description "When consent expires"
    end

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

    update :update do
      primary? true
    end
  end
end
```

### 2. Add to Your Router

```elixir
# For traditional Phoenix controllers
pipeline :browser do
  # ... your existing plugs
  plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
end

# For LiveView
defmodule MyAppWeb do
  def router do
    quote do
      # ... existing code
      on_mount {AshCookieConsent.LiveView.Hook, :load_consent}
    end
  end
end
```

### 3. Add Consent Modal to Layout

```heex
<!-- In your root.html.heex or app.html.heex -->
<AshCookieConsent.Components.ConsentModal.consent_modal
  current_consent={@consent}
  cookie_groups={AshCookieConsent.cookie_groups()}
  privacy_url="/privacy"
/>
```

Or import the component for cleaner syntax:

```elixir
# In your MyAppWeb module
def html do
  quote do
    # ...existing imports
    import AshCookieConsent.Components.ConsentModal
    import AshCookieConsent.Components.ConsentScript
  end
end
```

Then use it like:

```heex
<.consent_modal
  current_consent={@consent}
  cookie_groups={AshCookieConsent.cookie_groups()}
/>
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
  src={"https://www.googletagmanager.com/gtag/js?id=#{@ga_id}"}
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

### Customizing the Modal

The consent modal is highly customizable:

#### Custom Text

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
/>
```

#### Custom Styling

```heex
<.consent_modal
  current_consent={@consent}
  cookie_groups={AshCookieConsent.cookie_groups()}
  modal_class="my-custom-modal"
  button_class="my-custom-button"
/>
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

## Component Features

### Consent Modal

The consent modal provides a user-friendly interface for managing cookie preferences:

- **Two-View Design**: Summary view for quick decisions, detailed view for granular control
- **Smart Defaults**: Only required (essential) cookies selected by default
- **Keyboard Navigation**: Full keyboard support (Tab, Enter, Escape to close)
- **Accessibility**: ARIA labels, focus management, and screen reader support
- **Responsive**: Mobile-first design that works on all screen sizes
- **Customizable**: Override text, styling, and behavior

#### Modal Behavior

- Modal automatically shows when no consent has been given
- Users must make a choice (Accept All, Essential Only, or Customize)
- Consent is persisted and modal won't show again until expiration
- Essential cookies cannot be disabled (always selected)
- Form submission can be handled by your application (default: POST to `/consent`)

### Conditional Script Loading

The `ConsentScript` component ensures GDPR compliance by:

- Only loading scripts when user has consented to the specific category
- Supporting both external scripts (src) and inline scripts
- Automatically handling the "essential" category (always loaded)
- Preventing tracking before consent is given

## How It Works

### Three-Tier Storage

1. **Browser Cookie**: Stores consent for anonymous users and provides immediate access
2. **Phoenix Session**: Request-scoped access for performance
3. **Database (Ash)**: Long-term storage for authenticated users with audit trail

### Flow

- **Anonymous User**: Consent stored in browser cookie only
- **User Logs In**: Cookie consent synced to database via Ash
- **User on New Device**: Database consent loaded to cookie on login
- **User Clears Cookies**: On re-login, consent restored from database

This approach provides:
- Fast UX (no database roundtrip on every request)
- Cross-device consistency for authenticated users
- GDPR compliance (audit trail in database)
- Works seamlessly for users who clear cookies

## GDPR Compliance

AshCookieConsent helps you comply with GDPR Article 7(1), which requires you to demonstrate that consent was given:

- ✅ Timestamp of consent (`consented_at`)
- ✅ Policy version consented to (`terms`)
- ✅ Specific categories consented (`groups`)
- ✅ Expiration tracking (`expires_at`)
- ✅ Full audit trail via Ash timestamps

## Implementation Status

**Current Status**: Phase 2 Complete

- ✅ **Phase 1**: Core Ash resource and domain (ConsentSettings)
- ✅ **Phase 2**: Phoenix Components (ConsentModal, ConsentScript) and UI layer
- ⏳ **Phase 3**: Integration layer (Plug, LiveView hooks) - Coming Soon
- ⏳ **Phase 4**: Testing
- ⏳ **Phase 5**: Documentation polish
- ⏳ **Phase 6**: Hex.pm publishing

**Note**: The Plug and LiveView integration examples in this README are aspirational and represent the planned API. Phase 3 will implement these integration points.

## Documentation

Full documentation is available at [HexDocs](https://hexdocs.pm/ash_cookie_consent).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

## Repository

https://github.com/shotleybuilder/ash_cookie_consent

Inspired by [phx_cookie_consent](https://github.com/pzingg/phx_cookie_consent) by pzingg.
