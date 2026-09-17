# Tig Configuration Guide

Tig is a text-mode interface for Git with enhanced navigation and visualization capabilities.

## Quick Start

```bash
tig                    # Browse repository history
tig status             # View working directory status
tig blame <file>       # View file annotations
tig show <commit>      # Show specific commit
tig diff               # View working directory diff
```

## Navigation Keymaps

### Basic Movement

| Key                     | Action                     |
| ----------------------- | -------------------------- |
| `j`/`k`                 | Move down/up one line      |
| `<C-f>`/`<C-b>`         | Page down/up               |
| `<Space>`/`<Backspace>` | Page down/up (alternative) |
| `<PageDown>`/`<PageUp>` | Page down/up               |
| `g`/`G`                 | Go to first/last line      |
| `q`                     | Quit current view          |
| `Q`                     | Quit Tig                   |

### View Navigation

| Key | Action                        |
| --- | ----------------------------- |
| `m` | Switch to main (history) view |
| `s` | Switch to status view         |
| `c` | Switch to stage view          |
| `l` | Switch to log view            |
| `t` | Switch to tree view           |
| `f` | Switch to file view           |
| `d` | Switch to diff view           |
| `b` | Switch to blame view          |
| `h` | Show help                     |

## Text Selection & Copying

### Mouse Support

- **Text Selection**: Mouse disabled for normal terminal selection
- **Click and Drag**: Select any text in Tig output
- **Copy**: Use `Cmd+C` (macOS) or `Ctrl+C` (Linux) after selection
- **Mouse Wheel**: Scrolling still works

### Keyboard Selection

- **Terminal Selection**: Use your terminal's built-in text selection
- **Click and Drag**: Standard terminal selection works with mouse disabled
- **Keyboard**: Use terminal's keyboard selection shortcuts (varies by terminal)

### Quick Copy Commands

| Key | Action                          |
| --- | ------------------------------- |
| `y` | Copy commit hash to clipboard   |
| `Y` | Copy commit hash + subject line |
| `D` | Copy entire diff to clipboard   |

## Search & Find

| Key | Action              |
| --- | ------------------- |
| `/` | Search forward      |
| `?` | Search backward     |
| `n` | Find next match     |
| `N` | Find previous match |

## File Operations

| Key       | Action                                       |
| --------- | -------------------------------------------- |
| `e`       | Edit file in `$EDITOR` (from diff/tree view) |
| `<Enter>` | Open selected item                           |
| `<Tab>`   | Switch between staged/unstaged (status view) |

## Status View (Working Directory)

| Key | Action                |
| --- | --------------------- |
| `u` | Stage/unstage file    |
| `!` | Revert file changes   |
| `M` | Open merge tool       |
| `@` | Move to next chunk    |
| `C` | Commit staged changes |

## Diff View

| Key     | Action                   |
| ------- | ------------------------ |
| `[`/`]` | Move between chunks      |
| `{`/`}` | Move between files       |
| `@`     | Jump to next diff header |

## Configuration Features

### Enhanced Settings

- **Case-insensitive search**: Enabled by default
- **UTF-8 line graphics**: Better visual rendering
- **3 lines diff context**: More context in diffs
- **Line wrapping**: Long lines wrap instead of truncate

### Color Scheme

- **Gruvbox-inspired**: Dark theme with good contrast
- **Syntax highlighting**: Diffs, commits, and file types
- **Status indicators**: Clear visual hierarchy

## Tips & Tricks

1. **Quick commit info**: Hover over any commit to see details
2. **Branch visualization**: Main view shows git graph
3. **File history**: Use `tig <file>` to see file-specific history
4. **Blame navigation**: In blame view, press `<Enter>` on a commit to see full diff
5. **Multiple windows**: Use `:` commands to open multiple views
6. **Refresh**: Press `r` to refresh current view

## Environment Integration

- **Editor**: Uses `$EDITOR` environment variable (defaults to `nvim`)
- **Clipboard**: Uses `pbcopy` on macOS for clipboard operations
- **Terminal**: Works best with 256-color terminal support

## Common Workflows

### Review Changes Before Commit

```bash
tig status              # See what's changed
# Navigate to file, press 'e' to edit
# Press 'u' to stage/unstage files
# Press 'C' to commit
```

### Explore Project History

```bash
tig                     # Browse commits
# Press 'y' to copy commit hash
# Press 'Y' to copy commit + subject
# Press 'd' to see full diff
```

### Find Specific Changes

```bash
tig                     # Open main view
/search-term            # Search for commits
# Press 'n'/'N' to navigate results
```
