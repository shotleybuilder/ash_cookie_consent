# Troubleshooting

This guide covers common issues and their solutions when using AshCookieConsent.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Modal Not Appearing](#modal-not-appearing)
- [Consent Not Persisting](#consent-not-persisting)
- [Scripts Not Loading](#scripts-not-loading)
- [LiveView Issues](#liveview-issues)
- [Styling Issues](#styling-issues)
- [Performance Issues](#performance-issues)

## Installation Issues

### AlpineJS Not Working

**Problem**: The consent modal doesn't respond to clicks or doesn't show/hide properly.

**Solution**: Ensure AlpineJS is properly installed and initialized:

```javascript
// assets/js/app.js
import Alpine from 'alpinejs'
window.Alpine = Alpine
Alpine.start()
```

And installed via npm:

```bash
cd assets && npm install alpinejs --save
```

**Verify**: Check browser console for errors. You should see no AlpineJS-related errors.

### Tailwind CSS Styles Not Applied

**Problem**: The consent modal has no styling or looks broken.

**Solution**: Add the library path to your Tailwind config:

```javascript
// assets/tailwind.config.js
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex',
    '../deps/ash_cookie_consent/lib/**/*.ex'  // ← Add this
  ],
  // ...
}
```

Then rebuild your assets:

```bash
cd assets && npm run build
# or if using mix phx.server, just restart it
```

## Modal Not Appearing

### Modal Never Shows

**Problem**: The consent modal doesn't appear even for first-time visitors.

**Checklist**:

1. **Verify Plug is added**:
```elixir
# lib/my_app_web/router.ex
pipeline :browser do
  # ... other plugs
  plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
end
```

2. **Verify modal is in layout**:
```heex
<!-- lib/my_app_web/components/layouts/root.html.heex -->
<AshCookieConsent.Components.ConsentModal.consent_modal
  current_consent={assigns[:consent]}
  cookie_groups={AshCookieConsent.cookie_groups()}
/>
```

3. **Check assigns are set**:
```elixir
# In a controller or LiveView, inspect:
IO.inspect(conn.assigns.show_consent_modal)  # Should be true for first visit
IO.inspect(conn.assigns.consent)              # Should be nil for first visit
```

4. **Check browser console**: Look for JavaScript errors that might prevent AlpineJS from working.

### Modal Shows But Won't Close

**Problem**: Clicking "Accept" or "Customize" doesn't close the modal.

**Solution**: Ensure the form action is correct and the ConsentController exists:

```elixir
# lib/my_app_web/router.ex
scope "/", MyAppWeb do
  pipe_through :browser
  post "/consent", ConsentController, :update  # ← Add this
end
```

Or for LiveView, ensure the event handler is present:

```elixir
@impl true
def handle_event("update_consent", params, socket) do
  AshCookieConsent.LiveView.Hook.handle_consent_update(
    socket,
    params,
    resource: MyApp.Consent.ConsentSettings
  )
end
```

## Consent Not Persisting

### Consent Lost After Page Reload

**Problem**: Users have to accept cookies on every page visit.

**Possible Causes**:

1. **Cookie not being set**: Check browser DevTools → Application → Cookies
   - Look for `_consent` cookie
   - Should have a 1-year expiration

2. **Session not configured**: Ensure session is fetched in your router:
```elixir
pipeline :browser do
  plug :fetch_session  # ← Must come before AshCookieConsent.Plug
  plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
end
```

3. **Cookie being deleted**: Check if you have any code that clears cookies/session

**Debug**:
```elixir
# In a controller
def debug(conn, _params) do
  IO.inspect(conn.req_cookies["_consent"], label: "Cookie")
  IO.inspect(Plug.Conn.get_session(conn, "consent"), label: "Session")
  IO.inspect(conn.assigns.consent, label: "Assigns")
  text(conn, "Check logs")
end
```

### Consent Not Syncing Across Devices

**Problem**: Authenticated users don't see same consent on different devices.

**Explanation**: Database synchronization is currently stubbed (Phase 3 limitation).

**Workaround**: Consent is stored in browser cookies only. To implement cross-device sync:
- See [Extending Guide](extending.html) for adding user relationships
- Implement the stubbed database functions in Storage module

## Scripts Not Loading

### Analytics Scripts Not Loading Despite Consent

**Problem**: Google Analytics or other scripts don't load even after accepting cookies.

**Checklist**:

1. **Verify ConsentScript component usage**:
```heex
<AshCookieConsent.Components.ConsentScript.consent_script
  consent={@consent}           # ← Must pass consent
  group="analytics"            # ← Group must match consent
  src="https://..."
/>
```

2. **Check consent data**:
```elixir
# In template, temporarily add:
<%= inspect(@consent) %>
# Should show: %{"groups" => ["essential", "analytics"], ...}
```

3. **Verify group names match**:
```elixir
# Cookie groups config must match ConsentScript group parameter
config :ash_cookie_consent,
  cookie_groups: [
    %{id: "analytics", ...}  # ← ID must match
  ]
```

4. **Check for CSP (Content Security Policy)**: Your CSP might block external scripts.

### Scripts Load Before Consent

**Problem**: Analytics scripts load immediately instead of waiting for consent.

**Solution**: Ensure you're using `ConsentScript` component, NOT regular `<script>` tags:

```heex
<!-- ❌ Wrong - loads immediately -->
<script src="https://www.googletagmanager.com/gtag/js?id=GA_ID"></script>

<!-- ✅ Correct - only loads with consent -->
<.consent_script
  consent={@consent}
  group="analytics"
  src="https://www.googletagmanager.com/gtag/js?id=GA_ID"
/>
```

## LiveView Issues

### Hook Not Loading Consent

**Problem**: `@consent` is nil in LiveView even after accepting cookies.

**Solutions**:

1. **Verify Hook is mounted**:
```elixir
# lib/my_app_web.ex
def live_view do
  quote do
    use Phoenix.LiveView
    on_mount {AshCookieConsent.LiveView.Hook, :load_consent}  # ← Add this
  end
end
```

2. **Or add to specific LiveView**:
```elixir
defmodule MyAppWeb.MyLive do
  use MyAppWeb, :live_view
  on_mount {AshCookieConsent.LiveView.Hook, :load_consent}
end
```

3. **Or add to live_session in router**:
```elixir
live_session :default,
  on_mount: [{AshCookieConsent.LiveView.Hook, :load_consent}] do
  live "/", HomeLive
end
```

### Cookie Not Updating After LiveView Event

**Problem**: Consent is saved but cookie doesn't update in browser.

**Solution**: Add the cookie update handler to your root layout:

```heex
<!-- lib/my_app_web/components/layouts/root.html.heex -->
<script>
  window.addEventListener("phx:update-consent-cookie", (e) => {
    const consent = e.detail.consent;
    const expires = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toUTCString();
    document.cookie = `_consent=${encodeURIComponent(consent)}; expires=${expires}; path=/; SameSite=Lax`;
  });
</script>
```

## Styling Issues

### Modal Overlaps Content

**Problem**: The modal appears behind other content or doesn't cover the full screen.

**Solution**: The modal uses `z-50` by default. If you have higher z-index elements:

```heex
<.consent_modal
  current_consent={@consent}
  cookie_groups={@cookie_groups}
  modal_class="z-[9999]"  # ← Increase z-index
/>
```

### Custom Styling Not Applied

**Problem**: Adding custom classes doesn't change modal appearance.

**Solution**: Ensure your Tailwind config includes the library:

```javascript
// assets/tailwind.config.js
module.exports = {
  content: [
    '../deps/ash_cookie_consent/lib/**/*.ex',  // ← Must be included
  ],
  // ...
}
```

## Performance Issues

### Slow Page Load

**Problem**: Pages load slowly after adding AshCookieConsent.

**Diagnosis**:

1. **Check if database queries are running**: If you've implemented database sync, ensure it's efficient:
```elixir
# Add telemetry to see query times
```

2. **Session overhead**: Session is cached for performance, but check session store config:
```elixir
# config/config.exs
config :my_app, MyAppWeb.Endpoint,
  session_store: :cookie,
  session_options: [
    signing_salt: "...",
    max_age: 86400  # 1 day
  ]
```

**Solutions**:
- Use cookie/session storage (default behavior)
- Defer database sync (it's currently stubbed anyway)
- Enable HTTP/2 for faster script loading
- Use `async` or `defer` attributes on ConsentScript components

### Memory Usage High

**Problem**: Elixir memory usage increases after adding consent management.

**Diagnosis**: Check if consent data is being stored in process state unnecessarily.

**Solution**: Use the three-tier storage correctly:
- Assigns: Request-scoped (cleaned up after request)
- Session: Moderate size, cleaned up after expiration
- Cookie: Small, only transmitted on requests
- Database: Not currently used

## Getting Help

If you're still experiencing issues:

1. **Check the Examples**: See [Examples Guide](examples.html) for working patterns
2. **Review Documentation**: Check module documentation in ExDoc
3. **Enable Debug Logging**:
```elixir
# In a controller
require Logger
Logger.debug("Consent: #{inspect(conn.assigns.consent)}")
Logger.debug("Show modal: #{inspect(conn.assigns.show_consent_modal)}")
```

4. **Create an Issue**: Report bugs at [GitHub Issues](https://github.com/shotleybuilder/ash_cookie_consent/issues)

## Common Error Messages

### "key :resource not found"

**Error**: `** (KeyError) key :resource not found in: []`

**Fix**: You forgot to pass the `:resource` option to the Plug:
```elixir
plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
```

### "function __ash_resource__?/1 is undefined"

**Error**: The module you passed as `:resource` is not an Ash resource.

**Fix**: Ensure your ConsentSettings is an Ash.Resource:
```elixir
defmodule MyApp.Consent.ConsentSettings do
  use Ash.Resource, domain: MyApp.Consent  # ← Must use Ash.Resource
end
```

### "ArgumentError: session not fetched"

**Error**: `** (ArgumentError) session not fetched`

**Fix**: Add `:fetch_session` before the consent Plug:
```elixir
pipeline :browser do
  plug :fetch_session        # ← Must come first
  plug AshCookieConsent.Plug, resource: MyApp.Consent.ConsentSettings
end
```
