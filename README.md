# Godot Calculator 🧮

**Calculatrice scientifique faite avec Godot 4 — Scientific calculator built with Godot 4.**

![Godot 4.3](https://img.shields.io/badge/Godot-4.3-478cbf?logo=godotengine&logoColor=white)
![Version](https://img.shields.io/badge/version-1.0.0--beta.1-orange)
![License](https://img.shields.io/badge/license-Apache%202.0-blue)

🇫🇷 [Français](#-français) · 🇬🇧 [English](#-english)

---

## 🇫🇷 Français

Projet pour tester les fonctionnalités de Godot 4 (UI, thèmes, traductions,
entrées clavier, tweens, sauvegarde…) à travers une vraie application :
une calculatrice scientifique.

> ⚠️ **Version bêta** (`1.0.0-beta.1`) — objectif : une **v1.0** stable.

### Fonctionnalités

- Opérations de base `+ − × ÷`, parenthèses, priorité des opérateurs
- Fonctions scientifiques : `sin cos tan`, `sin⁻¹ cos⁻¹ tan⁻¹`, `ln log`, `eˣ 10ˣ`,
  `x² x³ xʸ`, `√ ∛`, `x!`, `|x|`, `1/x`, `mod`, `%`, notation scientifique `EXP`
- Constantes `π` et `e`, dernier résultat `Ans`, nombre aléatoire `Rand`
- Multiplication implicite : `2π`, `3(4+1)`, `2sin(30)`
- Degrés / radians (**DEG / RAD**)
- Touche **2nd** pour les fonctions secondes
- Mémoire **MC / MR / M+ / M−**
- **Aperçu du résultat en direct** pendant la saisie
- **Historique** des calculs (cliquer sur une ligne pour la réutiliser)
- **Français et anglais** (bouton FR/EN, virgule décimale en français)
- Préférences, mémoire et historique **sauvegardés** automatiquement
- Compatible **pavé numérique** et clavier complet
- Interface adaptée au mobile (portrait) et au bureau

### Lancer le projet

1. Installer [Godot 4.3](https://godotengine.org/download) (ou plus récent, version standard, pas .NET).
2. Cloner le dépôt ou télécharger le ZIP :
   ```bash
   git clone https://github.com/AlexTheDevOnMicrobit/godot-calculator-app.git
   ```
3. Dans le gestionnaire de projets Godot : **Importer** → choisir `project.godot`.
4. Appuyer sur **F5** (▶ Lancer le projet).

### Raccourcis clavier

| Touche | Action |
|---|---|
| `0`–`9`, `.` ou `,` | Chiffres, virgule (pavé numérique compris) |
| `+ - * /` (ou `x`, `:`) | Opérations |
| `^` `(` `)` `!` `%` | Puissance, parenthèses, factorielle, pourcentage |
| `Entrée` / `Entrée` pavé num. / `=` | Calculer |
| `Retour arrière` | Effacer le dernier élément |
| `Échap` / `Suppr` | Tout effacer (AC) |
| `S` `C` `T` | sin, cos, tan |
| `L` `G` `R` | ln, log, racine carrée |
| `P` `E` `A` | π, e, Ans |
| `Tab` | 2nd |
| `H` | Afficher / masquer l'historique |
| `F2` | DEG / RAD |
| `F3` | Changer de langue |
| `Ctrl+C` / `Ctrl+V` | Copier le résultat / coller une expression |

### Tests

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/test_runner.gd   # moteur de calcul
godot --headless --path . --script res://tests/test_ui.gd       # interface + clavier
```

Les tests tournent aussi automatiquement sur GitHub Actions.

### Exporter

Des préréglages d'export sont fournis (Windows, Linux, Web).
Installer d'abord les modèles d'export : **Éditeur → Gérer les modèles d'export**,
puis **Projet → Exporter…**

---

## 🇬🇧 English

A project to try out Godot 4 features (UI, themes, translations, keyboard
input, tweens, saving…) through a real app: a scientific calculator.

> ⚠️ **Beta version** (`1.0.0-beta.1`) — goal: a stable **v1.0**.

### Features

- Basic operations `+ − × ÷`, parentheses, operator precedence
- Scientific functions: `sin cos tan`, `sin⁻¹ cos⁻¹ tan⁻¹`, `ln log`, `eˣ 10ˣ`,
  `x² x³ xʸ`, `√ ∛`, `x!`, `|x|`, `1/x`, `mod`, `%`, scientific notation `EXP`
- Constants `π` and `e`, last answer `Ans`, random number `Rand`
- Implicit multiplication: `2π`, `3(4+1)`, `2sin(30)`
- Degrees / radians (**DEG / RAD**)
- **2nd** key for secondary functions
- Memory **MC / MR / M+ / M−**
- **Live result preview** while typing
- Calculation **history** (click a line to reuse it)
- **French and English** (FR/EN button, decimal comma in French)
- Settings, memory and history **saved** automatically
- **Numeric keypad** and full keyboard support
- Mobile-friendly (portrait) and desktop layout

### Running the project

1. Install [Godot 4.3](https://godotengine.org/download) (or newer, standard build, not .NET).
2. Clone the repository or download the ZIP:
   ```bash
   git clone https://github.com/AlexTheDevOnMicrobit/godot-calculator-app.git
   ```
3. In the Godot project manager: **Import** → select `project.godot`.
4. Press **F5** (▶ Run project).

### Keyboard shortcuts

| Key | Action |
|---|---|
| `0`–`9`, `.` or `,` | Digits, decimal point (numpad included) |
| `+ - * /` (or `x`, `:`) | Operators |
| `^` `(` `)` `!` `%` | Power, parentheses, factorial, percent |
| `Enter` / numpad `Enter` / `=` | Calculate |
| `Backspace` | Delete last item |
| `Esc` / `Delete` | Clear all (AC) |
| `S` `C` `T` | sin, cos, tan |
| `L` `G` `R` | ln, log, square root |
| `P` `E` `A` | π, e, Ans |
| `Tab` | 2nd |
| `H` | Show / hide history |
| `F2` | DEG / RAD |
| `F3` | Switch language |
| `Ctrl+C` / `Ctrl+V` | Copy result / paste an expression |

### Tests

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/test_runner.gd   # math engine
godot --headless --path . --script res://tests/test_ui.gd       # UI + keyboard
```

Tests also run automatically on GitHub Actions.

### Exporting

Export presets are included (Windows, Linux, Web). Install the export
templates first: **Editor → Manage Export Templates**, then **Project → Export…**

---

## 📁 Structure

```
godot-calculator-app/
├── project.godot                  # Project settings (window, theme, locales)
├── icon.svg                       # App icon
├── export_presets.cfg             # Windows / Linux / Web export presets
├── scenes/
│   └── main.tscn                  # Main screen (display, keypad, history)
├── scripts/
│   ├── main.gd                    # UI logic, keyboard/numpad, memory, history, settings
│   └── evaluator.gd               # Expression parser & math engine
├── assets/
│   ├── fonts/                     # DejaVu Sans (math symbol coverage) + license
│   └── theme/calculator_theme.tres  # Theme with button type variations
├── translations/
│   └── translations.csv           # FR / EN strings (imported by Godot)
├── tests/
│   ├── test_runner.gd             # Evaluator unit tests
│   └── test_ui.gd                 # UI integration tests
└── .github/workflows/tests.yml    # CI
```

## 🗺️ Roadmap → v1.0

- [x] Scientific calculator core (beta)
- [x] FR / EN, numpad, history, memory
- [ ] Feedback from beta testing / bug fixes
- [ ] Light theme / theme switch
- [ ] Android export & on-screen tests
- [ ] Sounds / haptics (optional)
- [ ] v1.0 release

## 📄 License

Code: [Apache 2.0](LICENSE). Font: DejaVu Sans — see
[`assets/fonts/LICENSE-DejaVu.txt`](assets/fonts/LICENSE-DejaVu.txt).
