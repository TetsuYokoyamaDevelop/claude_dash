# Claude Dash

macOS desktop app for managing multiple [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI sessions in one window.

## Features

- **Tab-based sessions** - Run Claude Code CLI on multiple projects simultaneously
- **Permission notifications** - macOS notifications when Claude needs approval (Allow/Deny)
- **Attention badges** - Orange dot on tabs that need your input
- **Keyboard shortcuts** - Native macOS menu shortcuts for fast tab switching
- **Project persistence** - Projects are saved and restored on relaunch
- **Full terminal emulation** - Powered by xterm + flutter_pty with UTF-8 support

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+1` ~ `Cmd+9` | Switch to tab |
| `Cmd+Shift+]` | Next tab |
| `Cmd+Shift+[` | Previous tab |
| `Cmd+T` | Add project |
| `Cmd+W` | Close tab |

## Requirements

- macOS
- Flutter SDK (stable channel)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed (`npm install -g @anthropic-ai/claude-code`)

## Build & Run

```bash
git clone https://github.com/TetsuYokoyamaDevelop/claude_dash.git
cd claude_dash
flutter build macos
open build/macos/Build/Products/Release/claude_dash.app
```

Optionally copy to Applications:

```bash
cp -R build/macos/Build/Products/Release/claude_dash.app /Applications/Claude\ Dash.app
```

## Tech Stack

- **Framework**: Flutter (macOS desktop)
- **Terminal**: xterm + flutter_pty
- **Notifications**: local_notifier
- **Persistence**: shared_preferences
- **Native shortcuts**: NSMenuItem via MethodChannel

## License

MIT
