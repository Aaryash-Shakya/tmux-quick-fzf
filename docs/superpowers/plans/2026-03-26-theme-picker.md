# Theme Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ctrl-t cycle toggle with a dedicated theme picker fzf that shows color swatches in the preview, saves on enter, and returns to window search.

**Architecture:** A new `scripts/theme-picker.sh` script launches a nested fzf with the theme list. The preview for each theme shows colored sample text using ANSI escapes derived from the theme's hex colors. On enter, the selected theme is saved to `@quick_fzf_theme` and `find-window.sh` is re-launched. On esc, `find-window.sh` is re-launched without changes. In `find-window.sh`, `ctrl-t` uses `execute` to run theme-picker.sh then `abort` to close the current fzf (since theme-picker re-launches find-window).

**Tech Stack:** Bash, fzf `--bind`, fzf `--preview`, tmux user options

---

### Task 1: Create `scripts/theme-preview.sh` — color swatch preview

**Files:**
- Create: `scripts/theme-preview.sh`

This script takes a theme name as `$1`, sources `themes.sh`, gets the color string, and prints a colored sample using ANSI escape sequences converted from the theme's hex values.

- [ ] **Step 1: Create `scripts/theme-preview.sh`**

```bash
#!/usr/bin/env bash
# Preview a theme by showing colored sample text

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

theme="$1"
[[ -z "$theme" ]] && exit 0

colors=$(get_theme_color_string "$theme")
[[ -z "$colors" ]] && echo "No colors (default fzf theme)" && exit 0

# Extract hex color for a given fzf slot from the color string
get_hex() {
  echo "$colors" | tr ',' '\n' | grep "^${1}:" | head -1 | cut -d: -f2
}

# Convert #RRGGBB to ANSI 24-bit escape: \e[38;2;R;G;Bm (fg) or \e[48;2;R;G;Bm (bg)
hex_to_ansi() {
  local hex="${1#\#}" mode="$2"  # mode: 38=fg, 48=bg
  local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
  echo -n "\e[${mode};2;${r};${g};${b}m"
}

bg=$(get_hex bg)
fg=$(get_hex fg)
bg_sel=$(get_hex "bg+")
fg_sel=$(get_hex "fg+")
hl=$(get_hex hl)
border=$(get_hex border)
header=$(get_hex header)
prompt=$(get_hex prompt)
info=$(get_hex info)
green=$(get_hex spinner)

RST="\e[0m"

if [[ -n "$bg" && -n "$fg" ]]; then
  BG=$(hex_to_ansi "$bg" 48)
  FG=$(hex_to_ansi "$fg" 38)
  BG_SEL=$(hex_to_ansi "$bg_sel" 48)
  FG_SEL=$(hex_to_ansi "$fg_sel" 38)
  HL=$(hex_to_ansi "$hl" 38)
  BORDER=$(hex_to_ansi "$border" 38)
  HEADER=$(hex_to_ansi "$header" 38)
  PROMPT=$(hex_to_ansi "$prompt" 38)
  INFO=$(hex_to_ansi "$info" 38)
  GREEN=$(hex_to_ansi "$green" 38)

  current=$(tmux show-option -gqv @quick_fzf_theme 2>/dev/null)
  current="${current:-mocha}"

  echo -e "${BG}${BORDER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
  echo -e "${BG}${HEADER}  Theme: ${theme}${RST}"
  echo -e "${BG}${BORDER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
  echo ""
  echo -e "${BG}${PROMPT}  > ${FG}Search query here${RST}"
  echo -e "${BG}${INFO}  4/12${RST}"
  echo -e "${BG}${FG_SEL}${BG_SEL}  > main:1  zsh${RST}"
  echo -e "${BG}${FG}    main:2  ${HL}nvim${RST}"
  echo -e "${BG}${FG}    dev:1   node${RST}"
  echo -e "${BG}${FG}    dev:2   ${HL}nvim${RST}"
  echo ""
  echo -e "${BG}${BORDER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
  echo ""
  if [[ "$theme" == "$current" ]]; then
    echo -e "${GREEN}  ● Current theme${RST}"
  else
    echo -e "${INFO}  ○ Press enter to apply${RST}"
  fi
fi
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x scripts/theme-preview.sh
git add scripts/theme-preview.sh
git commit -m "feat(theme): add theme preview script with color swatches"
```

---

### Task 2: Create `scripts/theme-picker.sh` — nested fzf theme selector

**Files:**
- Create: `scripts/theme-picker.sh`

- [ ] **Step 1: Create `scripts/theme-picker.sh`**

