# tmux-quick-fzf Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a tmux plugin that fuzzy-finds and switches windows across all sessions using fzf, with live pane preview and new window/session creation.

**Architecture:** Single entry point (`main.tmux`) binds a key that launches a bash script (`find-window.sh`). The script lists all windows, pipes them through `fzf-tmux` with a preview panel, and dispatches the result (switch, new window, or new session) based on the fzf output.

**Tech Stack:** Bash, tmux, fzf, fzf-tmux

**Spec:** `docs/superpowers/specs/2026-03-25-tmux-quick-fzf-design.md`

---

## File Map

| File | Responsibility |
|---|---|
| `main.tmux` | TPM entry point. Reads `TMUX_QUICK_FZF_KEY`, binds it to launch `find-window.sh`. |
| `scripts/find-window.sh` | Core logic: version detection, env setup, window listing, fzf invocation, result dispatch. |
| `scripts/.preview` | Receives fzf selection line, extracts `session:window_index`, runs `tmux capture-pane -ep`. |
| `scripts/.fzf-tmux` | Bundled fallback copy of junegunn/fzf's `fzf-tmux` script (MIT-licensed). |
| `README.md` | Installation, usage, configuration, key bindings documentation. |

---

### Task 1: Bundle the `.fzf-tmux` fallback script

**Files:**
- Create: `scripts/.fzf-tmux`

- [ ] **Step 1: Copy the fzf-tmux script from the tmux-fzf reference plugin**

Copy `/home/aaryash/Documents/personal/tmux/tmux-fzf/scripts/.fzf-tmux` to `scripts/.fzf-tmux`. This is the junegunn/fzf `fzf-tmux` wrapper (MIT-licensed). Keep the file as-is — do not modify it.

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/.fzf-tmux`

- [ ] **Step 3: Verify the license header is present**

Run: `head -3 scripts/.fzf-tmux`
Expected: Should contain the fzf-tmux header comment.

- [ ] **Step 4: Commit**

```bash
git add scripts/.fzf-tmux
git commit -m "chore: bundle fzf-tmux fallback script from junegunn/fzf"
```

---

### Task 2: Create the `.preview` script

**Files:**
- Create: `scripts/.preview`

- [ ] **Step 1: Write the preview script**

```bash
#!/usr/bin/env bash
# Preview script for tmux-quick-fzf
# Receives a fzf selection line, extracts session:window_index from the
# tab-delimited first field, and captures the pane content.

[[ -z "$1" ]] && exit 0

# Extract the target (everything before the first tab)
target="${1%%$'\t'*}"

[[ -z "$target" ]] && exit 0

tmux capture-pane -ep -t "$target" 2>/dev/null
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/.preview`

- [ ] **Step 3: Test manually**

Run inside tmux: `bash scripts/.preview "dev:0"` (replace `dev:0` with an actual session:window_index from `tmux list-windows -a -F '#{session_name}:#{window_index}'`).
Expected: Prints the visible content of that pane.

- [ ] **Step 4: Commit**

```bash
git add scripts/.preview
git commit -m "feat: add preview script for pane content capture"
```

---

### Task 3: Create the `find-window.sh` core script

**Files:**
- Create: `scripts/find-window.sh`

This is the main script. It handles version detection, fzf-tmux resolution, window listing, fzf invocation, and result dispatch.

- [ ] **Step 1: Write the full `find-window.sh` script**

```bash
#!/usr/bin/env bash
# tmux-quick-fzf: fuzzy find and switch tmux windows
# Launched via tmux run-shell from main.tmux

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Error checks ---

if ! command -v fzf &>/dev/null; then
  tmux display-message "tmux-quick-fzf: fzf not found in PATH"
  exit 1
fi

# --- Version detection ---

