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
