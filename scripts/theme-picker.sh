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
