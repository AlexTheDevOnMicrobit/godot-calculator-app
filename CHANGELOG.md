# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/), versions: [SemVer](https://semver.org/).

## [1.0.0-beta.4] - 2026-10-14

### Changed — minimal redesign
- New flat design: no cards, borders or shadows, one accent color, quiet
  function keys, digits slightly raised, larger result.
- Top bar reduced to the **mode name** (tap → mode menu), **history** and
  **settings**. The mode bar, title, theme button, book button and the `TeX`
  tag are gone.
- **Tap the display** for Copy / Copy as LaTeX / Paste. `DEG` / `RAD` is a small
  tappable label in the display.
- Scientific keypad: 7 rows instead of 8, no hint texts; memory moved to the
  f(x) panel, `S⇔D` became `⇄`, `±` / `x!` / `EXP` / `%` are 2nd functions.
- **Settings** gather every non-math option: theme (Auto / Light / Dark),
  language, angle unit, decimal places, sound and vibration switches, and links
  to **Basic knowledge**, the new **Help** page and the **on-screen tests**.
- History: trash icon instead of a text button. Converter: dropdowns without
  captions, bigger values, swap icon.

### Added
- **Landscape layout** (display on the left, keypad on the right), screen
  orientation follows the device; keys scale their labels with their size.
- **Help** page: how modes, templates, 2nd functions, the display and the
  panels work, and the keyboard shortcuts.
- **Languages**: Spanish, German, Italian and Portuguese (with English and
  French): 270 texts each, including help, units and the knowledge page.
  Decimal comma and thin-space grouping for all languages except English.
  Localized app name. A *Translations* test checks that nothing is missing.
- **Platforms**: installable **web app (PWA)** with icons and offline page,
  **macOS** preset, Windows icon (`.ico`, `tools/make_ico.py`) and file
  metadata, Android version 1.0.0-beta.4. Workflows: GitHub **Release** with all
  builds on `v*` tags, **GitHub Pages** deployment of the web app, optional
  **signed Android release** from repository secrets.

### Fixed
- The display kept its extra height after a tall fraction.
- In Programmer mode, scientific keyboard shortcuts (`s` → sin…) were inserted.
- `build/` exports were imported by Godot and could end up in later exports
  (`build/.gdignore` + export filter).
- Settings are also saved when the app loses focus (web tab closed, app switched).

### Performance
- Keypads and the functions / settings / help / knowledge pages are built on
  first use: 76 nodes at startup instead of 626 (≈ 330 ms less work at launch).
- Caret blink timers only run for views that show a caret.
- Physics ticks lowered to 30/s (the app uses no physics).
- About 0.25 ms to refresh the display after a key press.

## [1.0.0-beta.3] - 2026-10-14

### Added
- **Four modes** with their own keypad: **Basic**, **Scientific**, **Programmer**
  (64-bit integers, HEX / DEC / OCT / BIN side by side, AND / OR / XOR / NOT,
  shifts, mod) and **Converter** (11 unit categories, FR / EN unit names).
  Switch with the mode bar, `Ctrl+1…4` or `F7`; the mode is remembered.
- **Textbook display** (`math_view.gd`): stacked fractions, radicals with a bar
  over the radicand and an index for ⁿ√x, raised exponents, delimiters that grow
  with their content, placeholders for empty slots and a blinking caret.
- **Smart templates**: `a⁄b`, `ⁿ√x`, `xʸ`, `log_b`, `nCr`… are filled slot by
  slot with the new **→** key (or the Right arrow).
- **LaTeX**: copy the calculation as LaTeX (`TeX` button, `Ctrl+Shift+C`) and
  paste LaTeX (`\frac`, `\sqrt[n]`, `^{}`, `\binom`, `\log_b`, `\left|...\right|`…)
  to compute it.
- **S⇔D**: show the result as a fraction or a decimal.
- New functions: `frac`, `root` (ⁿ√x), `logb`, `nCr`, `nPr`, `gcd`, `lcm`, `round`,
  `floor`, `ceil`, `asinh`, `acosh`, `atanh`, `randint`, golden ratio `φ`.
- **f(x) panel** listing every function by category.
- **Basic knowledge** page (book icon, `K` or `F8`): perfect squares and cubes,
  prime numbers under 200, π (50 decimals and a mnemonic), constants, powers of 2,
  factorials, exact trigonometric values, algebra and geometry formulas drawn in
  textbook form, divisibility rules and unit prefixes, in English and French.
  Tapping a number inserts it into the calculation. Built on first use only.
- **±** key, `%` and `EXP` as 2nd functions; 2nd functions shown as small hints on the keys.
- **Decimal places** setting (Auto, 2, 4, 6, 8).
- Readable history (`³√27 + 3⁄4 = 3.75`, `log₂(8)`, `2³`).
- On-screen tests: 282 checks (new sections: functions, fractions, LaTeX,
  programmer, converter, knowledge) with timing and memory usage.

### Fixed
- Letters glued to a function were rejected (`esin(90)`, `2πe`): identifiers are
  now split into known words.
- `2` then `a⁄b` read like the mixed number 2½ but computed 2 × ½: a `×` is now
  inserted so the display matches the result.
- Pressing `=` with an unfinished template now closes it before evaluating.
- The README screenshots were imported as game resources (`docs/.gdignore`).

### Optimized
- Fonts rendered with **MSDF**: one glyph atlas for every size (the result and
  the math view auto-fit their font size), crisp text when keys are animated.
- Keypads are built once per mode and only shown / hidden when switching.
- Settings are saved with a short debounce (and on pause / close) instead of on
  every key press.
- History updates incrementally instead of rebuilding the list.
- Live preview cached; result auto-fit uses a binary search on the font size.
- Builds exclude `docs/`, `tools/`, tests and source SVGs.

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
