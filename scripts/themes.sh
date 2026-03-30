#!/usr/bin/env bash
# Theme definitions for tmux-quick-fzf

get_theme_list() {
  echo "mocha frappe macchiato latte dracula nord gruvbox-dark gruvbox-light solarized-dark solarized-light one-dark tokyo-night rose-pine everforest auto none"
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
    dracula)
      echo "bg:#282a36,fg:#f8f8f2,bg+:#44475a,fg+:#f8f8f2,hl:#bd93f9,hl+:#50fa7b,border:#6272a4,preview-border:#6272a4,header:#ff79c6,info:#6272a4,prompt:#bd93f9,pointer:#ff79c6,marker:#ff5555,spinner:#50fa7b,preview-bg:#282a36,preview-fg:#f8f8f2,gutter:#282a36"
      ;;
    nord)
      echo "bg:#2e3440,fg:#d8dee9,bg+:#3b4252,fg+:#eceff4,hl:#88c0d0,hl+:#a3be8c,border:#4c566a,preview-border:#4c566a,header:#81a1c1,info:#4c566a,prompt:#b48ead,pointer:#b48ead,marker:#bf616a,spinner:#a3be8c,preview-bg:#2e3440,preview-fg:#d8dee9,gutter:#2e3440"
      ;;
    gruvbox-dark)
      echo "bg:#282828,fg:#ebdbb2,bg+:#3c3836,fg+:#fbf1c7,hl:#83a598,hl+:#b8bb26,border:#665c54,preview-border:#665c54,header:#d3869b,info:#a89984,prompt:#fe8019,pointer:#fe8019,marker:#fb4934,spinner:#b8bb26,preview-bg:#282828,preview-fg:#ebdbb2,gutter:#282828"
      ;;
    gruvbox-light)
      echo "bg:#fbf1c7,fg:#3c3836,bg+:#ebdbb2,fg+:#282828,hl:#076678,hl+:#79740e,border:#a89984,preview-border:#a89984,header:#8f3f71,info:#928374,prompt:#af3a03,pointer:#af3a03,marker:#cc241d,spinner:#79740e,preview-bg:#fbf1c7,preview-fg:#3c3836,gutter:#fbf1c7"
      ;;
    solarized-dark)
      echo "bg:#002b36,fg:#839496,bg+:#073642,fg+:#93a1a1,hl:#268bd2,hl+:#2aa198,border:#586e75,preview-border:#586e75,header:#6c71c4,info:#586e75,prompt:#b58900,pointer:#cb4b16,marker:#dc322f,spinner:#2aa198,preview-bg:#002b36,preview-fg:#839496,gutter:#002b36"
      ;;
    solarized-light)
      echo "bg:#fdf6e3,fg:#657b83,bg+:#eee8d5,fg+:#586e75,hl:#268bd2,hl+:#2aa198,border:#93a1a1,preview-border:#93a1a1,header:#6c71c4,info:#93a1a1,prompt:#b58900,pointer:#cb4b16,marker:#dc322f,spinner:#2aa198,preview-bg:#fdf6e3,preview-fg:#657b83,gutter:#fdf6e3"
      ;;
    one-dark)
      echo "bg:#282c34,fg:#abb2bf,bg+:#3e4452,fg+:#d7dae0,hl:#61afef,hl+:#98c379,border:#5c6370,preview-border:#5c6370,header:#c678dd,info:#5c6370,prompt:#e06c75,pointer:#c678dd,marker:#e06c75,spinner:#98c379,preview-bg:#282c34,preview-fg:#abb2bf,gutter:#282c34"
      ;;
    tokyo-night)
      echo "bg:#1a1b26,fg:#c0caf5,bg+:#292e42,fg+:#c0caf5,hl:#7aa2f7,hl+:#9ece6a,border:#3b4261,preview-border:#3b4261,header:#bb9af7,info:#565f89,prompt:#f7768e,pointer:#bb9af7,marker:#f7768e,spinner:#9ece6a,preview-bg:#1a1b26,preview-fg:#c0caf5,gutter:#1a1b26"
      ;;
    rose-pine)
      echo "bg:#191724,fg:#e0def4,bg+:#26233a,fg+:#e0def4,hl:#9ccfd8,hl+:#31748f,border:#6e6a86,preview-border:#6e6a86,header:#c4a7e7,info:#908caa,prompt:#ebbcba,pointer:#c4a7e7,marker:#eb6f92,spinner:#31748f,preview-bg:#191724,preview-fg:#e0def4,gutter:#191724"
      ;;
    everforest)
      echo "bg:#2d353b,fg:#d3c6aa,bg+:#3d484d,fg+:#d3c6aa,hl:#7fbbb3,hl+:#a7c080,border:#859289,preview-border:#859289,header:#d699b6,info:#859289,prompt:#e67e80,pointer:#d699b6,marker:#e67e80,spinner:#a7c080,preview-bg:#2d353b,preview-fg:#d3c6aa,gutter:#2d353b"
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
