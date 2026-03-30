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

  # Get terminal width for the preview pane, fall back to 40
  w=${FZF_PREVIEW_COLUMNS:-40}

  # Print a full-width line: bg fills to edge via \e[K (erase to end of line)
  # \e[K uses the current background color to fill
  line() {
    printf "${BG}${1}%-${w}s${RST}\n" ""
  }
  textline() {
    printf "${BG}${1}%s\e[K${RST}\n" "$2"
  }

  # Fill entire preview with theme background using \e[K
  textline "$BORDER" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  textline "$HEADER" "  Theme: ${theme}"
  textline "$BORDER" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "${BG}\e[K${RST}\n"
  textline "$PROMPT" "  > ${BG}${FG}Search query here"
  textline "$INFO" "  4/12"
  printf "${BG_SEL}${FG_SEL}  > main:1  zsh\e[K${RST}\n"
  textline "$FG" "    main:2  ${HL}nvim"
  textline "$FG" "    dev:1   node"
  textline "$FG" "    dev:2   ${HL}nvim"
  printf "${BG}\e[K${RST}\n"
  textline "$BORDER" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "${BG}\e[K${RST}\n"
  if [[ "$theme" == "$current" ]]; then
    textline "$GREEN" "  ● Current theme"
  else
    textline "$INFO" "  ○ Press enter to apply"
  fi
  # Fill remaining lines with background
  for _ in $(seq 1 20); do
    printf "${BG}\e[K${RST}\n"
  done
fi
