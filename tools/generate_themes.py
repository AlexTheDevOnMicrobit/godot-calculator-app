#!/usr/bin/env python3
"""Generates assets/theme/dark_theme.tres and light_theme.tres.

Minimal, flat design: no borders or shadows, one accent color, quiet function
keys, digits slightly raised from the background. Both themes define the same
theme types; only the palette changes, so the app can switch at runtime.

Edit PALETTES, then run from the project root:  python3 tools/generate_themes.py
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "theme"

PALETTES = {
    "dark": {
        "bg": "#101216",
        "text": "#eef0f4", "muted": "#7f8796", "accent": "#ffb35c", "on_accent": "#1b1206",
        "surface": "#1b1e24", "surface_hover": "#23272f", "surface_pressed": "#15171c",
        "quiet": "#15181d", "quiet_hover": "#1d2027", "quiet_text": "#a7afbd",
        "operator": "#2a2219", "operator_hover": "#342a1e", "operator_text": "#ffb35c",
        "danger_text": "#ff8a94",
        "equals": "#ffb35c", "equals_hover": "#ffc27a", "equals_pressed": "#e89d45",
        "selected": "#ffb35c26", "hover": "#ffffff0d", "line": "#262a32",
        "panel": "#14171c", "popup": "#1d2027", "chip": "#1f2229", "chip_hover": "#272b33",
        "preview": "#6f7889", "error": "#ff7b86", "success": "#62d394",
    },
    "light": {
        "bg": "#f5f6f8",
        "text": "#14171c", "muted": "#6a7385", "accent": "#e07a00", "on_accent": "#ffffff",
        "surface": "#ffffff", "surface_hover": "#f7f8fa", "surface_pressed": "#eceef2",
        "quiet": "#eceef2", "quiet_hover": "#e4e7ec", "quiet_text": "#4a5366",
        "operator": "#fdebd6", "operator_hover": "#fbe0c0", "operator_text": "#c86a00",
        "danger_text": "#d23544",
        "equals": "#f08a12", "equals_hover": "#f59a32", "equals_pressed": "#d97a05",
        "selected": "#e07a0024", "hover": "#0000000a", "line": "#e2e5ea",
        "panel": "#ffffff", "popup": "#ffffff", "chip": "#eef0f3", "chip_hover": "#e4e7ec",
        "preview": "#8c94a4", "error": "#d23544", "success": "#1f9d55",
    },
}

RADIUS = 18


def color(hexs):
    hexs = hexs.lstrip("#")
    r, g, b = (int(hexs[i:i + 2], 16) / 255 for i in (0, 2, 4))
    a = int(hexs[6:8], 16) / 255 if len(hexs) == 8 else 1.0
    return f"Color({r:.4g}, {g:.4g}, {b:.4g}, {a:.4g})"


class ThemeWriter:
    def __init__(self):
        self.subs = []
        self.props = {}
        self.ext = {}
        self.count = 0

    def box(self, bg, radius=RADIUS, margins=(6, 4, 6, 4), border=None):
        self.count += 1
        name = f"StyleBoxFlat_{self.count}"
        lines = [f'[sub_resource type="StyleBoxFlat" id="{name}"]']
        for side, m in zip(("left", "top", "right", "bottom"), margins):
            lines.append(f"content_margin_{side} = {float(m)}")
        lines.append(f"bg_color = {color(bg)}")
        if border:
            for side in ("left", "top", "right", "bottom"):
                lines.append(f"border_width_{side} = 1")
            lines.append(f"border_color = {color(border)}")
        for corner in ("top_left", "top_right", "bottom_right", "bottom_left"):
            lines.append(f"corner_radius_{corner} = {radius}")
        lines.append("corner_detail = 8")
        lines.append("anti_aliasing = true")
        self.subs.append("\n".join(lines) + "\n")
        return f'SubResource("{name}")'

    def empty(self, margins=(0, 0, 0, 0)):
        self.count += 1
        name = f"StyleBoxEmpty_{self.count}"
        lines = [f'[sub_resource type="StyleBoxEmpty" id="{name}"]']
        for side, m in zip(("left", "top", "right", "bottom"), margins):
            if m:
                lines.append(f"content_margin_{side} = {float(m)}")
        self.subs.append("\n".join(lines) + "\n")
        return f'SubResource("{name}")'

    def texture(self, path):
        if path not in self.ext:
            self.ext[path] = f"{len(self.ext) + 3}_tex"
        return f'ExtResource("{self.ext[path]}")'

    def set(self, key, value):
        self.props[key] = value


def button(w, p, name, bg, hover, pressed, text, size, base="Button", radius=RADIUS,
           toggle=None, margins=(6, 4, 6, 4)):
    if base:
        w.set(f"{name}/base_type", f'&"{base}"')
    w.set(f"{name}/font_sizes/font_size", size)
    for state in ("font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
                  "font_hover_pressed_color", "icon_normal_color", "icon_hover_color",
                  "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"):
        w.set(f"{name}/colors/{state}", color(text))
    w.set(f"{name}/colors/font_disabled_color", color(p["muted"] + "66"))
    w.set(f"{name}/colors/icon_disabled_color", color(p["muted"] + "66"))
    make = (lambda c: w.box(c, radius, margins)) if bg else (lambda c: w.empty(margins))
    w.set(f"{name}/styles/normal", make(bg) if bg else w.empty(margins))
    w.set(f"{name}/styles/hover", w.box(hover, radius, margins))
    w.set(f"{name}/styles/pressed", w.box(pressed, radius, margins))
    w.set(f"{name}/styles/disabled", make(bg) if bg else w.empty(margins))
    w.set(f"{name}/styles/focus", w.empty())
    if toggle:
        tbg, tfg = toggle
        w.set(f"{name}/styles/pressed", w.box(tbg, radius, margins))
        w.set(f"{name}/styles/hover_pressed", w.box(tbg, radius, margins))
        for state in ("font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"):
            w.set(f"{name}/colors/{state}", color(tfg))


def build(kind):
    p = PALETTES[kind]
    w = ThemeWriter()
    w.set("default_font", 'ExtResource("1_regular")')
    w.set("default_font_size", 18)

    # Keypad
    button(w, p, "Button", p["quiet"], p["quiet_hover"], p["surface_pressed"], p["text"], 17, base=None)
    button(w, p, "DigitButton", p["surface"], p["surface_hover"], p["surface_pressed"], p["text"], 26)
    button(w, p, "FunctionButton", p["quiet"], p["quiet_hover"], p["surface_pressed"], p["quiet_text"], 19)
    button(w, p, "OperatorButton", p["operator"], p["operator_hover"], p["surface_pressed"], p["operator_text"], 28)
    button(w, p, "ClearButton", p["quiet"], p["quiet_hover"], p["surface_pressed"], p["danger_text"], 20)
    button(w, p, "EqualsButton", p["equals"], p["equals_hover"], p["equals_pressed"], p["on_accent"], 30)
    button(w, p, "ToggleButton", p["quiet"], p["quiet_hover"], p["surface_pressed"], p["accent"], 18,
           toggle=(p["accent"], p["on_accent"]))

    # Flat controls
    button(w, p, "IconButton", None, p["hover"], p["selected"], p["muted"], 18, radius=12,
           toggle=(p["selected"], p["accent"]), margins=(8, 8, 8, 8))
    button(w, p, "ModeButton", None, p["hover"], p["selected"], p["text"], 19, radius=12, margins=(10, 6, 10, 6))
    w.set("ModeButton/fonts/font", 'ExtResource("2_bold")')
    w.set("ModeButton/colors/icon_normal_color", color(p["muted"]))
    w.set("ModeButton/colors/icon_hover_color", color(p["muted"]))
    w.set("ModeButton/constants/h_separation", 6)
    button(w, p, "StatusButton", None, p["hover"], p["selected"], p["accent"], 13, radius=8, margins=(6, 2, 6, 2))
    button(w, p, "SegmentButton", p["chip"], p["chip_hover"], p["surface_pressed"], p["quiet_text"], 15, radius=12,
           toggle=(p["accent"], p["on_accent"]))
    button(w, p, "ChipButton", p["chip"], p["chip_hover"], p["surface_pressed"], p["text"], 14, radius=12)
    button(w, p, "ListButton", None, p["hover"], p["selected"], p["text"], 16, radius=12, margins=(4, 10, 4, 10))
    w.set("ListButton/colors/icon_normal_color", color(p["muted"]))
    w.set("ListButton/colors/icon_hover_color", color(p["muted"]))
    button(w, p, "BaseRowButton", None, p["hover"], p["selected"], p["muted"], 14, radius=8,
           toggle=(p["selected"], p["accent"]), margins=(8, 2, 8, 2))

    # OptionButton (language, converter units) and its popup menu
    button(w, p, "OptionButton", p["chip"], p["chip_hover"], p["surface_pressed"], p["text"], 15, base=None, radius=12,
           margins=(12, 6, 12, 6))
    w.set("OptionButton/constants/arrow_margin", 10)
    w.set("FlatOptionButton/base_type", '&"OptionButton"')
    w.set("FlatOptionButton/styles/normal", w.empty((0, 4, 0, 4)))
    w.set("FlatOptionButton/styles/hover", w.box(p["hover"], 10, (0, 4, 0, 4)))
    w.set("FlatOptionButton/styles/pressed", w.box(p["selected"], 10, (0, 4, 0, 4)))
    w.set("FlatOptionButton/colors/font_color", color(p["muted"]))
    w.set("FlatOptionButton/font_sizes/font_size", 15)
    w.set("PopupMenu/styles/panel", w.box(p["popup"], 14, (8, 8, 8, 8), border=p["line"]))
    w.set("PopupMenu/styles/hover", w.box(p["selected"], 10))
    w.set("PopupMenu/colors/font_color", color(p["text"]))
    w.set("PopupMenu/colors/font_hover_color", color(p["text"]))
    w.set("PopupMenu/colors/font_disabled_color", color(p["muted"]))
    w.set("PopupMenu/font_sizes/font_size", 17)
    w.set("PopupMenu/constants/v_separation", 14)
    w.set("PopupMenu/constants/h_separation", 12)
    w.set("PopupMenu/icons/radio_checked", w.texture(f"res://assets/icons/check_{kind}.svg"))
    w.set("PopupMenu/icons/radio_unchecked", w.texture("res://assets/icons/blank.svg"))

    # Switches (settings)
    w.set("CheckButton/icons/checked", w.texture(f"res://assets/icons/toggle_on_{kind}.svg"))
    w.set("CheckButton/icons/unchecked", w.texture(f"res://assets/icons/toggle_off_{kind}.svg"))
    w.set("CheckButton/icons/checked_mirrored", w.texture(f"res://assets/icons/toggle_on_{kind}.svg"))
    w.set("CheckButton/icons/unchecked_mirrored", w.texture(f"res://assets/icons/toggle_off_{kind}.svg"))
    for state in ("normal", "hover", "pressed", "hover_pressed", "focus", "disabled"):
        w.set(f"CheckButton/styles/{state}", w.empty((0, 8, 0, 8)))
    for state in ("font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"):
        w.set(f"CheckButton/colors/{state}", color(p["text"]))
    w.set("CheckButton/font_sizes/font_size", 16)

    # Panels
    w.set("PanelContainer/styles/panel", w.empty())
    w.set("BackgroundPanel/base_type", '&"PanelContainer"')
    w.set("BackgroundPanel/styles/panel", w.box(p["bg"], 0, (0, 0, 0, 0)))
    w.set("SheetPanel/base_type", '&"PanelContainer"')
    w.set("SheetPanel/styles/panel", w.box(p["panel"], 22, (0, 0, 0, 0)))
    w.set("HSeparator/styles/separator", w.box(p["line"], 0, (0, 0, 0, 0)))
    w.set("HSeparator/constants/separation", 1)

    # Labels
    w.set("Label/colors/font_color", color(p["text"]))
    for name, col, size in (("ResultLabel", p["text"], 52), ("StatusLabel", p["accent"], 13),
                            ("SectionLabel", p["muted"], 13), ("MutedLabel", p["muted"], 15),
                            ("HeaderLabel", p["text"], 22), ("TitleLabel", p["text"], 17),
                            ("ValueLabel", p["text"], 34)):
        w.set(f"{name}/base_type", '&"Label"')
        w.set(f"{name}/colors/font_color", color(col))
        w.set(f"{name}/font_sizes/font_size", size)
    for name in ("ResultLabel", "HeaderLabel", "TitleLabel", "ValueLabel"):
        w.set(f"{name}/fonts/font", 'ExtResource("2_bold")' if name != "ResultLabel" else 'ExtResource("1_regular")')

    # Custom app colors (read with get_theme_color(name, "App"))
    for name in ("preview", "error", "success", "accent", "muted", "text", "bg"):
        w.set(f"App/colors/{name}", color(p[name]))

    # ItemList (history)
    w.set("ItemList/font_sizes/font_size", 17)
    w.set("ItemList/colors/font_color", color(p["text"]))
    w.set("ItemList/colors/font_hovered_color", color(p["text"]))
    w.set("ItemList/colors/font_selected_color", color(p["text"]))
    w.set("ItemList/colors/guide_color", color(p["line"]))
    w.set("ItemList/constants/v_separation", 18)
    w.set("ItemList/constants/line_separation", 4)
    w.set("ItemList/styles/panel", w.empty())
    w.set("ItemList/styles/focus", w.empty())
    w.set("ItemList/styles/hovered", w.box(p["hover"], 10))
    w.set("ItemList/styles/selected", w.box(p["selected"], 10))
    w.set("ItemList/styles/selected_focus", w.box(p["selected"], 10))
    w.set("ItemList/styles/cursor", w.empty())
    w.set("ItemList/styles/cursor_unfocused", w.empty())

    # RichTextLabel (tests, help)
    w.set("RichTextLabel/colors/default_color", color(p["text"]))
    w.set("RichTextLabel/font_sizes/normal_font_size", 15)
    w.set("RichTextLabel/font_sizes/bold_font_size", 16)
    w.set("RichTextLabel/fonts/bold_font", 'ExtResource("2_bold")')
    w.set("RichTextLabel/constants/line_separation", 4)
    w.set("RichTextLabel/styles/normal", w.empty())

    # Scrollbars: thin, only the grabber
    for bar in ("VScrollBar", "HScrollBar"):
        w.set(f"{bar}/styles/scroll", w.empty((2, 2, 2, 2)))
        w.set(f"{bar}/styles/grabber", w.box(p["line"], 3, (2, 2, 2, 2)))
        w.set(f"{bar}/styles/grabber_highlight", w.box(p["muted"], 3, (2, 2, 2, 2)))
        w.set(f"{bar}/styles/grabber_pressed", w.box(p["accent"], 3, (2, 2, 2, 2)))

    # Tooltips
    w.set("TooltipPanel/styles/panel", w.box(p["popup"], 8, (10, 6, 10, 6), border=p["line"]))
    w.set("TooltipLabel/colors/font_color", color(p["text"]))
    w.set("TooltipLabel/font_sizes/font_size", 14)

    used = "\n".join(str(v) for v in w.props.values())
    subs = [s for s in w.subs if '"' + s.split('id="')[1].split('"')[0] + '"' in used]
    ext = ['[ext_resource type="FontFile" path="res://assets/fonts/DejaVuSans.ttf" id="1_regular"]',
           '[ext_resource type="FontFile" path="res://assets/fonts/DejaVuSans-Bold.ttf" id="2_bold"]']
    ext += [f'[ext_resource type="Texture2D" path="{path}" id="{rid}"]' for path, rid in w.ext.items()]
    text = f'[gd_resource type="Theme" load_steps={len(subs) + len(ext) + 1} format=3]\n\n'
    text += "\n".join(ext) + "\n\n" + "\n".join(subs) + "\n[resource]\n"
    text += "\n".join(f"{k} = {v}" for k, v in w.props.items()) + "\n"
    (OUT / f"{kind}_theme.tres").write_text(text)
    print("wrote", OUT / f"{kind}_theme.tres", len(subs), "sub-resources")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in PALETTES:
        build(kind)
