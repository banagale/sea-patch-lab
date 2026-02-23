# Patch Target Verification

This document records the 5 search/replace targets used by `scripts/patch.sh`.

## Verified Targets

| # | Original | Patched |
|---|---|---|
| 1 | `Model upgrade available for` | `Model upgrade available foR` |
| 2 | `j((U-P)/I*100)` | `j((U+P)/I*100)` |
| 3 | `UNRESTRICTED MODE` | `UNRESTRICTED mODE` |
| 4 | `Shift+Tab also cycles mode (and this hint always clutters UI).` | `Shift+Tab also cycles mode (and this hint always clutters UI)!` |
| 5 | `Warning: Context critically low. Responses may degrade.` | `Warning: Context critically low. Responses may degrade!` |

## Expected Counts

Before patching (`scripts/patch.sh status`):

- each original: `2`
- each patched: `0`

After `scripts/patch.sh apply`:

- each original: `0`
- each patched: `2`

After `scripts/patch.sh revert`:

- each original: `2`
- each patched: `0`

## Quick Check

```bash
scripts/patch.sh status
```

The script prints per-target counts and `state: unpatched|patched|mixed`.
