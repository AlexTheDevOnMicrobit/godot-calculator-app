# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/), versions: [SemVer](https://semver.org/).

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
