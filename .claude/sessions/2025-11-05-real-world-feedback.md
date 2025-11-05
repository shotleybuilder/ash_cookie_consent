# 2025-11-05: Real-World Implementation Feedback

## Session Summary

User reported critical bugs discovered during real-world implementation in their EHS Enforcement app. These issues were always present but hidden until the consent library was integrated alongside AshAuthentication.

## Root Cause Analysis

### The Hidden Bug

**Before Cookie Consent Integration:**
1. The `:admin` live_session had: `on_mount: AshAuthentication.Phoenix.LiveSession`
2. The `live_view` macro had: `on_mount {AshCookieConsent.LiveView.Hook, :load_consent}`
3. **Critical Issue**: The `live_session` `on_mount` was REPLACING the one from `live_view` macro
4. This worked because AshAuthentication was setting `current_user` in socket assigns
5. A redundant check in mount would redirect if `current_user` was nil (but never triggered)

**After Cookie Consent Integration:**
1. Added `AshCookieConsent.Plug` to `:browser` pipeline
2. The plug calls `put_session/3` to cache consent data (line 100 of plug.ex)
3. This `put_session` call interfered with Phoenix session handling
4. Fixed plug order (after `:fetch_live_flash`) but session issue remained
5. Updated `:admin` live_session to run BOTH hooks:
   ```elixir
   on_mount: [
     AshAuthentication.Phoenix.LiveSession,
     {AshCookieConsent.LiveView.Hook, :load_consent}
   ]
   ```
6. **Exposed the real bug**: `AshAuthentication.Phoenix.LiveSession` hook doesn't work in `live_session` context with session map - it expects a conn struct and calls `Plug.Conn.get_session/1`

### Error Logs

```
[error] ** (FunctionClauseError) no function clause matching in Plug.Conn.get_session/1
    (plug 1.18.1) lib/plug/conn.ex:1781: Plug.Conn.get_session(%{"_csrf_token" => "...", "user" => "user?id=..."})
    (ash_authentication 4.12.0) lib/ash_authentication/plug/helpers.ex:166: anonymous fn/4 in AshAuthentication.Plug.Helpers.retrieve_from_session/3
```

The AshAuthentication hook calls `Plug.Helpers.retrieve_from_session/3` which tries to use `Plug.Conn.get_session/1`, but in LiveView `on_mount` context, it receives the session as a map, not a conn struct.

### Key Finding

**Phoenix LiveView Behavior**: `live_session` `on_mount` **REPLACES** (not appends to) any `on_mount` from the `live_view` macro. This is a common source of silent failures.

## Issues Fixed

### Issue #1: Session Caching Interference

**Problem**: The plug unconditionally calls `put_session` (line 100) to cache consent, which can interfere with other session data when called at the wrong point in the pipeline.

**Solution**: Added `skip_session_cache` option to disable session caching entirely:

```elixir
# In plug.ex init/1
%{
  # ...existing options...
  skip_session_cache: Keyword.get(opts, :skip_session_cache, false)
}

# In plug.ex call/2
conn =
  if consent && !config.skip_session_cache && !get_session_consent(conn, storage_opts) do
    put_session(conn, config.session_key, consent)
  else
    conn
  end
```

**Files Modified**:
- `lib/ash_cookie_consent/plug.ex`: Added option to init/1 and conditional logic in call/2
- Documentation updated with new option

**Tests Added**:
- Test that `skip_session_cache` option is accepted
- Test that it defaults to false
- Test that session is NOT written when option is true
- Test that session is still READ when option is true (only prevents writing)

### Issue #2: Hook Ordering Documentation

**Problem**: Documentation didn't clearly explain that `live_session` `on_mount` REPLACES the one from `live_view` macro.

**Solution**: Added comprehensive warnings and examples to multiple documentation files:

**Files Modified**:
1. `guides/getting-started.md`: Added "⚠️ Important: Hook Ordering with Multiple on_mount Callbacks" section
2. `guides/troubleshooting.md`: Added "LiveView Hooks Not Running with live_session" section with debugging steps
3. `usage-rules.md`: Added "⚠️ CRITICAL: live_session Replaces on_mount from live_view Macro" section

**Documentation Improvements**:
- Clear ❌ WRONG / ✅ CORRECT examples
- Explanation of Phoenix behavior (replacement, not combination)
- Debugging techniques (IO.inspect socket.assigns)
- Rule of thumb for when to list all hooks explicitly

### Issue #3: Session Interference Troubleshooting

**Problem**: No troubleshooting guidance for session-related errors with other libraries.

**Solution**: Added comprehensive "Session Interference with Other Libraries" section to troubleshooting guide.

**Coverage**:
- Root cause explanation
- Common symptoms (`FunctionClauseError`, authentication failures)
- Three solutions:
  1. Disable session caching (recommended)
  2. Verify plug order
  3. Use cookie-only mode
- Explanation of WHY it happens
- Best practices for complex session handling

## Implementation Changes

### Code Changes

**lib/ash_cookie_consent/plug.ex**:
1. Added `:skip_session_cache` to configuration options
2. Added conditional check before `put_session` call
3. Updated moduledoc with new option

### Test Changes

**test/ash_cookie_consent/plug_test.exs**:
1. Added test for `skip_session_cache` option acceptance
2. Added test for default false value
3. Added test that session is NOT written when true
4. Added test that session is still read when true

**Test Results**: All 176 tests passing (4 new tests added)

### Documentation Changes

**guides/getting-started.md**:
- Added 30+ line warning section about hook ordering
- Included wrong/correct examples
- Explained Phoenix replacement behavior

**guides/troubleshooting.md**:
- Added "LiveView Hooks Not Running with live_session" section
- Added "Session Interference with Other Libraries" section (80+ lines)
- Three solutions with code examples
- Root cause explanations

**usage-rules.md**:
- Added "⚠️ CRITICAL" section about live_session replacement
- Wrong/correct examples with explanations
- Rule of thumb for hook ordering
- Debugging technique

## User's Fix (In Their App)

1. **Router fix**: Added both hooks to the `:admin` live_session
2. **Template fix**: Removed dependency on `@current_user` (AshAuthentication bug, not ash_cookie_consent)
3. **Security**: The `:admin_required` pipeline already verified authentication

Trade-off: Can't display username in admin dashboard header (shows "ADMIN" badge instead).

## Key Takeaways

### For Library Users

1. **Always list ALL hooks in `live_session`** if using multiple hooks
2. **Use `skip_session_cache: true`** when integrating with authentication libraries
3. **Phoenix's `live_session` replaces, not appends** - this is critical to understand
4. Session caching is optional and can be disabled without performance impact

### For Library Maintenance

1. **Session interference is real** - `skip_session_cache` option is essential for compatibility
2. **Documentation needs clear warnings** about Phoenix hook replacement behavior
3. **Test edge cases** with multiple hooks and session scenarios
4. The three-tier storage was the right design - cookie-only mode works great

### For Future Development

Consider making `skip_session_cache: true` the DEFAULT in v0.2.0:
- Simpler mental model (cookie-only by default)
- Better compatibility with other libraries
- Minimal performance impact
- Opt-in session caching for those who need it

## Related Documentation

- Getting Started: Step 3 (LiveView configuration)
- Troubleshooting: Session Issues, LiveView Issues
- Usage Rules: LiveView Integration
- Plug moduledoc: Configuration options

## Status

✅ All issues fixed
✅ Tests added and passing (176 tests)
✅ Documentation comprehensive
✅ User's app is working

Ready for inclusion in next release (v0.1.1 patch or v0.2.0).
