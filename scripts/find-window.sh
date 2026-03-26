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
  FZF_TMUX_OPTS="-p -w 62% -h 50%"
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

# --- Extract tmux theme colors for fzf ---

extract_color() {
  local style="$1" attr="$2"
  local raw
  raw=$(tmux show-option -gv "$style" 2>/dev/null | grep -oP "${attr}=\\K[^,]+")
  [[ -z "$raw" || "$raw" == "default" ]] && return
  # Resolve tmux format strings like #{@thm_overlay_0}
  if [[ "$raw" == *'#{'* ]]; then
    raw=$(tmux display-message -p "$raw" 2>/dev/null)
  fi
  [[ -n "$raw" ]] && echo "$raw"
}

tmux_bg=$(extract_color "status-style" "bg")
tmux_fg=$(extract_color "status-style" "fg")
tmux_sel_bg=$(extract_color "mode-style" "bg")
tmux_sel_fg=$(extract_color "mode-style" "fg")
tmux_border=$(extract_color "pane-active-border-style" "fg")

fzf_colors=""
[[ -n "$tmux_bg" ]] && fzf_colors+="bg:${tmux_bg},preview-bg:${tmux_bg},"
[[ -n "$tmux_fg" ]] && fzf_colors+="fg:${tmux_fg},header:${tmux_fg},info:${tmux_fg},"
[[ -n "$tmux_sel_bg" ]] && fzf_colors+="bg+:${tmux_sel_bg},"
[[ -n "$tmux_sel_fg" ]] && fzf_colors+="fg+:${tmux_sel_fg},hl+:${tmux_sel_fg},"
[[ -n "$tmux_border" ]] && fzf_colors+="border:${tmux_border},preview-border:${tmux_border},"

# Remove trailing comma
fzf_colors="${fzf_colors%,}"

# --- Build fzf options ---

fzf_opts=()
fzf_opts+=(--delimiter=$'\t')
fzf_opts+=(--with-nth=2..)
fzf_opts+=(--print-query)
fzf_opts+=(--expect=ctrl-w,ctrl-s)
fzf_opts+=(--header="ctrl-w: new window | ctrl-s: new session | enter: switch")
fzf_opts+=(--reverse)
fzf_opts+=(--no-sort)

# Theme
if [[ -n "$fzf_colors" ]]; then
  fzf_opts+=(--color="$fzf_colors")
fi

# Preview
if [[ "$PREVIEW_ENABLED" = "1" ]]; then
  fzf_opts+=(--preview="$CURRENT_DIR/.preview {}")
  fzf_opts+=(--preview-window=right:50%:follow)
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
