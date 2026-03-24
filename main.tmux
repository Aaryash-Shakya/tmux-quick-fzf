#!/usr/bin/env bash
# tmux-quick-fzf: TPM entry point
# Binds the launch key to run find-window.sh

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMUX_QUICK_FZF_KEY="${TMUX_QUICK_FZF_KEY:-f}"

tmux bind-key "$TMUX_QUICK_FZF_KEY" run-shell -b "$CURRENT_DIR/scripts/find-window.sh"
