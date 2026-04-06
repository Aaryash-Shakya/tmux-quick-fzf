# Help Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the truncating shortcuts header with a single `?: toggle help` hint, and update the help panel to tell users how to close it.

**Architecture:** Two one-line edits — the `--header` value in `find-window.sh` and the first line of output in `.help`. No new scripts, no state management, no fzf version constraints. The existing `preview()` binding already dismisses on typing/navigation.

**Tech Stack:** bash, fzf

---

### Task 1: Update the header in find-window.sh

**Files:**
- Modify: `scripts/find-window.sh:119`

- [ ] **Step 1: Make the change**

In `scripts/find-window.sh`, find line 119:
```bash
fzf_opts+=(--header="enter: switch | ctrl-w: new window | ctrl-s: new session | ctrl-t: theme | ?: help")
```
Replace with:
```bash
fzf_opts+=(--header="?: toggle help")
```

- [ ] **Step 2: Manually verify**

Run the plugin (e.g. via your tmux keybinding). Confirm:
- The header shows only `?: toggle help`
- Pressing `?` still shows the help panel in the preview area
- Typing any character after `?` dismisses the help and restores the normal preview

- [ ] **Step 3: Commit**

```bash
git add scripts/find-window.sh
git commit -m "feat(header): replace shortcut list with '?: toggle help' hint"
```

---

### Task 2: Update .help to tell users how to close it

**Files:**
- Modify: `scripts/.help`

- [ ] **Step 1: Make the change**

In `scripts/.help`, the `cat <<EOF` block currently starts with:
```
tmux-quick-fzf

Keybindings:
```
Add a close hint as the very first line of output:
```bash
cat <<EOF
Press ? or start typing to close

tmux-quick-fzf

Keybindings:
  enter    Switch to selected window
  ctrl-w   Create new window (named after query)
  ctrl-s   Create new session (named after query)
  ctrl-t   Open theme picker
  ?        Show this help
  esc      Cancel

Themes: $(get_theme_list | tr ' ' ', ')
Current: $current_theme
EOF
```

- [ ] **Step 2: Manually verify**

Open the plugin, press `?`. Confirm the help panel shows:
```
Press ? or start typing to close

tmux-quick-fzf

Keybindings:
  ...
```

Then type a character and confirm the help panel dismisses and the normal preview returns.

- [ ] **Step 3: Commit**

```bash
git add scripts/.help
git commit -m "feat(help): add close hint to help panel"
```
