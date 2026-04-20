---
name: hermes-tui-local-patches
description: Apply local patches to the Hermes TUI (TypeScript/React/Ink). Use when the user wants behavior changes in their `hermes` CLI — keybindings, mouse/clipboard behavior, theme tweaks, status bar additions — without waiting for upstream. Covers project layout, build pipeline gotchas, the selection/clipboard API, and a copy-on-select reference patch.
version: 1.0.0
metadata:
  hermes:
    tags: [hermes, tui, ink, react, typescript, patch, clipboard, selection]
    related_skills: [hermes-agent]
---

# Hermes TUI Local Patches

## When to use

User asks to change Hermes CLI/TUI behavior locally:
- "Make the TUI copy on mouse select"
- "Bind X to Y in the chat UI"
- "Change the status bar / theme / scroll behavior"
- Anything touching the rendered terminal UI (not the agent loop, not tools).

For changes to the agent loop, tools, prompts, or gateway → use the **hermes-agent** skill instead. This skill is *only* for the Ink-based TUI rendering layer.

## Layout

```
~/.hermes/hermes-agent/ui-tui/
├── package.json                   # scripts: dev, build, type-check, lint, test
├── tsconfig.build.json            # USE THIS — `tsconfig.json` triggers noisy lint
├── src/
│   ├── entry.tsx                  # bin entry
│   ├── app/
│   │   ├── useMainApp.ts          # top-level app hook — wire selection/clipboard side-effects here
│   │   ├── useInputHandlers.ts    # keypress dispatch
│   │   ├── useComposerState.ts    # input box state
│   │   └── ...
│   ├── components/                # TUI components
│   └── config/env.ts              # env var feature flags (e.g. HERMES_TUI_DISABLE_MOUSE)
├── packages/hermes-ink/           # local fork of Ink
│   └── src/ink/
│       ├── selection.ts           # selection ops + OSC 52 clipboard via setClipboard()
│       ├── ink.tsx                # Ink class — copySelection, copySelectionNoClear, hasTextSelection
│       └── hooks/use-selection.ts # public useSelection() hook contract
└── dist/                          # built output (consumed by ~/.local/bin/hermes)
```

The installed binary `~/.local/bin/hermes` is a symlink chain ending at the Python venv's `hermes` script, which spawns the built TUI from `dist/`. **You must run `npm run build` for changes to show up.**

## Build pipeline

**Always use the project script — do NOT run raw `tsc`:**

```bash
cd ~/.hermes/hermes-agent/ui-tui
npm run build
```

This does: `tsc -p tsconfig.build.json && chmod +x dist/entry.js`, plus an esbuild bundle of `packages/hermes-ink`.

### Pitfall: pre-existing lint noise

Running raw `tsc` (or hooks that auto-lint with the default `tsconfig.json`) prints ~50 errors about `--jsx not set`, `Property 'at' does not exist`, `Intl.Segmenter`, `replaceAll`, `at()`, etc. **These are all pre-existing.** They come from `tsconfig.json` (typecheck-only) using older lib targets than `tsconfig.build.json`. Ignore them. Only treat errors as real if `npm run build` itself fails (last lines will show the actual error from `tsconfig.build.json`).

When the `patch` tool's auto-lint shows these errors, scan for any errors that mention files you actually edited — those are real. Everything else is noise.

## Selection / Clipboard API

The TUI ships an alt-screen text selection system with OSC 52 clipboard write. Public surface from `@hermes/ink`:

```ts
import { useSelection, useHasSelection } from '@hermes/ink'

const sel = useSelection()
sel.copySelection()         // copy + clear highlight, returns text
sel.copySelectionNoClear()  // copy via OSC 52, keep highlight
sel.clearSelection()
sel.hasSelection()
sel.getState()              // returns SelectionState | null with isDragging/anchor/focus
sel.subscribe(cb)           // mutations: drag start/update/finish/clear; returns unsub
sel.shiftAnchor / shiftSelection / moveFocus / captureScrolledRows / setSelectionBgColor
```

