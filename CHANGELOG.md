# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/), versions: [SemVer](https://semver.org/).

## [1.0.0-beta.2] - 2026-10-14

### Added
- **Light theme** and **theme switch** (Auto / Dark / Light); Auto follows the
  system theme on Android, Windows and macOS. Themes are generated from a
  palette by `tools/generate_themes.py`.
- **Settings panel**: theme, language, angle unit, sounds, vibration, about.
- **Sounds** (key click, result, error) and **haptics** on mobile (`VIBRATE` permission).
- **On-screen tests**: the full test suite (105 checks) runs on the device,
  with a device report (OS, model, screen, renderer, GPU…).
- **Android export**: preset (arm64-v8a + armeabi-v7a), adaptive launcher icons,
  back button closes panels then quits, safe-area margins for notches.
- **Build workflow** (GitHub Actions): Android debug APK, Windows, Linux and Web
  builds as artifacts. Issue templates for beta feedback.
- **Smart input**: an operator replaces the previous one (`2+×` → `2×`), one
  decimal point per number, `.5` → `0.5`, `05` → `5`, `)` only with an open
  parenthesis, an operator typed first continues the last answer.
- Thousands separators in results (`1,234,567` / `1 234 567`).
- Wide layout: on large screens the history is docked next to the keypad.
- Visual refresh: gradient background, rounded buttons with shadows, press
  animation, display shake on error, SVG icons, bigger digits.

### Fixed
- The numeric keypad did nothing with **NumLock off** (it sent Home / arrows):
  it now always types digits (found while testing the Web build).
- `2 3` was silently computed as `6`: it is now a syntax error.
- Pressing `=` twice added the same calculation to the history twice.
- A plain number (`12 =`) no longer fills the history.
- Ctrl+C copied the error text: it now copies only a valid result.
- Live preview no longer flickers with `Rand`.
- Title no longer truncated on phones (short title in portrait).

### Changed
- Code split into `expression_editor.gd`, `settings.gd`, `feedback.gd` and
  `self_test.gd` (shared by CI and the on-screen tests).
- Low processor mode enabled (saves battery: the screen only redraws on change).

## [1.0.0-beta.1] - 2026-10-14

### Added
- First beta of the scientific calculator (Godot 4.3).
- Expression parser: operator precedence, parentheses (auto-closed), implicit
  multiplication, scientific notation, `Ans`, `π`, `e`, `rand`.
- Functions: sin/cos/tan and inverses, ln, log, eˣ, 10ˣ, x², x³, xʸ, √, ∛, x!,
  |x|, 1/x, mod, %.
- DEG / RAD angle modes, 2nd key, memory (MC / MR / M+ / M−).
- Live result preview, calculation history, error messages.
- French and English UI (CSV translations), decimal comma in French.
- Full keyboard and numeric keypad support, copy / paste.
- Persistent settings, memory and history (`user://settings.cfg`).
- Custom theme, DejaVu Sans font, app icon.
- Headless unit and UI tests, GitHub Actions CI, export presets.
