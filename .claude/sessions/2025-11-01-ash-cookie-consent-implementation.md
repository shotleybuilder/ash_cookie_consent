# ash_cookie_consent - Implementation & Hex Publishing

**Filename**: `2025-11-01-ash-cookie-consent-implementation.md`

## Session Overview

**Start Time**: 2025-11-01

Building `ash_cookie_consent` - a lightweight, Ash-native cookie consent library for Phoenix applications with GDPR compliance.

## Goals

- Design and implement ash_cookie_consent library
- Create reusable package for EHS Enforcement + Sertantai projects
- Publish to Hex.pm for Ash community
- Follow Ash Framework best practices
- Ensure GDPR compliance with audit trail

## Background

From previous research session (2025-11-01-gdpr-cookie-consent.md):
- No existing Ash-native cookie consent library
- phx_cookie_consent exists as reference (Ecto-based, unmaintained, full app)
- Building from scratch preferred over forking
- Database persistence required for GDPR audit trail

## Implementation Plan

### Phase 1: Project Setup & Core Architecture (Day 1)

**1.1 Create Library Project**
- [ ] Create new Mix project: `mix new ash_cookie_consent`
- [ ] Initialize git repository
- [ ] Set up GitHub repository (sertantai/ash_cookie_consent)
- [ ] Configure mix.exs with dependencies
- [ ] Add MIT license
- [ ] Create initial README.md

**1.2 Dependencies**
Required packages:
```elixir
{:ash, "~> 3.0"},
{:ash_postgres, "~> 2.0"},  # Optional data layer
{:phoenix, "~> 1.7"},
{:phoenix_live_view, "~> 1.0"},
{:jason, "~> 1.4"}
```

**1.3 Define Ash Resource**
- [ ] Create `AshCookieConsent.ConsentSettings` resource
- [ ] Define attributes (terms, groups, consented_at, expires_at)
- [ ] Add actions (create, read, update, destroy)
- [ ] Configure relationships (belongs_to user)
- [ ] Add validations and policies

**Resource Schema** (based on phx_cookie_consent):
```elixir
attributes do
  uuid_primary_key :id

  attribute :terms, :string do
    description "Policy version identifier"
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
  belongs_to :user, YourApp.Accounts.User
end
```

### Phase 2: Phoenix Components & UI (Day 1-2)

**2.1 Core Components**
- [ ] Create `AshCookieConsent.Components.ConsentModal`
  - Summary modal (Accept All / Reject All)
  - Details modal (granular category selection)
- [ ] Add AlpineJS integration for interactivity
- [ ] Style with Tailwind CSS (configurable)
- [ ] Add keyboard navigation (Escape to close)
- [ ] Implement click-outside dismissal

**2.2 Conditional Script Loading**
- [ ] Create `AshCookieConsent.Components.ConsentScript`
- [ ] Helper for conditionally loading scripts based on consent
- [ ] Examples for Google Analytics, Google Tag Manager

**Component API**:
```elixir
<AshCookieConsent.Components.ConsentModal.summary
  current_consent={@consent}
  on_accept={&handle_consent/1}
  on_reject={&handle_consent/1}
/>

<AshCookieConsent.Components.ConsentScript.render
  consent={@consent}
  group="analytics"
  src="https://www.googletagmanager.com/gtag/js?id=GA_ID"
/>
```

### Phase 3: Integration Layer (Day 2)

**3.1 Plugs & Hooks**
- [ ] Create `AshCookieConsent.Plug` for traditional Phoenix
  - Reads consent from cookie
  - Loads from database for authenticated users
  - Sets `:show_consent_modal` assign
- [ ] Create `AshCookieConsent.LiveView.Hook` for LiveView
  - `on_mount/4` callback for LiveView routes
  - Syncs consent state to socket assigns

**3.2 Cookie/Session/DB Sync**
- [ ] Implement three-tier storage pattern
  - Browser cookie (anonymous users)
  - Phoenix session (request-scoped)
  - Database via Ash (authenticated users)
- [ ] Sync logic on login/logout
- [ ] Restore from DB when cookie cleared

**3.3 Helper Functions**
- [ ] `AshCookieConsent.get_consent/1` - Get current consent
- [ ] `AshCookieConsent.update_consent/2` - Update consent
- [ ] `AshCookieConsent.consent_given?/2` - Check if category consented
- [ ] `AshCookieConsent.drop_unconsented_cookies/2` - Remove non-consented cookies

### Phase 4: Testing (Day 2)

**4.1 Unit Tests**
- [ ] Test Ash resource actions
- [ ] Test consent validation logic
- [ ] Test expiration handling
- [ ] Test policy enforcement

