# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Quick Integration Checklist in usage-rules.md for rapid setup guidance

### Changed
- **BREAKING DOCUMENTATION**: Removed global hook pattern from getting-started guide
- Updated all integration examples to use router-level `live_session` only
- Removed general Phoenix/LiveView teaching from documentation (focused on consent integration)
- Comprehensive extending guide improvements with real-world database sync patterns

### Fixed
- Documentation now clearly warns against global hook anti-pattern
- Added guidance for when to skip LiveView hook on admin/authenticated routes
- Added session interference prevention with `skip_session_cache` option
- Extending guide now includes user ID extraction, "newer wins" logic, and proper user relationships

## [0.1.0] - 2025-11-04

Initial release of AshCookieConsent - GDPR-compliant cookie consent management for Ash Framework applications.

### Added

#### Core Features
- **ConsentSettings Ash Resource** with GDPR-compliant attributes:
  - `terms` - Policy version identifier
  - `groups` - Array of consented cookie categories
  - `consented_at` - Consent timestamp
  - `expires_at` - Consent expiration (365 days default)
- **Custom Ash Actions**:
  - `grant_consent` - Record user consent with automatic timestamps
  - `revoke_consent` - Revoke all consent
  - `active_consents` - Query non-expired consents
- **Validations**: Terms and groups validation with clear error messages

#### Phoenix Components
- **ConsentModal** component with:
  - AlpineJS-powered interactive modal
  - Tailwind CSS styling (customizable)
  - Granular cookie group selection
  - Accept All / Reject All shortcuts
  - Keyboard navigation (Escape to close)
  - Click-outside dismissal
  - Accessibility support (ARIA labels, focus management)
- **ConsentScript** component for conditional script loading:
  - Only load scripts when user has consented to category
  - Support for async/defer attributes
  - Custom attributes pass-through
  - Examples for Google Analytics, Tag Manager, Facebook Pixel

#### Integration Layer
- **AshCookieConsent.Plug** for traditional Phoenix apps:
  - Loads consent from three-tier storage
  - Sets assigns (`:consent`, `:show_consent_modal`, `:cookie_groups`)
  - Configurable cookie and session keys
  - Optional database sync for authenticated users
- **AshCookieConsent.LiveView.Hook** for LiveView apps:
  - `on_mount` callback with `:load_consent` and `:require_consent` phases
  - Socket assign management
  - Event handlers for consent updates
  - Helper functions (`show_modal/1`, `hide_modal/1`)
- **Three-Tier Storage System** (`AshCookieConsent.Storage`):
  - **Read Priority**: assigns → session → cookie → database
  - **Write Strategy**: All tiers updated simultaneously
  - Automatic sync on login for authenticated users
  - Conflict resolution (newest consent wins)
- **Cookie Management** (`AshCookieConsent.Cookie`):
  - Signed cookies using Phoenix.Token
  - JSON encoding with automatic timestamp handling
  - Configurable cookie options (max_age, domain, path, etc.)
  - HttpOnly, Secure, SameSite defaults

#### Helper Functions
- `consent_given?/2` - Check if user consented to cookie group
- `get_consent/1` - Retrieve current consent data
- `has_consent?/1` - Check if any consent exists
- Cookie group configuration via Application config

#### Documentation
- **README.md** with:
  - Badges (Hex.pm, documentation, license)
  - "Why AshCookieConsent?" comparison section
  - Quick 4-line integration example
  - Feature comparison table vs alternatives
- **6 Comprehensive Guides** (1,820+ lines total):
  - `getting-started.md` - Installation and basic setup
  - `migration-guide.md` - Migration from other libraries and adding to existing apps
  - `examples.md` - Real-world integration patterns
  - `troubleshooting.md` - Common issues and solutions
  - `extending.md` - Custom storage, UI customization
  - `usage-rules.md` - AI assistant integration guidance
- **Code Documentation**: All modules and public functions documented with examples
- **Moduledoc and @doc** coverage for all public APIs