tmux_version=$(tmux -V | sed -En 's/^tmux[^0-9]*([0-9]+(\.[0-9]+)*).*$/\1/p')
fzf_version=$(fzf --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')

# Compare two version strings: returns 0 (equal), 1 (v1 > v2), 2 (v1 < v2)
vercomp() {
  local v1="$1" v2="$2"
  IFS='.' read -r -a ver1 <<< "$v1"
  IFS='.' read -r -a ver2 <<< "$v2"
  for i in 0 1 2; do
    local num1="${ver1[i]:-0}"
    local num2="${ver2[i]:-0}"
    if (( num1 > num2 )); then return 1
    elif (( num1 < num2 )); then return 2
    fi
  done
  return 0
}

# version_ge: true if $1 >= $2
version_ge() {
  vercomp "$1" "$2"
  [[ $? -ne 2 ]]
}

# --- Resolve fzf-tmux binary ---

if command -v fzf-tmux &>/dev/null; then
  FZF_TMUX_BIN="fzf-tmux"
else
  FZF_TMUX_BIN="$CURRENT_DIR/.fzf-tmux"
  if [[ ! -x "$FZF_TMUX_BIN" ]]; then
    tmux display-message "tmux-quick-fzf: fzf-tmux not found"
    exit 1
  fi
fi

# --- Configuration ---

WINDOW_FORMAT="${TMUX_QUICK_FZF_WINDOW_FORMAT:-#S:#I: #W}"
PREVIEW_ENABLED="${TMUX_QUICK_FZF_PREVIEW:-1}"

# Build fzf-tmux layout options
if [[ -n "$TMUX_QUICK_FZF_OPTIONS" ]]; then
  FZF_TMUX_OPTS="$TMUX_QUICK_FZF_OPTIONS"
elif version_ge "$tmux_version" "3.2"; then
  FZF_TMUX_OPTS="-p -w 62% -h 38%"
else
  FZF_TMUX_OPTS=""
fi

# --- Build window list ---

# Internal format: session:index<TAB>display_columns
# The display_columns include the user format + active window marker
list_format="#{session_name}:#{window_index}"$'\t'"${WINDOW_FORMAT}#{?window_active, *,}"

windows=$(tmux list-windows -a -F "$list_format" 2>/dev/null)

if [[ -z "$windows" ]]; then
  tmux display-message "tmux-quick-fzf: no windows found"
  exit 0
fi

# --- Build fzf options ---

fzf_opts=()
fzf_opts+=(--delimiter=$'\t')
fzf_opts+=(--with-nth=2..)
fzf_opts+=(--print-query)
fzf_opts+=(--expect=ctrl-w,ctrl-s)
fzf_opts+=(--header="ctrl-w: new window | ctrl-s: new session | enter: switch")
fzf_opts+=(--reverse)
fzf_opts+=(--no-sort)

# Preview
if [[ "$PREVIEW_ENABLED" = "1" ]]; then
  fzf_opts+=(--preview="$CURRENT_DIR/.preview {}")
  fzf_opts+=(--preview-window=right:50%)
fi

# Progressive fzf features
if version_ge "$fzf_version" "0.61.0"; then
  fzf_opts+=(--ghost="Type to search windows...")
  fzf_opts+=(--input-border --input-label=" Search ")
  fzf_opts+=(--list-border --list-label=" Windows ")
  fzf_opts+=(--preview-border --preview-label=" Preview ")
elif version_ge "$fzf_version" "0.58.0"; then
  fzf_opts+=(--input-border --input-label=" Search ")
  fzf_opts+=(--list-border --list-label=" Windows ")
  fzf_opts+=(--preview-border --preview-label=" Preview ")
fi

# --- Run fzf ---

result=$(echo "$windows" | $FZF_TMUX_BIN $FZF_TMUX_OPTS -- "${fzf_opts[@]}")

# fzf output with --print-query --expect:
#   line 1: query
#   line 2: key pressed (empty for Enter)
#   line 3: selected entry
query=$(sed -n '1p' <<< "$result")
key=$(sed -n '2p' <<< "$result")
selection=$(sed -n '3p' <<< "$result")

# User cancelled
if [[ -z "$key" && -z "$selection" ]]; then
  exit 0
fi

# --- Dispatch ---

case "$key" in
  ctrl-w)
    # Create new window in current session
    if [[ -n "$query" ]]; then
      tmux new-window -n "$query"
    else
      tmux new-window
    fi
    ;;
  ctrl-s)
    # Create new session
    if [[ -n "$query" ]]; then
      if ! tmux new-session -d -s "$query" 2>/dev/null; then
        tmux display-message "Session '$query' already exists"
        exit 1
      fi
      tmux switch-client -t "$query"
    else
      # -P prints the new session info, -F extracts the name
      new_session=$(tmux new-session -dP -F '#{session_name}')
      tmux switch-client -t "$new_session"
    fi
    ;;
  *)
    # Switch to selected window
    if [[ -n "$selection" ]]; then
      # Extract session:index from the first tab-delimited field
      target="${selection%%$'\t'*}"
      session="${target%%:*}"
      tmux switch-client -t "$session"
      tmux select-window -t "$target"
    fi
    ;;
