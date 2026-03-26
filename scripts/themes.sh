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