```bash
#!/usr/bin/env bash
# Open a theme picker fzf, save selection, then re-launch find-window

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

current=$(tmux show-option -gqv @quick_fzf_theme 2>/dev/null)
current="${current:-mocha}"

# Build theme list with current marker
theme_list=""
for t in $(get_theme_list); do
  if [[ "$t" == "$current" ]]; then
    theme_list+="$t *"$'\n'
  else
    theme_list+="$t"$'\n'
  fi
done

# Remove trailing newline
theme_list="${theme_list%$'\n'}"

# Find fzf-tmux binary (same logic as find-window.sh)
if command -v fzf-tmux &>/dev/null; then
  FZF_TMUX_BIN="fzf-tmux"
else
  FZF_TMUX_BIN="$CURRENT_DIR/.fzf-tmux"
fi

# Get current theme colors for the picker itself
fzf_colors=$(get_theme_color_string "$current")
color_opt=()
[[ -n "$fzf_colors" ]] && color_opt=(--color="$fzf_colors")

# Launch theme picker
selected=$(echo "$theme_list" | $FZF_TMUX_BIN -p -w 62% -h 50% -- \
  --header="enter: apply theme | esc: cancel" \
  --preview="$CURRENT_DIR/theme-preview.sh {1}" \
  --preview-window=right:50% \
  --reverse \
  --no-sort \
  --with-nth=1.. \
  --input-border --input-label=" Search " \
  --list-border --list-label=" Themes " \
  --preview-border --preview-label=" Preview " \
  "${color_opt[@]}")

# Extract just the theme name (strip the * marker)
selected_theme=$(echo "$selected" | awk '{print $1}')

if [[ -n "$selected_theme" ]]; then
  tmux set-option -g @quick_fzf_theme "$selected_theme"
fi

# Re-launch window search
"$CURRENT_DIR/find-window.sh"
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x scripts/theme-picker.sh
git add scripts/theme-picker.sh
git commit -m "feat(theme): add theme picker with preview and save"
```

---

### Task 3: Update `find-window.sh` — bind ctrl-t to theme picker

**Files:**
- Modify: `scripts/find-window.sh:92-98`

- [ ] **Step 1: Replace ctrl-t binding**

Replace the current keybinding lines (lines 96-98):

```bash
# Keybindings inside fzf
fzf_opts+=(--bind="ctrl-t:execute-silent($CURRENT_DIR/cycle-theme.sh)+transform-header(echo \"enter: switch | ctrl-w: new window | ctrl-s: new session | ctrl-t: theme | ?: help  [theme: \$(tmux show-option -gqv @quick_fzf_theme)]\")")
fzf_opts+=(--bind="?:preview($CURRENT_DIR/.help)+change-preview-label( Help )")
```

With:

```bash
# Keybindings inside fzf
fzf_opts+=(--bind="ctrl-t:abort+execute($CURRENT_DIR/theme-picker.sh)")
fzf_opts+=(--bind="?:preview($CURRENT_DIR/.help)+change-preview-label( Help )")
```

Wait — `abort+execute` won't work since abort closes fzf before execute runs. The correct approach: use `execute` which runs the command and returns to fzf. But we want to *replace* the current fzf with the theme picker. The cleanest way: use `become` (fzf 0.38+) which replaces the fzf process.

Replace with:

```bash
# Keybindings inside fzf
fzf_opts+=(--bind="ctrl-t:become($CURRENT_DIR/theme-picker.sh)")
fzf_opts+=(--bind="?:preview($CURRENT_DIR/.help)+change-preview-label( Help )")
```

- [ ] **Step 2: Commit**

```bash
git add scripts/find-window.sh
git commit -m "feat(theme): bind ctrl-t to launch theme picker via become"
```

---

### Task 4: Update help text and clean up cycle-theme.sh

**Files:**
- Modify: `scripts/.help`
- Delete: `scripts/cycle-theme.sh` (no longer needed — theme-picker.sh replaces it)

- [ ] **Step 1: Update `.help` to reflect new ctrl-t behavior**

Replace the full content of `scripts/.help`:

```bash
#!/usr/bin/env bash
# Help text for tmux-quick-fzf

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

current_theme=$(tmux show-option -gqv @quick_fzf_theme 2>/dev/null)
current_theme="${current_theme:-mocha}"

cat <<EOF
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

- [ ] **Step 2: Remove cycle-theme.sh**

```bash
git rm scripts/cycle-theme.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/.help
git commit -m "feat(theme): update help text and remove cycle-theme.sh"
```

---

## Verification

1. `bash main.tmux` to reload
2. `prefix+f` — window search opens with current theme colors
3. Press `ctrl-t` — window search closes, theme picker opens showing all 6 themes
4. Move through themes — preview shows colored swatch with sample fzf UI
5. Current theme is marked with `●`
6. Press `enter` on a theme — saves it, returns to window search with new colors
7. Press `esc` in theme picker — returns to window search without changing theme
8. Press `?` in window search — shows help with "ctrl-t: Open theme picker"