esac
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/find-window.sh`

- [ ] **Step 3: Smoke test — verify the window list generation**

Run inside tmux:
```bash
WINDOW_FORMAT="#S:#I: #W" bash -c '
  list_format="#{session_name}:#{window_index}"$'"'"'\t'"'"'"${WINDOW_FORMAT}#{?window_active, *,}"
  tmux list-windows -a -F "$list_format"
'
```
Expected: Tab-separated output like `dev:0\tdev:0: bash *` for each window.

- [ ] **Step 4: Smoke test — run the full script interactively**

Run inside tmux: `bash scripts/find-window.sh`
Expected: fzf popup opens with window list, preview shows pane content, Enter switches to selected window.

- [ ] **Step 5: Test ctrl-w (new window creation)**

Run inside tmux: `bash scripts/find-window.sh`, type a name, press `ctrl-w`.
Expected: New window created in current session with the typed name.

- [ ] **Step 6: Test ctrl-s (new session creation)**

Run inside tmux: `bash scripts/find-window.sh`, type a name, press `ctrl-s`.
Expected: New session created and switched to.

- [ ] **Step 7: Test cancellation**

Run inside tmux: `bash scripts/find-window.sh`, press `Escape`.
Expected: Script exits cleanly, no action taken.

- [ ] **Step 8: Commit**

```bash
git add scripts/find-window.sh
git commit -m "feat: add core find-window script with fzf integration"
```

---

### Task 4: Create the `main.tmux` TPM entry point

**Files:**
- Create: `main.tmux`

- [ ] **Step 1: Write `main.tmux`**

```bash
#!/usr/bin/env bash
# tmux-quick-fzf: TPM entry point
# Binds the launch key to run find-window.sh

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMUX_QUICK_FZF_KEY="${TMUX_QUICK_FZF_KEY:-f}"

tmux bind-key "$TMUX_QUICK_FZF_KEY" run-shell -b "$CURRENT_DIR/scripts/find-window.sh"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x main.tmux`

- [ ] **Step 3: Test TPM integration**

Add to `~/.tmux.conf`:
```tmux
set -g @plugin 'aaryash/tmux-quick-fzf'
```
Or test manually: `bash main.tmux` then press `prefix + f`.
Expected: fzf window opens with the window finder.

- [ ] **Step 4: Test custom key binding**

Run: `TMUX_QUICK_FZF_KEY=g bash main.tmux`, then press `prefix + g`.
Expected: fzf window opens.

- [ ] **Step 5: Commit**

```bash
git add main.tmux
git commit -m "feat: add main.tmux TPM entry point"
```

---

### Task 5: Write the README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

```markdown
# tmux-quick-fzf

Fast fuzzy finder for tmux windows. Search across all sessions and windows, switch instantly, or create new ones — all from a single fzf prompt.

## Features

- Fuzzy search across all sessions and windows
- Live pane content preview
- Create new windows or sessions directly from the search prompt
- Popup window (tmux >= 3.2) with split-pane fallback for older versions
- Progressive fzf enhancements (borders, ghost text) for newer fzf versions
- Fully configurable via environment variables

## Requirements