#### Testing
- **163 Comprehensive Tests** including:
  - Unit tests for Ash resource (ConsentSettings)
  - Component rendering tests
  - Cookie encoding/decoding tests
  - Plug integration tests
  - LiveView Hook tests
  - Three-tier storage tests
  - Helper function tests
  - Edge case coverage (expiration, malformed data, etc.)
- All tests passing with 0 failures

#### Code Quality
- **Credo**: Passing strict mode (intentional TODOs documented)
- **Dialyzer**: Zero type warnings (0 errors)
- **Formatted**: Using `mix format`
- **Zero compile warnings**
- Documented extension points for database sync

### Design Decisions

#### Database Sync - Intentionally Optional
The library provides **extension points** for database synchronization but doesn't enforce a specific user relationship pattern. This allows:
- Cookie/session storage works for all users (authenticated or not)
- Apps can add user relationships as needed
- Flexibility in user model architecture
- Simple integration without database requirements

**Extension Points**:
- `lib/ash_cookie_consent/storage.ex`: Stubbed `load_user_consent/2` and `save_user_consent/3`
- `lib/ash_cookie_consent/plug.ex`: Stubbed database sync functions
- `lib/ash_cookie_consent/live_view/hook.ex`: Stubbed `save_consent_to_db/3`

See `guides/migration-guide.md` section "Adding User Relationships" for complete implementation guide.

#### Three-Tier Storage Benefits
- **Assigns**: Fastest access, request-scoped
- **Session**: Server-side cache, no database roundtrip
- **Cookie**: Client-side persistence, works offline
- **Database**: Audit trail, cross-device sync (when implemented)

### Dependencies

#### Required
- `ash ~> 3.0` - Core Ash Framework
- `phoenix ~> 1.7` - Phoenix Framework
- `phoenix_live_view ~> 1.0` - LiveView support
- `jason ~> 1.4` - JSON encoding

#### Optional
- `ash_postgres ~> 2.0` - PostgreSQL data layer (or use `ash_sqlite`)

#### Development
- `ex_doc ~> 0.34` - Documentation generation
- `credo ~> 1.7` - Static analysis
- `dialyxir ~> 1.4` - Type checking

### Configuration

Default cookie groups:
```elixir
config :ash_cookie_consent, :cookie_groups, [
  %{
    key: "essential",
    label: "Essential Cookies",
    description: "Required for the website to function",
    required: true
  },
  %{
    key: "analytics",
    label: "Analytics Cookies",
    description: "Help us understand how visitors use our website",
    required: false
  },
  %{
    key: "marketing",
    label: "Marketing Cookies",
    description: "Used to deliver personalized advertisements",
    required: false
  }
]
```

### Migration Path

For existing applications:
1. Add dependency to `mix.exs`
2. Create `ConsentSettings` resource with data layer
3. Add Plug to router (after `:fetch_session`)
4. Add LiveView Hook (optional, for LiveView apps)
5. Add modal component to layout
6. Configure cookie groups

See `guides/migration-guide.md` for detailed instructions.

### Breaking Changes

None (initial release)

### Known Limitations

- **Database sync requires user relationship**: Apps must implement user relationship and database queries (documented extension points provided)
- **AlpineJS required**: Modal interactivity requires AlpineJS v3.x
- **Tailwind recommended**: Components styled with Tailwind (customizable via Alpine x-bind)
- **Phoenix 1.7+**: Requires Phoenix 1.7 for Phoenix.Component

### Roadmap

See GitHub Issues for planned enhancements:
- Built-in database sync helpers (v0.2.0)
- Multi-language support
- Consent banner variants (banner, modal, corner popup)
- Export/import consent data
- Enhanced analytics integration

### Credits

Built with [Ash Framework](https://ash-hq.org/) by Zach Daniel and the Ash core team.

Inspired by [phx_cookie_consent](https://github.com/pzingg/phx_cookie_consent) (Ecto-based) but rewritten for Ash Framework.

### License

MIT License - See LICENSE file for details

---

[Unreleased]: https://github.com/shotleybuilder/ash_cookie_consent/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/shotleybuilder/ash_cookie_consent/releases/tag/v0.1.0
