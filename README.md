# ClipboardHistory

**English** | [简体中文](README-zh.md)

A lightweight, open-source clipboard history app for macOS that keeps all data on your Mac.

> The current minimum requirement is macOS 15.6. The app does not upload clipboard contents or require Accessibility permission.

## Installation

1. Open the project's [Releases page](../../releases/latest).
2. Download the latest `ClipboardHistory-v*.dmg`.
3. Open the DMG and drag `ClipboardHistory` into Applications.
4. Launch the app. Its icon will appear in the menu bar.

If a release is marked as an "unnotarized test build," macOS may show a security warning. Public production releases should be signed with a Developer ID certificate and notarized by Apple.

## Usage

- Copy text, rich text, images, or files as usual. They are automatically added to your local history.
- Press `⇧⌘C` to show or hide the history panel. You can also pause recording from the menu bar menu.
- Enter a keyword to search content, filenames, or source applications. Searching a long history no longer blocks the UI.
- Finder images, videos, and common documents use Quick Look thumbnails when available; copying multiple files is preserved.
- Click a card to select it, or double-click it to copy the item using the default mode and close the panel.
- Text cards always show **Keep Formatting** and **Plain Text**, so the layout stays stable while using the mouse.
- Use the pin on each card for short-term priority, or the star for long-term favorites.
- Switch between **History** and **Favorites** inside the panel.
- After deleting an item, use the Undo button or `⌘Z` within 5 seconds to restore it.
- Preferences let you set the history limit, automatic deletion period, and whether clearing history also deletes database backups.
- Very large screenshots are downscaled and re-encoded instead of being dropped silently.

| Key | Action |
| --- | --- |
| `↑` / `↓` | Move the selection |
| `Enter` | Copy the selected item and close the panel |
| `Option + Enter` | Temporarily use the other text copy mode |
| `⌘1`–`⌘9` | Select one of the first nine items |
| `Delete` / `Backspace` | Delete the selected item |
| `⌘P` | Pin or unpin the selected item |
| `⇧⌘F` | Favorite or unfavorite the selected item |
| `⌘Z` | Undo deletion |
| `Esc` | Clear search; close the panel when the search field is empty |

Click the menu bar icon and choose **偏好设置…** (Preferences) to view all shortcuts and customize the panel, pin, favorite, and alternative-copy shortcuts. You can also change the default text copy mode, history limit, retention period, launch-at-login behavior, and privacy rules.

## Privacy

- All history data is stored locally with SwiftData.
- The app has no accounts, cloud sync, analytics SDKs, or network upload features.
- Clipboard contents marked confidential, transient, or auto-generated are skipped automatically; content from Apple Passwords and other known password managers is not recorded by default.
- You can clear all history (optionally together with database backups) or ignore specific apps in Preferences.
- Pinned and favorite items are excluded from automatic cleanup, but can still be deleted manually.
- Schema upgrades and database recovery keep up to 5 local backups that may contain old history content; they stay on this Mac.

See [PRIVACY.md](PRIVACY.md) for complete details.

## Building from source

You need macOS and Xcode 26 or later.

1. Open `ClipboardHistory.xcodeproj` in Xcode.
2. Wait for Swift Package Manager to fetch `KeyboardShortcuts` 3.0.1.
3. Select the `ClipboardHistory` scheme and `My Mac`.
4. Click Run.

To build from the command line:

```bash
xcodebuild \
  -project ClipboardHistory.xcodeproj \
  -scheme ClipboardHistory \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run the lightweight logic tests (no Xcode test target required; covers file payloads, search, history management, and undo/restore):

```bash
./scripts/run_logic_tests.sh
```

## Packaging a DMG

The project includes a reusable packaging script:

```bash
./scripts/package_dmg.sh 1.2.0
```

Without a Developer ID certificate, the script creates an ad-hoc signed DMG suitable only for local testing. For production signing and notarization instructions, see [docs/RELEASING.md](docs/RELEASING.md).

## License

This project is available under the [MIT License](LICENSE). The `KeyboardShortcuts` dependency is also licensed under the MIT License.
