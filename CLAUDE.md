# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`ash_cookie_consent` is a GDPR-compliant cookie consent management library for Ash Framework applications. It provides:

- An Ash.Resource (`ConsentSettings`) for tracking consent with full audit trail
- Phoenix integration via Plugs and LiveView hooks (planned)
- Three-tier storage: browser cookies, Phoenix session, and database persistence
- Phoenix Components for consent UI (planned)

**Status**: Phase 1 (Core Architecture) completed. Phases 2-7 are in progress.

## Development Commands

### Running Tests
```bash
mix test                    # Run all tests
mix test path/to/test.exs  # Run a single test file
```

### Code Quality
```bash
mix format                 # Format code
mix credo                  # Run static analysis
mix dialyzer              # Run type checking (first run is slow)
```

### Documentation
```bash
mix docs                   # Generate documentation
open doc/index.html       # View generated docs
```

### Compilation
```bash
mix compile               # Compile the project
mix clean                 # Clean build artifacts
```

### Publishing
```bash
mix hex.build            # Build the Hex package
mix hex.publish          # Publish to Hex.pm (requires authentication)
```

## Architecture

### Core Resource: `ConsentSettings`

The `AshCookieConsent.ConsentSettings` resource is the heart of the library. It tracks:

- **terms**: Policy version identifier (e.g., "v1.0", "2025-01-01")
- **groups**: Array of consented cookie categories (e.g., ["essential", "analytics"])
- **consented_at**: Timestamp when consent was given
- **expires_at**: When consent expires (automatically set to 365 days from consent)

**Custom Actions**:
- `:grant_consent` - Creates consent with automatic timestamp management
- `:revoke_consent` - Updates consent to remove specific groups
- `:active_consents` - Filters for non-expired consent records

**Design Note**: The `user` relationship is intentionally commented out in the resource. This allows consuming applications to define their own user relationships without coupling to a specific user module.

### Three-Tier Storage Pattern (Planned)

The library implements a layered storage approach:

1. **Browser Cookie**: Fast, anonymous-user friendly, works immediately
2. **Phoenix Session**: Request-scoped cache, no database roundtrip per request
3. **Database (Ash)**: Audit trail, cross-device sync for authenticated users

**Sync Flow**:
- Anonymous users: consent stored only in browser cookie
- User logs in: cookie consent synced to database
- User on new device: database consent loaded to cookie
- User clears cookies: consent restored from database on re-login

This provides GDPR compliance (database audit trail) while maintaining fast UX (cookie access).

### Ash Framework Integration

- **Domain**: `AshCookieConsent.Domain` contains the `ConsentSettings` resource
- **Configuration**: `config/config.exs` registers the domain with `ash_domains`
- **Data Layer**: No default data layer configured - consumers choose their own (AshPostgres, AshSqlite, etc.)

The library is data-layer agnostic. Consuming applications add their preferred data layer via resource extensions.

## Implementation Phases

Refer to `.claude/sessions/2025-11-01-ash-cookie-consent-implementation.md` for detailed phase breakdown:

- **Phase 1** ✅: Project setup, Ash resource, domain configuration
- **Phase 2** (Next): Phoenix Components (consent modal, script helpers)
- **Phase 3**: Integration layer (Plug, LiveView hooks, sync logic)
- **Phase 4**: Testing
- **Phase 5**: Documentation
- **Phase 6**: Hex.pm publishing
- **Phase 7**: Integration into EHS Enforcement app

## Code Conventions

### Ash Resource Patterns

When working with the `ConsentSettings` resource:

- Use custom actions (`:grant_consent`, `:revoke_consent`) instead of generic `:create`/`:update` for business operations
- Timestamps (`consented_at`, `expires_at`) are managed automatically by actions
- Validations ensure `terms` is a non-empty string and `groups` is an array of strings

### Module Organization

```
lib/ash_cookie_consent/
├── consent_settings.ex       # Core Ash.Resource
├── domain.ex                 # Ash.Domain definition
├── application.ex            # OTP application (supervision tree)
└── (planned)
    ├── plug.ex              # Phoenix plug integration
    ├── live_view/
    │   └── hook.ex          # LiveView on_mount hooks
    └── components/
        ├── consent_modal.ex  # Phoenix Component for UI
        └── consent_script.ex # Conditional script loading
```

### Testing Strategy

- Use `doctest` for documentation examples
- Create test support modules in `test/support/` (already configured via `elixirc_paths`)
- Integration tests should cover the three-tier storage sync logic
- Test both authenticated and anonymous user flows

## Configuration

The library uses minimal configuration in `config/config.exs`:

```elixir
config :ash_cookie_consent, ash_domains: [AshCookieConsent.Domain]
```

Future configuration options (planned):
- Cookie groups customization
- Consent expiration duration
- Modal UI customization

## Dependencies

**Core**:
- `ash` ~> 3.0 - Framework for building composable domain models
- `phoenix` ~> 1.7 - Web framework
- `phoenix_live_view` ~> 1.0 - Real-time UI components
- `jason` ~> 1.4 - JSON encoding

**Optional**:
- `ash_postgres` ~> 2.0 - PostgreSQL data layer (consumers can choose alternatives)

**Dev/Test**:
- `ex_doc` - Documentation generation
- `credo` - Static code analysis
- `dialyxir` - Static type checking

## GDPR Compliance Notes

The `ConsentSettings` resource provides the attributes required by GDPR Article 7(1) to demonstrate consent:

- Timestamp of consent (`consented_at`)
- Policy version consented to (`terms`)
- Specific categories consented (`groups`)
- Expiration tracking (`expires_at`)
- Full audit trail via Ash timestamps (`inserted_at`, `updated_at`)

When implementing features, ensure that consent updates maintain the audit trail and don't overwrite historical data.

## Library Design Philosophy

- **Ash-Native**: Built on Ash.Resource with full policy support
- **Data Layer Agnostic**: Works with any Ash data layer
- **Lightweight**: Minimal JavaScript (AlpineJS), no heavy frameworks
- **Extensible**: Configurable categories, customizable UI, pluggable storage
- **GDPR-First**: Audit trail and consent tracking are core requirements

## References

- Inspired by [phx_cookie_consent](https://github.com/pzingg/phx_cookie_consent)
- GDPR Article 7: https://gdpr-info.eu/art-7-gdpr/
- Ash Framework: https://ash-hq.org/
