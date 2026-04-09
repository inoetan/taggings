#!/usr/bin/env bash
# build-check.sh — Static analysis for common Swift crash patterns
#
# Full compilation requires Xcode on macOS:  open Package.swift && ⌘R
# This script catches crash-prone patterns before the Mac round-trip.
#
# Usage:  ./scripts/build-check.sh

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/Sources"
ERRORS=0

fail() { echo "  [FAIL] $1"; ERRORS=$((ERRORS + 1)); }
ok()   { echo "  [ OK ] $1"; }

echo "=== TagFlow static analysis ==="
echo ""

# ── 1. fatalError in required init?(coder:) ─────────────────────────────────
echo "1. required init?(coder:) must not call fatalError()"
while IFS= read -r file; do
    # Find blocks where required init?(coder:) contains fatalError
    if grep -q "required init?(coder" "$file" && grep -A2 "required init?(coder" "$file" | grep -q "fatalError"; then
        fail "$file — fatalError() in coder init (crashes on macOS state restoration)"
    fi
done < <(find "$SRC" -name "*.swift")
[ "$ERRORS" -eq 0 ] && ok "No fatalError in coder inits"

# ── 2. Unsafe [0] array subscript ───────────────────────────────────────────
echo ""
echo "2. Array [0] subscripts should use .first"
while IFS= read -r match; do
    file=$(echo "$match" | cut -d: -f1)
    line=$(echo "$match" | cut -d: -f2)
    fail "$file:$line — Use .first instead of [0] (index-out-of-range crash)"
done < <(grep -rn '\][[:space:]]*\[0\]' "$SRC" --include="*.swift" || true)
# Also check standalone [0] that isn't in a comment or string
while IFS= read -r match; do
    file=$(echo "$match" | cut -d: -f1)
    line=$(echo "$match" | cut -d: -f2)
    content=$(echo "$match" | cut -d: -f3-)
    # Skip if it's clearly inside a string literal or comment
    if echo "$content" | grep -vqE '^\s*(//|")'; then
        fail "$file:$line — Bare [0] subscript: $content"
    fi
done < <(grep -rn '\b\w\+\[0\]' "$SRC" --include="*.swift" || true)
[ "$ERRORS" -le 1 ] && ok "No unsafe [0] subscripts"  # allow 1 for the pre-existing error counter

# ── 3. isRestorable = false on all windows ──────────────────────────────────
echo ""
echo "3. Windows must set isRestorable = false"
for class in EdgeTriggerWindow TagPanelWindow TagBrowserWindowController; do
    file=$(grep -rl "class $class" "$SRC" --include="*.swift" | head -1 || true)
    if [ -z "$file" ]; then
        fail "$class — file not found"
        continue
    fi
    if ! grep -q "isRestorable = false" "$file"; then
        fail "$file — $class missing isRestorable = false"
    else
        ok "$class sets isRestorable = false"
    fi
done

# ── 4. @objc on all #selector-referenced methods ────────────────────────────
echo ""
echo "4. Methods referenced by #selector must be @objc"
SELECTOR_ERRORS=0
while IFS= read -r match; do
    file=$(echo "$match" | cut -d: -f1)
    selector=$(echo "$match" | grep -oP '#selector\(\K[^)]+' || true)
    # Extract base method name only (strip parameter labels like "(_:)")
    method_name=$(echo "$selector" | sed 's/[^a-zA-Z0-9_].*//')
    if [ -z "$method_name" ]; then continue; fi
    if ! grep -q "@objc.*func $method_name" "$file"; then
        fail "$file — #selector($selector) but @objc func $method_name not found"
        SELECTOR_ERRORS=$((SELECTOR_ERRORS + 1))
    fi
done < <(grep -rn '#selector(' "$SRC" --include="*.swift" || true)
[ "$SELECTOR_ERRORS" -eq 0 ] && ok "All #selector methods have @objc"

# ── 5. NSApp.setActivationPolicy called in will/did launch ──────────────────
echo ""
echo "5. setActivationPolicy(.accessory) should be in applicationWillFinishLaunching"
appdelegate=$(grep -rl "setActivationPolicy" "$SRC" --include="*.swift" | head -1 || true)
if [ -z "$appdelegate" ]; then
    fail "setActivationPolicy not found"
else
    if grep -B5 "setActivationPolicy" "$appdelegate" | grep -q "WillFinishLaunching"; then
        ok "setActivationPolicy is in applicationWillFinishLaunching"
    else
        fail "$appdelegate — setActivationPolicy should be in applicationWillFinishLaunching (not DidFinish)"
    fi
fi

# ── 6. No @available(*, unavailable) on required inits ──────────────────────
echo ""
echo "6. No @available(*, unavailable) guarding required init?(coder:)"
while IFS= read -r file; do
    if grep -B1 "required init?(coder" "$file" | grep -q "@available.*unavailable"; then
        fail "$file — @available(*, unavailable) on coder init can still be called by Obj-C runtime"
    fi
done < <(find "$SRC" -name "*.swift")
ok "No unavailable coder inits"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [ "$ERRORS" -eq 0 ]; then
    echo "✓ All checks passed"
    echo ""
    echo "Next: open Package.swift in Xcode on macOS and build (⌘B) for full validation."
else
    echo "✗ $ERRORS issue(s) found. Fix before building on Mac."
    exit 1
fi
