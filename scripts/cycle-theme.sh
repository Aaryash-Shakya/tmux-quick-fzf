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
