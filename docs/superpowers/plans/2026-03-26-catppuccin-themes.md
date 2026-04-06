# Catppuccin Theme System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add built-in Catppuccin theme support (Mocha, Frappe, Macchiato, Latte) with Alt+t cycling, replacing the raw dynamic color extraction on `feat/tmux-theme-colors`.

**Architecture:** Theme definitions live in a standalone `scripts/themes.sh` sourced by `find-window.sh`. Current theme is persisted in tmux user option `@quick_fzf_theme`. A separate `scripts/cycle-theme.sh` is bound to Alt+t to cycle themes. The existing dynamic extraction becomes the `auto` theme.

**Tech Stack:** Bash (case statements for portability, no associative arrays), tmux user options, fzf `--color`

**Branch:** All work on `feat/tmux-theme-colors` (extends existing commit `7c56437`)

---

### Task 1: Create `scripts/themes.sh` — theme definitions

**Files:**
- Create: `scripts/themes.sh`

- [ ] **Step 1: Create `scripts/themes.sh` with `get_theme_list` and `get_theme_color_string`**

```bash
#!/usr/bin/env bash
# Theme definitions for tmux-quick-fzf

get_theme_list() {
  echo "mocha frappe macchiato latte auto none"
}

# Resolve a color attribute from a tmux style option.
# Filters out "default" and expands tmux format strings like #{@thm_overlay_0}.
extract_color() {
  local style="$1" attr="$2"
  local raw
  raw=$(tmux show-option -gv "$style" 2>/dev/null | grep -oE "${attr}=[^, ]+" | sed "s/${attr}=//")
  [[ -z "$raw" || "$raw" == "default" ]] && return
  if [[ "$raw" == *'#{'* ]]; then
    raw=$(tmux display-message -p "$raw" 2>/dev/null)
  fi
  [[ -n "$raw" ]] && echo "$raw"
}

# Build fzf --color string by reading live tmux style options.
_build_auto_colors() {
  local tmux_bg tmux_fg tmux_sel_bg tmux_sel_fg tmux_border colors=""

  tmux_bg=$(extract_color "status-style" "bg")
  tmux_fg=$(extract_color "status-style" "fg")
  tmux_sel_bg=$(extract_color "mode-style" "bg")
  tmux_sel_fg=$(extract_color "mode-style" "fg")
  tmux_border=$(extract_color "pane-active-border-style" "fg")

  [[ -n "$tmux_bg" ]]     && colors+="bg:${tmux_bg},preview-bg:${tmux_bg},gutter:${tmux_bg},"
  [[ -n "$tmux_fg" ]]     && colors+="fg:${tmux_fg},preview-fg:${tmux_fg},header:${tmux_fg},info:${tmux_fg},"
  [[ -n "$tmux_sel_bg" ]] && colors+="bg+:${tmux_sel_bg},"
  [[ -n "$tmux_sel_fg" ]] && colors+="fg+:${tmux_sel_fg},hl+:${tmux_sel_fg},"
  [[ -n "$tmux_border" ]] && colors+="border:${tmux_border},preview-border:${tmux_border},"

  echo "${colors%,}"
}

# Main entry point. Takes a theme name, prints the fzf --color value string.
get_theme_color_string() {
  local theme="${1:-mocha}"
  case "$theme" in
    mocha)
      echo "bg:#1e1e2e,fg:#cdd6f4,bg+:#313244,fg+:#cdd6f4,hl:#89b4fa,hl+:#a6e3a1,border:#6c7086,preview-border:#6c7086,header:#b4befe,info:#a6adc8,prompt:#cba6f7,pointer:#cba6f7,marker:#f38ba8,spinner:#a6e3a1,preview-bg:#1e1e2e,preview-fg:#cdd6f4,gutter:#1e1e2e"
      ;;
    frappe)
      echo "bg:#303446,fg:#c6d0f5,bg+:#414559,fg+:#c6d0f5,hl:#8caaee,hl+:#a6d189,border:#737994,preview-border:#737994,header:#babbf1,info:#a5adce,prompt:#ca9ee6,pointer:#ca9ee6,marker:#e78284,spinner:#a6d189,preview-bg:#303446,preview-fg:#c6d0f5,gutter:#303446"
      ;;
    macchiato)
      echo "bg:#24273a,fg:#cad3f5,bg+:#363a4f,fg+:#cad3f5,hl:#8aadf4,hl+:#a6da95,border:#6e738d,preview-border:#6e738d,header:#b7bdf8,info:#a5adcb,prompt:#c6a0f6,pointer:#c6a0f6,marker:#ed8796,spinner:#a6da95,preview-bg:#24273a,preview-fg:#cad3f5,gutter:#24273a"
      ;;
    latte)
      echo "bg:#eff1f5,fg:#4c4f69,bg+:#ccd0da,fg+:#4c4f69,hl:#1e66f5,hl+:#40a02b,border:#9ca0b0,preview-border:#9ca0b0,header:#7287fd,info:#6c6f85,prompt:#8839ef,pointer:#8839ef,marker:#d20f39,spinner:#40a02b,preview-bg:#eff1f5,preview-fg:#4c4f69,gutter:#eff1f5"
      ;;
    auto)
      _build_auto_colors
      ;;
    none)
      echo ""
      ;;
    *)
      # Unknown theme, fall back to mocha
      get_theme_color_string "mocha"
      ;;
  esac
}
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/themes.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/themes.sh
git commit -m "feat(theme): add Catppuccin theme definitions"
```

