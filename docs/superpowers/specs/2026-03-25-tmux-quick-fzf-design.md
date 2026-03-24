# tmux-quick-fzf — Design Spec

## Overview

A lightweight tmux plugin that provides fast fuzzy-find-and-switch for windows across all sessions. Uses fzf in a tmux popup (or split pane for older tmux) to search by session name and window name, with live pane preview. Also supports creating new windows or sessions directly from the search prompt via dedicated key bindings.

## File Structure

```
tmux-quick-fzf/
├── main.tmux              # TPM entry point — binds launch key
├── scripts/
│   ├── find-window.sh     # Core logic: list, fzf, switch/create
│   ├── .preview           # Preview script: captures pane content
│   └── .fzf-tmux          # Bundled fzf-tmux fallback (from junegunn/fzf)
└── README.md
```

## User Flow

1. User presses `prefix + f` (configurable).
2. `main.tmux` runs `scripts/find-window.sh` in background via `tmux run-shell -b`.
3. Script builds a structured list of all windows via `tmux list-windows -a -F` with a fixed internal format. The format string is constructed as: `"#{session_name}:#{window_index}"$'\t'"<display_format>"`, where `<display_format>` is the configurable portion (default: `#S:#I: #W`). The script automatically appends `#{?window_active, *,}` to mark the current window.
4. List is piped to `fzf-tmux` (never bare `fzf` — `run-shell` has no tty, so fzf-tmux must create its own popup/pane):
   - tmux >= 3.2: popup window (default 62% width, 38% height)
   - tmux < 3.2: split pane
5. fzf uses `--delimiter=$'\t' --with-nth=2..` to split on the tab and display only the human-readable columns. The hidden first field (`session:index`) is used for targeting.
6. fzf preview panel shows live pane content via `.preview` script using `tmux capture-pane -ep`.
7. User types to fuzzy-match against session names and window names.
8. fzf is launched with `--print-query` and `--expect=ctrl-w,ctrl-s`:
   - **Enter** (regular selection) → switch to selected window
   - **ctrl-w** → create new window in current session, named after the query
   - **ctrl-s** → create new session named after the query
9. On selection:
   - **Regular entry** → extract `session:index` from first field, run `tmux switch-client -t <session>` + `tmux select-window -t <session:index>`
   - **ctrl-w** → `tmux new-window -n <query>` in current session
   - **ctrl-s** → `tmux new-session -d -s <query>` + `tmux switch-client -t <query>`
   - If query is empty for create actions, let tmux use its default naming.

## Configuration

All configuration is via environment variables. Set them in `.tmux.conf` using `set-environment -g`:

```tmux
set-environment -g TMUX_QUICK_FZF_KEY "f"
set-environment -g TMUX_QUICK_FZF_WINDOW_FORMAT "#S:#I: #W"
```

Or export them in your shell profile (they propagate to tmux's server environment).

| Variable | Default | Purpose |
|---|---|---|
| `TMUX_QUICK_FZF_KEY` | `f` | Key binding (used with prefix) |
| `TMUX_QUICK_FZF_WINDOW_FORMAT` | `#S:#I: #W` | tmux format string for display columns |
| `TMUX_QUICK_FZF_OPTIONS` | auto-detected per tmux version | Extra fzf-tmux flags (popup size, position) |
| `TMUX_QUICK_FZF_PREVIEW` | `1` | Enable (`1`) or disable (`0`) preview panel |

### Default fzf-tmux Options

- tmux >= 3.2: `-p -w 62% -h 38%`
- tmux < 3.2: (empty — uses default split behavior)

## fzf-tmux Binary Resolution

1. Check if system `fzf-tmux` exists in `$PATH`.
2. If found, use it.
3. If not, fall back to bundled `scripts/.fzf-tmux` (copy of junegunn/fzf's fzf-tmux script, MIT-licensed — retain license header in the bundled copy).

## Preview System

The list sent to fzf has a structured first field: `session:window_index`, separated from display columns by a tab. The `.preview` script receives the full selected line, extracts the target using `target=${1%%$'\t'*}`, and runs:

```bash
tmux capture-pane -ep -t "$target"
```

This approach is robust regardless of the user's custom `TMUX_QUICK_FZF_WINDOW_FORMAT` — the preview always parses the fixed internal field, not the display text.

## Progressive fzf Feature Detection

The script detects the installed fzf version and enables features progressively:

- **All versions**: Core fuzzy search and selection.
- **fzf >= 0.58.0**: Border styling with `--input-border`, `--list-border`, `--preview-border` and labels.
- **fzf >= 0.61.0**: Ghost text hint (e.g., "Type to search windows...").

## Create New Window/Session

Instead of pinned list entries (which fzf cannot reliably keep visible during filtering), creation is handled via `--expect` key bindings:

- **ctrl-w**: Create new window in current session, named after the typed query.
- **ctrl-s**: Create new session named after the typed query.
- **Enter**: Switch to the selected window (default action).

fzf is launched with `--print-query --expect=ctrl-w,ctrl-s`. The output format is:

```
line 1: query string
line 2: pressed key (empty for Enter, "ctrl-w", or "ctrl-s")
line 3: selected entry (if any)
```

The script reads all three lines and dispatches accordingly. An fzf `--header` line documents these bindings for the user:

```
ctrl-w: new window | ctrl-s: new session | enter: switch
```

## Version Detection

### tmux

Uses a `vercomp` function for robust semantic version comparison (handles versions like `3.2a`, `next-3.4`):

```bash
tmux_version=$(tmux -V | sed -En 's/^tmux[^0-9]*([0-9]+(\.[0-9]+)*).*$/\1/p')
```

### fzf

```bash
fzf_version=$(fzf --version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
```

Both use a `vercomp` function (as in fzf-pane-switch) for reliable comparison.

## Current Window Handling

The current window is included in the list but marked with a `*` indicator (e.g., `dev:2: vim *`). The script automatically appends `#{?window_active, *,}` to the display format. Selecting the current window is harmless — `tmux switch-client` and `tmux select-window` succeed silently when already on the target.

## Error Handling

- If `fzf` is not found in `$PATH`: display a tmux message (`tmux display-message "fzf not found"`) and exit. (Note: `fzf-tmux` calls `fzf` internally, so both must be available. The bundled `.fzf-tmux` fallback covers the wrapper, but `fzf` itself is always required.)
- If `tmux list-windows` returns empty: exit gracefully (no windows to show).
- If creating a session with a name that already exists: catch the error and display `tmux display-message "Session '<name>' already exists"`. (Duplicate window names are allowed by tmux, so no check needed for ctrl-w.)
- If user cancels fzf (Escape/ctrl-c): script exits cleanly, no action taken.

## Compatibility

- **tmux**: >= 2.1 (split pane), >= 3.2 (popup)
- **fzf**: any version (progressive enhancement for newer)
- **Installation**: TPM (`set -g @plugin 'user/tmux-quick-fzf'`) or manual clone to `~/.tmux/plugins/`

## Dependencies

- `tmux` (required)
- `fzf` (required)
- TPM (optional, for managed installation)

## Future Extensibility

The plugin is designed as a single-action tool (find and switch). The fzf output dispatch (query/key/selection) provides a natural extension point — additional `--expect` keys can be added to support more actions (rename, kill, swap) without restructuring. If the action set grows large, the script can be refactored into a modular structure with an action menu, following the pattern established by tmux-fzf.
