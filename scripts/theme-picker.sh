#!/usr/bin/env bash
# Open a theme picker fzf, save selection, then re-launch find-window

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/themes.sh"

# Original theme saved on first launch (before any become restarts)
original="${TMUX_QF_ORIGINAL_THEME}"
if [[ -z "$original" ]]; then
  original=$(tmux show-option -gqv @quick_fzf_theme 2>/dev/null)
  original="${original:-mocha}"
  export TMUX_QF_ORIGINAL_THEME="$original"
fi

# Preview theme = arg passed by become, or current saved theme
preview_theme="${1:-$original}"

# Build theme list (mark original with *)
theme_list=""
for t in $(get_theme_list); do
  if [[ "$t" == "$original" ]]; then
    theme_list+="$t *"$'\n'
  else
    theme_list+="$t"$'\n'
  fi
done
theme_list="${theme_list%$'\n'}"

# Color fzf with the preview theme
fzf_colors=$(get_theme_color_string "$preview_theme")
color_opt=()
[[ -n "$fzf_colors" ]] && color_opt=(--color="$fzf_colors")

# Launch picker — become restarts with focused theme's colors
selected=$(echo "$theme_list" | fzf \
  --header="enter: apply | esc: cancel  [previewing: $preview_theme]" \
  --preview="$CURRENT_DIR/theme-preview.sh {1}" \
  --preview-window=right:50% \
  --reverse \
  --no-sort \
  --with-nth=1.. \
  --bind="focus:become($CURRENT_DIR/theme-picker.sh {1})" \
  "${color_opt[@]}")

# Extract just the theme name (strip the * marker)
selected_theme=$(echo "$selected" | awk '{print $1}')

if [[ -n "$selected_theme" ]]; then
  # Enter: save selected theme
  tmux set-option -g @quick_fzf_theme "$selected_theme"
else
  # Esc: revert to original
  tmux set-option -g @quick_fzf_theme "$original"
fi

# Re-launch window search as a new popup (after this one closes)
tmux run-shell -b "$CURRENT_DIR/find-window.sh"
