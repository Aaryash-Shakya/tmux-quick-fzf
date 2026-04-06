# Help Toggle Design

**Date:** 2026-04-06  
**Status:** Approved

## Problem

The fzf header line showing all shortcuts truncates on narrow terminals (visible as `ctrl-s: new ..`), making it unreliable as a shortcut reference.

## Solution

Replace the full shortcuts list in the header with a single universal hint: `?: toggle help`. All shortcuts are shown in the help preview panel, which the user can open with `?` and dismiss by typing or navigating.

## Changes

### `scripts/find-window.sh`

Change the `--header` option from:
```
enter: switch | ctrl-w: new window | ctrl-s: new session | ctrl-t: theme | ?: help
```
To:
```
?: toggle help
```

No changes to the `?` binding — it already uses `preview()` (not `change-preview()`), which is a one-shot overlay. Typing or changing selection naturally restores the normal preview. No temp files, rebinds, or new scripts needed.

### `scripts/.help`

Add a line at the top of the help output:
```
Press ? or start typing to close
```

This tells the user how to dismiss the help panel.

## Behavior

- On open: header shows `?: toggle help` only
- Press `?`: help panel appears in the preview area, normal preview is replaced
- Type anything or navigate to another item: fzf re-runs the original preview, help disappears
- The help panel itself states how to close it

## Non-goals

- No explicit close keybinding (start typing is sufficient)
- No header state change when help is open (universal label handles both states)
- No changes to what shortcuts are listed in `.help`
