# SEA Patch Lab

A hands-on lab for learning binary patching against JavaScript embedded inside a native Node.js SEA executable.

The demo app is intentionally annoying in 5 specific ways so you can patch byte-level strings in `demo-cli` and observe behavior changes.

## What This Lab Covers

- Building a minified JS payload and embedding it into a Mach-O executable with Node SEA
- Locating stable patch-target strings in a native binary
- Applying equal-length, in-place string patches
- Re-signing the executable after mutation
- Reverting and validating patch state

## Prerequisites

- macOS (tested on Apple Silicon)
- Node.js 22+
- `npm`
- `codesign` (provided by macOS)

## Quick Start

```bash
npm install
npm run build
./demo-cli
```

## Build Pipeline

`npm run build` executes `scripts/build.sh`:

1. Bundle/minify `src/index.tsx` -> `dist/bundle.cjs`
2. Generate SEA blob -> `dist/sea-prep.blob`
3. Copy current Node runtime -> `demo-cli`
4. Inject blob with `postject`
5. Re-sign binary with ad-hoc signature

## Patch Targets

The lab exposes 5 patch target strings. In the final SEA binary, each appears exactly **2 times**.

| # | Target string | Annoyance |
|---|---|---|
| 1 | `Model upgrade available for` | Upgrade nag banner |
| 2 | `j((U-P)/I*100)` | Wrong context math toggle |
| 3 | `UNRESTRICTED MODE` | Scary red mode label |
| 4 | `Shift+Tab also cycles mode (and this hint always clutters UI).` | Hint clutter |
| 5 | `Warning: Context critically low. Responses may degrade.` | Forced low-context warning |

Verify counts:

```bash
for p in \
  "Model upgrade available for" \
  "j((U-P)/I*100)" \
  "UNRESTRICTED MODE" \
  "Shift+Tab also cycles mode (and this hint always clutters UI)." \
  "Warning: Context critically low. Responses may degrade."; do
  echo "--- $p"
  rg -a -o --fixed-strings "$p" demo-cli | wc -l
 done
```

Expected output: `2` for each target.

## Patcher Usage

Use `scripts/patch.sh`:

```bash
scripts/patch.sh status
scripts/patch.sh apply
scripts/patch.sh revert
scripts/patch.sh auto
```

### Subcommands

- `status`: reports per-target original/patched counts and state (`unpatched`, `patched`, `mixed`)
- `apply`: applies all 5 patches, creates backup (`demo-cli.bak`) if missing, re-signs binary
- `revert`: restores all 5 original strings and re-signs
- `auto`: applies only when fully unpatched

Helper script:

```bash
scripts/patch-check.sh
```

This runs `status`, `auto`, then `status` again.

## Technique Notes

- Patches are byte-for-byte in-place string replacements.
- Every replacement keeps the same byte length.
- The patched binary must be re-signed after mutation.
- The patcher enforces deterministic preconditions per target (expected occurrence counts) to avoid corrupting mixed-state binaries.

## Constraints and Safety

When patching JS-in-binary payloads:

- Keep replacement lengths equal to original lengths
- Keep resulting JS syntactically valid
- Keep changes deterministic and reversible
- Re-sign after modifying Mach-O bytes
- Validate target counts before and after every operation

## Files

- `src/index.tsx`: demo Ink/React CLI with intentional patch toggles
- `scripts/build.sh`: SEA build pipeline
- `scripts/patch.sh`: apply/revert/status/auto patch manager
- `scripts/patch-check.sh`: idempotent auto-patch check helper
- `sea-config.json`: SEA blob configuration

## Troubleshooting

- `ERR_UNKNOWN_BUILTIN_MODULE` at runtime: binary was built with externalized deps; rebuild with current scripts.
- Binary crashes after patching: run `scripts/patch.sh status`; if mixed, restore from `demo-cli.bak` and rebuild.
- Signature errors on launch: re-run `scripts/patch.sh apply` or `scripts/patch.sh revert` (both re-sign).