- [tmux](https://github.com/tmux/tmux) >= 2.1 (popup requires >= 3.2)
- [fzf](https://github.com/junegunn/fzf)

## Installation

### With TPM (recommended)

Add to your `~/.tmux.conf`:

```tmux
set -g @plugin 'aaryash/tmux-quick-fzf'
```

Then press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/aaryash/tmux-quick-fzf ~/.tmux/plugins/tmux-quick-fzf
```

Add to your `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-quick-fzf/main.tmux
```

Then reload tmux: `tmux source-file ~/.tmux.conf`

## Usage

Press `prefix + f` to open the fuzzy finder.

### Key Bindings (inside fzf)

| Key | Action |
|---|---|
| `Enter` | Switch to selected window |
| `ctrl-w` | Create new window (named after your search query) |
| `ctrl-s` | Create new session (named after your search query) |
| `Escape` | Cancel |

The search matches against both **session names** and **window names**. The current window is marked with `*`.

## Configuration

All options are set via environment variables. Add them to your `~/.tmux.conf`:

```tmux
# Change the launch key (default: f)
set-environment -g TMUX_QUICK_FZF_KEY "f"

# Custom window display format (default: #S:#I: #W)
set-environment -g TMUX_QUICK_FZF_WINDOW_FORMAT "#S:#I: #W"

# Custom fzf-tmux layout options
set-environment -g TMUX_QUICK_FZF_OPTIONS "-p -w 70% -h 50%"

# Disable preview (default: 1)
set-environment -g TMUX_QUICK_FZF_PREVIEW "0"
```

Or export them in your shell profile:

```bash
export TMUX_QUICK_FZF_KEY="f"
```

### Options Reference

| Variable | Default | Description |
|---|---|---|
| `TMUX_QUICK_FZF_KEY` | `f` | Key binding (used with prefix) |
| `TMUX_QUICK_FZF_WINDOW_FORMAT` | `#S:#I: #W` | tmux format string for window display |
| `TMUX_QUICK_FZF_OPTIONS` | auto-detected | fzf-tmux layout flags |
| `TMUX_QUICK_FZF_PREVIEW` | `1` | Enable (`1`) or disable (`0`) pane preview |

### Window Format

The `TMUX_QUICK_FZF_WINDOW_FORMAT` variable accepts any tmux `FORMAT` string. Some useful variables:

| Variable | Description |
|---|---|
| `#S` | Session name |
| `#I` | Window index |
| `#W` | Window name |
| `#F` | Window flags |
| `#P` | Pane index |
| `#{pane_current_command}` | Current command in pane |
| `#{pane_current_path}` | Current path in pane |

Example — show window name and current command:

```tmux
set-environment -g TMUX_QUICK_FZF_WINDOW_FORMAT "#S:#I: #W [#{pane_current_command}]"
```

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with installation, usage, and configuration"
```

---

### Task 6: Final integration test

- [ ] **Step 1: Verify complete file structure**

Run: `find . -type f | grep -v '.git/' | sort`
Expected:
```
./docs/superpowers/plans/2026-03-25-tmux-quick-fzf.md
./docs/superpowers/specs/2026-03-25-tmux-quick-fzf-design.md
./main.tmux
./README.md
./scripts/.fzf-tmux
./scripts/.preview
./scripts/find-window.sh
```

- [ ] **Step 2: Verify all scripts are executable**

Run: `ls -la main.tmux scripts/.fzf-tmux scripts/.preview scripts/find-window.sh | awk '{print $1, $NF}'`
Expected: All show `-rwxr-xr-x` permissions.

- [ ] **Step 3: End-to-end test — load plugin and use it**

```bash
# Source the plugin
bash main.tmux

# Create a few test sessions/windows
tmux new-session -d -s test1 -n editor
tmux new-window -t test1 -n server
tmux new-session -d -s test2 -n notes
```

Press `prefix + f`. Verify:
1. fzf popup opens (or split pane on older tmux)
2. All windows from all sessions are listed
3. Current window is marked with `*`
4. Preview shows pane content
5. Typing filters by session and window name
6. Enter switches to selected window
7. ctrl-w creates new window
8. ctrl-s creates new session
9. Escape cancels cleanly

- [ ] **Step 4: Test with preview disabled**

Run: `TMUX_QUICK_FZF_PREVIEW=0 bash scripts/find-window.sh`
Expected: fzf opens without preview panel.

- [ ] **Step 5: Test with custom format**

Run: `TMUX_QUICK_FZF_WINDOW_FORMAT="#S:#I: #W [#{pane_current_command}]" bash scripts/find-window.sh`
Expected: Each entry shows the current command in brackets.