---

### Task 2: Create `scripts/cycle-theme.sh`

**Files:**
- Create: `scripts/cycle-theme.sh`

- [ ] **Step 1: Create `scripts/cycle-theme.sh`**

```bash
#!/usr/bin/env bash
# Cycle through available tmux-quick-fzf themes

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

themes=($(get_theme_list))
current=$(tmux show-option -gqv @quick_fzf_theme)
current="${current:-mocha}"

# Find current index and advance
next_theme="${themes[0]}"
for i in "${!themes[@]}"; do
  if [[ "${themes[$i]}" == "$current" ]]; then
    next_idx=$(( (i + 1) % ${#themes[@]} ))
    next_theme="${themes[$next_idx]}"
    break
  fi
done

tmux set-option -g @quick_fzf_theme "$next_theme"
tmux display-message "tmux-quick-fzf theme: $next_theme"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/cycle-theme.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/cycle-theme.sh
git commit -m "feat(theme): add theme cycling script"
```

---

### Task 3: Modify `main.tmux` — initialize theme and bind Alt+t

**Files:**
- Modify: `main.tmux`

- [ ] **Step 1: Add theme initialization and Alt+t binding**

After the existing `bind-key` line, add:

```bash
# Initialize theme from env var if not already set
current_theme=$(tmux show-option -gqv @quick_fzf_theme)
if [ -z "$current_theme" ]; then
  tmux set-option -g @quick_fzf_theme "${TMUX_QUICK_FZF_THEME:-mocha}"
fi

# Bind Alt+t to cycle themes
TMUX_QUICK_FZF_CYCLE_KEY="${TMUX_QUICK_FZF_CYCLE_KEY:-M-t}"
tmux bind-key -n "$TMUX_QUICK_FZF_CYCLE_KEY" run-shell -b "$CURRENT_DIR/scripts/cycle-theme.sh"
```

The full `main.tmux` becomes:

```bash
#!/usr/bin/env bash
# tmux-quick-fzf: TPM entry point
# Binds the launch key to run find-window.sh

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMUX_QUICK_FZF_KEY="${TMUX_QUICK_FZF_KEY:-f}"

tmux bind-key "$TMUX_QUICK_FZF_KEY" run-shell -b "$CURRENT_DIR/scripts/find-window.sh"

# Initialize theme from env var if not already set
current_theme=$(tmux show-option -gqv @quick_fzf_theme)
if [ -z "$current_theme" ]; then
  tmux set-option -g @quick_fzf_theme "${TMUX_QUICK_FZF_THEME:-mocha}"
fi

# Bind Alt+t to cycle themes
TMUX_QUICK_FZF_CYCLE_KEY="${TMUX_QUICK_FZF_CYCLE_KEY:-M-t}"
tmux bind-key -n "$TMUX_QUICK_FZF_CYCLE_KEY" run-shell -b "$CURRENT_DIR/scripts/cycle-theme.sh"
```

- [ ] **Step 2: Commit**

```bash
git add main.tmux
git commit -m "feat(theme): initialize theme option and bind Alt+t for cycling"
```

---

### Task 4: Modify `find-window.sh` — use theme system

**Files:**
- Modify: `scripts/find-window.sh` (on `feat/tmux-theme-colors` branch)

- [ ] **Step 1: Replace the inline color extraction block with theme sourcing**

Replace the entire `# --- Extract tmux theme colors for fzf ---` section (the `extract_color` function, the 5 variable assignments, and the `fzf_colors` construction) with:

```bash
# --- Resolve theme colors for fzf ---

source "$CURRENT_DIR/themes.sh"
theme=$(tmux show-option -gqv @quick_fzf_theme)
fzf_colors=$(get_theme_color_string "${theme:-mocha}")
```

The `# Theme` block that applies `--color` stays unchanged:

```bash
# Theme
if [[ -n "$fzf_colors" ]]; then
  fzf_opts+=(--color="$fzf_colors")
fi
```

- [ ] **Step 2: Commit**

```bash
git add scripts/find-window.sh
git commit -m "feat(theme): integrate theme system into find-window"
```

---

### Task 5: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add theme documentation section**

Add a "Themes" section after the existing configuration section covering:
- Available themes: `mocha` (default), `frappe`, `macchiato`, `latte`, `auto`, `none`
- Setting default theme: `set-environment -g TMUX_QUICK_FZF_THEME "frappe"`
- Runtime cycling: Alt+t
- Customizing cycle key: `set-environment -g TMUX_QUICK_FZF_CYCLE_KEY "M-T"`
- Setting directly: `tmux set -g @quick_fzf_theme latte`

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add theme configuration to README"
```

---

## Verification

1. `tmux source ~/.tmux.conf` to reload the plugin
2. Press `Alt+t` — should see "tmux-quick-fzf theme: frappe" message
3. Press `prefix+f` — fzf popup should use Frappe colors
4. Press `Alt+t` multiple times — cycles through all 6 themes with display messages
5. Press `prefix+f` after selecting "latte" — should show light theme
6. Press `prefix+f` after selecting "none" — should show default fzf colors
7. Press `prefix+f` after selecting "auto" — should extract colors from tmux styles
8. Set `TMUX_QUICK_FZF_THEME=macchiato` in `.tmux.conf`, reload — should default to macchiato
