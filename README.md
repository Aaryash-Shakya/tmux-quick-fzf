# tmux-quick-fzf

Fast fuzzy finder for tmux windows. Search across all sessions and windows, switch instantly, or create new ones — all from a single fzf prompt.

## Features

- Fuzzy search across all sessions and windows
- Live pane content preview
- Create new windows or sessions directly from the search prompt
- Popup window (tmux >= 3.2) with split-pane fallback for older versions
- Progressive fzf enhancements (borders, ghost text) for newer fzf versions
- Fully configurable via environment variables

## Requirements

- [tmux](https://github.com/tmux/tmux) >= 2.1 (popup requires >= 3.2)
- [fzf](https://github.com/junegunn/fzf)

## Installation

### With TPM (recommended)

Add to your `~/.tmux.conf`:

```tmux
set -g @plugin 'aaryash/tmux-quick-fzf'
```

Then press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/aaryash/tmux-quick-fzf ~/.tmux/plugins/tmux-quick-fzf
```

Add to your `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-quick-fzf/main.tmux
```

Then reload tmux: `tmux source-file ~/.tmux.conf`

## Usage

Press `prefix + f` to open the fuzzy finder.

### Key Bindings (inside fzf)

| Key | Action |
|---|---|
| `Enter` | Switch to selected window |
| `ctrl-w` | Create new window (named after your search query) |
| `ctrl-s` | Create new session (named after your search query) |
| `Escape` | Cancel |

The search matches against both **session names** and **window names**. The current window is marked with `*`.

## Configuration

All options are set via environment variables. Add them to your `~/.tmux.conf`:

```tmux
# Change the launch key (default: f)
set-environment -g TMUX_QUICK_FZF_KEY "f"

# Custom window display format (default: #S:#I: #W)
set-environment -g TMUX_QUICK_FZF_WINDOW_FORMAT "#S:#I: #W"

# Custom fzf-tmux layout options
set-environment -g TMUX_QUICK_FZF_OPTIONS "-p -w 70% -h 50%"

# Disable preview (default: 1)
set-environment -g TMUX_QUICK_FZF_PREVIEW "0"
```

Or export them in your shell profile:

```bash
export TMUX_QUICK_FZF_KEY="f"
```

### Options Reference

| Variable | Default | Description |
|---|---|---|
| `TMUX_QUICK_FZF_KEY` | `f` | Key binding (used with prefix) |
| `TMUX_QUICK_FZF_WINDOW_FORMAT` | `#S:#I: #W` | tmux format string for window display |
| `TMUX_QUICK_FZF_OPTIONS` | auto-detected | fzf-tmux layout flags |
| `TMUX_QUICK_FZF_PREVIEW` | `1` | Enable (`1`) or disable (`0`) pane preview |

### Window Format

The `TMUX_QUICK_FZF_WINDOW_FORMAT` variable accepts any tmux `FORMAT` string. Some useful variables:

| Variable | Description |
|---|---|
| `#S` | Session name |
| `#I` | Window index |
| `#W` | Window name |
| `#F` | Window flags |
| `#P` | Pane index |
| `#{pane_current_command}` | Current command in pane |
| `#{pane_current_path}` | Current path in pane |

Example — show window name and current command:

```tmux
set-environment -g TMUX_QUICK_FZF_WINDOW_FORMAT "#S:#I: #W [#{pane_current_command}]"
```

## License

MIT