**Type pitfall:** `getState()` is loosely typed as `{}` in `packages/hermes-ink/index.d.ts`. To read fields without TS errors, define a local interface and cast:
```ts
interface SelectionSnap { anchor?: { row: number }; focus?: { row: number }; isDragging?: boolean }
const s = sel.getState() as null | SelectionSnap
```
`useMainApp.ts` already declares `SelectionSnap` — reuse it.

OSC 52 plumbing: `copySelectionNoClear` calls `setClipboard(text)` then writes the returned escape sequence to stdout. Inside tmux it auto-wraps in DCS passthrough — silently no-ops without `allow-passthrough on` (no regression).

## Why mouse features bypass terminal-level behavior

The TUI enables mouse tracking (DECSET 1000/1002/1006). The terminal hands ALL mouse events to the TUI, so:
- Ghostty's `copy-on-select = clipboard` never fires
- iTerm's right-click menu / drag-select goes to the TUI
- ⌥-drag (macOS) bypasses TUI mouse capture; Shift sometimes works (xterm convention)

Workarounds:
1. `export HERMES_TUI_DISABLE_MOUSE=1` — fully disables TUI mouse; terminal handles everything but loses click-to-focus, link-click, drag-to-scroll, multi-click word select.
2. Patch the TUI to mirror the terminal behavior using the selection API (preferred — see below).

## Reference patch: copy-on-select

Wire the existing OSC 52 `copySelectionNoClear` to fire on drag-release inside `useMainApp.ts`, right after the `setSelectionBgColor` effect:

```ts
// Copy-on-select: drag-release with non-empty selection → OSC 52 → system clipboard.
// Disable with HERMES_TUI_NO_COPY_ON_SELECT=1.
useEffect(() => {
  if (/^(?:1|true|yes|on)$/i.test((process.env.HERMES_TUI_NO_COPY_ON_SELECT ?? '').trim())) {
    return
  }
  let prevDragging = false
  return selection.subscribe(() => {
    const s = selection.getState() as null | SelectionSnap
    const dragging = !!s?.isDragging
    if (prevDragging && !dragging && selection.hasSelection()) {
      selection.copySelectionNoClear()
    }
    prevDragging = dragging
  })
}, [selection])
```

Why this shape:
- `subscribe` is the only public mutation feed; there's no dedicated `onSelectionFinish` callback.
- Track `prevDragging` to detect the true→false edge (mouse-up). Without that, every mid-drag tick would re-copy.
- `copySelectionNoClear` (not `copySelection`) preserves the highlight, matching Ghostty/iTerm UX.
- Env-var escape hatch named `HERMES_TUI_NO_*` for symmetry with existing `HERMES_TUI_DISABLE_MOUSE`.

## Workflow checklist for any TUI patch

1. Read the user's goal; confirm it's TUI-layer (not agent/tool).
2. `search_files` in `ui-tui/src` and `ui-tui/packages/hermes-ink/src` for relevant identifiers.
3. Prefer wiring existing APIs over editing `packages/hermes-ink` (keeps upstream-rebase friction low). `useMainApp.ts` is the right place for app-level side effects on selection/keys/composer state.
4. Make the patch with `patch` tool. Ignore lint noise; only worry about errors mentioning files you touched.
5. `cd ~/.hermes/hermes-agent/ui-tui && npm run build` — must complete with `Done in Nms` on the esbuild line and no trailing tsc error.
6. Tell the user to **restart their `hermes` CLI** to pick up the new `dist/`.
7. Add a feature-flag env var so the user can toggle without rebuilding.
8. Note that upstream `hermes update` will overwrite `dist/` (and possibly `src/`) — patch is local until merged.

## Pitfalls log

- **Don't run raw `tsc`** in the TUI dir — wrong tsconfig, floods you with false errors.
- **Don't grep `dist/`** for source changes — edit `src/` only, then rebuild.
- **Don't import from `packages/hermes-ink/src/...`** — go through the `@hermes/ink` package barrel.
- **`getState()` returns `{}` to TS** — cast via `SelectionSnap` (or a local interface).
- **Tmux clipboard:** OSC 52 needs `set -g set-clipboard on` and `set -g allow-passthrough on`, otherwise the escape is silently dropped.
- **Restart required:** the running TUI loads `dist/` once at startup; no hot reload for users.