**4.2 Integration Tests**
- [ ] Test plug integration
- [ ] Test LiveView hook integration
- [ ] Test cookie/session/DB sync
- [ ] Test consent modal rendering

**4.3 Example App**
- [ ] Create test Phoenix app
- [ ] Demonstrate integration patterns
- [ ] Test with authenticated and anonymous users

### Phase 5: Documentation (Day 2)

**5.1 Code Documentation**
- [ ] Add @moduledoc to all modules
- [ ] Add @doc to all public functions
- [ ] Add @typedoc for custom types
- [ ] Include code examples in docs

**5.2 User Guides**
- [ ] Installation guide
- [ ] Quick start tutorial
- [ ] Integration with existing Ash apps
- [ ] Customization guide (UI, categories, etc.)
- [ ] GDPR compliance notes

**5.3 README.md**
- [ ] Feature overview
- [ ] Installation instructions
- [ ] Basic usage example
- [ ] Configuration options
- [ ] Links to full documentation

### Phase 6: Hex.pm Publishing (Day 2-3)

**6.1 Pre-publish Checklist**
- [ ] Verify all tests pass
- [ ] Run `mix format`
- [ ] Run `mix credo` (if added)
- [ ] Run `mix dialyzer` (if added)
- [ ] Generate ExDocs: `mix docs`
- [ ] Review generated documentation
- [ ] Verify README renders correctly on Hex

**6.2 Package Metadata**
Update mix.exs:
```elixir
def project do
  [
    app: :ash_cookie_consent,
    version: "0.1.0",
    elixir: "~> 1.14",
    description: "GDPR-compliant cookie consent for Ash Framework applications",
    package: package(),
    docs: docs(),
    # ...
  ]
end

defp package do
  [
    name: "ash_cookie_consent",
    licenses: ["MIT"],
    links: %{
      "GitHub" => "https://github.com/sertantai/ash_cookie_consent"
    },
    maintainers: ["Jason [Sertantai]"],
    files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
  ]
end

defp docs do
  [
    main: "readme",
    extras: ["README.md", "CHANGELOG.md"]
  ]
end
```

**6.3 Publish**
- [ ] Create Hex.pm account (if needed)
- [ ] Run `mix hex.publish`
- [ ] Verify package on Hex.pm
- [ ] Test installation from Hex

**6.4 Announcement**
- [ ] Post to Elixir Forum
- [ ] Share on Ash Discord
- [ ] Tweet/social media (optional)

### Phase 7: Integration into EHS Enforcement (Day 3)

**7.1 Install Package**
- [ ] Add to mix.exs: `{:ash_cookie_consent, "~> 0.1"}`
- [ ] Run `mix deps.get`

**7.2 Configure**
- [ ] Set up ConsentSettings resource
- [ ] Add to router pipeline
- [ ] Add LiveView hooks
- [ ] Customize UI to match app design

**7.3 Deploy**
- [ ] Test in development
- [ ] Run migrations
- [ ] Deploy to Hetzner
- [ ] Verify GDPR compliance

## Technical Decisions

### Design Choices

**Ash-Native vs Agnostic**:
- ✅ Use Ash.Resource for domain model
- ✅ Support any Ash data layer (Postgres, SQLite, etc.)
- ✅ Leverage Ash policies for authorization
- ⚠️ Keep UI components Phoenix-agnostic (works with any Ash app)

**Storage Strategy**:
- Cookie: Immediate UX, works for anonymous users
- Session: Request-scoped, no persistence
- Database: Audit trail, cross-device, GDPR proof

**UI Framework**:
- AlpineJS for interactivity (lightweight, no build step)
- Tailwind CSS classes (configurable/overridable)
- Phoenix Components (works with LiveView and controllers)

**Extensibility**:
- Configurable cookie categories (default: essential, analytics, marketing)
- Customizable modal templates
- Pluggable consent storage backend
- Hooks for custom business logic

## Success Criteria

- [ ] Library published to Hex.pm
- [ ] 100% documented (ExDoc)
- [ ] >80% test coverage
- [ ] Successfully integrated into EHS Enforcement
- [ ] Reusable in Sertantai project
- [ ] Positive community feedback

## Reference Materials

- phx_cookie_consent: https://github.com/pzingg/phx_cookie_consent
- GDPR Article 7: https://gdpr-info.eu/art-7-gdpr/
- Ash Framework: https://ash-hq.org/
- Phoenix Components: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html

## Progress Tracking

_Session in progress - updates will be added as work progresses_

