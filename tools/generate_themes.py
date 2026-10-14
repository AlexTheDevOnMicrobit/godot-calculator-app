#!/usr/bin/env python3
"""Generates assets/theme/dark_theme.tres and light_theme.tres.

Both themes define the same theme types, only the palette changes, so the app
can switch between them at runtime. Edit the PALETTES below, then run from
the project root:  python3 tools/generate_themes.py
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "theme"

PALETTES = {
    "dark": {
        "bg_top": "#151a24", "bg_bottom": "#0b0e14",
        "text": "#eef1f6", "muted": "#8b96aa", "accent": "#ffc46b", "on_accent": "#1a1206",
        "display": "#080a0f", "display_border": "#222a38",
        "card": "#141924", "card_border": "#232b3a",
        "digit": ("#1f2532", "#283042", "#171c27", "#eef1f6"),
        "function": ("#161b25", "#1e2532", "#11151d", "#a9b4c8"),
        "operator": ("#243152", "#2d3d66", "#1c2742", "#9cc0ff"),
        "memory": ("#161b25", "#1e2532", "#11151d", "#7fd6c2"),
        "clear": ("#3a1d25", "#4a2530", "#2e171d", "#ff8a96"),
        "equals": ("#ff9f43", "#ffb066", "#e8892c", "#1a1206"),
        "toggle": ("#161b25", "#1e2532", "#11151d", "#ffc46b"),
        "segment": ("#1f2532", "#283042", "#171c27", "#c9d1df"),
        "icon": ("#00000000", "#ffffff14", "#ffffff22", "#c9d1df"),
        "shadow": "#00000066",
        "preview": "#6f7a8e", "error": "#ff6b78", "success": "#5fd38d",
        "selection": "#ffc46b33",
    },
    "light": {
        "bg_top": "#f4f6fa", "bg_bottom": "#e2e7ef",
        "text": "#1d2330", "muted": "#677288", "accent": "#b86e00", "on_accent": "#1a1206",
        "display": "#ffffff", "display_border": "#d5dbe6",
        "card": "#ffffff", "card_border": "#d5dbe6",
        "digit": ("#ffffff", "#f5f7fb", "#e7ebf2", "#1d2330"),
        "function": ("#e6eaf2", "#dce2ec", "#d0d7e3", "#3e4a60"),
        "operator": ("#dce7ff", "#cddcff", "#bccffa", "#2457d6"),
        "memory": ("#e6eaf2", "#dce2ec", "#d0d7e3", "#0f7a64"),
        "clear": ("#ffe3e6", "#ffd4d9", "#ffc4cb", "#c62839"),
        "equals": ("#ff8c1a", "#ff9d3d", "#ea7a0a", "#ffffff"),
        "toggle": ("#e6eaf2", "#dce2ec", "#d0d7e3", "#b86e00"),
        "segment": ("#e6eaf2", "#dce2ec", "#d0d7e3", "#3e4a60"),
        "icon": ("#00000000", "#0000000f", "#0000001c", "#3e4a60"),
        "shadow": "#1d233022",
        "preview": "#8a94a6", "error": "#d93040", "success": "#1f9d55",
        "selection": "#ffb34040",
    },
}

TOGGLE_PRESSED = {"dark": ("#ffc46b", "#1a1206"), "light": ("#ffb340", "#1a1206")}


def color(hexs):
    hexs = hexs.lstrip("#")
    r, g, b = (int(hexs[i:i + 2], 16) / 255 for i in (0, 2, 4))
    a = int(hexs[6:8], 16) / 255 if len(hexs) == 8 else 1.0
    return f"Color({r:.4g}, {g:.4g}, {b:.4g}, {a:.4g})"


class ThemeWriter:
    def __init__(self):
        self.subs = []
        self.props = []
        self.count = 0

    def box(self, bg, radius=14, border=None, border_width=1, shadow=None, shadow_size=0,
            margins=(6, 6, 6, 6), shadow_offset=(0, 2)):
        self.count += 1
        name = f"StyleBoxFlat_{self.count}"
        lines = [f'[sub_resource type="StyleBoxFlat" id="{name}"]']
        for side, m in zip(("left", "top", "right", "bottom"), margins):
            lines.append(f"content_margin_{side} = {float(m)}")
        lines.append(f"bg_color = {color(bg)}")
        if border:
            for side in ("left", "top", "right", "bottom"):
                lines.append(f"border_width_{side} = {border_width}")
            lines.append(f"border_color = {color(border)}")
        for corner in ("top_left", "top_right", "bottom_right", "bottom_left"):
            lines.append(f"corner_radius_{corner} = {radius}")
        lines.append("corner_detail = 8")
        if shadow and shadow_size:
            lines.append(f"shadow_color = {color(shadow)}")
            lines.append(f"shadow_size = {shadow_size}")
            lines.append(f"shadow_offset = Vector2({shadow_offset[0]}, {shadow_offset[1]})")
        lines.append("anti_aliasing = true")
        self.subs.append("\n".join(lines) + "\n")
        return f'SubResource("{name}")'

    def gradient_box(self, top, bottom):
        self.count += 1
        g, t, s = (f"Gradient_{self.count}", f"GradientTexture2D_{self.count}", f"StyleBoxTexture_{self.count}")
        self.subs.append(f'[sub_resource type="Gradient" id="{g}"]\n'
                         f'colors = PackedColorArray({color(top)[6:-1]}, {color(bottom)[6:-1]})\n')
        self.subs.append(f'[sub_resource type="GradientTexture2D" id="{t}"]\n'
                         f'gradient = SubResource("{g}")\nwidth = 16\nheight = 256\n'
                         f'fill_from = Vector2(0, 0)\nfill_to = Vector2(0, 1)\n')
        self.subs.append(f'[sub_resource type="StyleBoxTexture" id="{s}"]\ntexture = SubResource("{t}")\n')
        return f'SubResource("{s}")'

    def empty(self):
        self.count += 1
        name = f"StyleBoxEmpty_{self.count}"
        self.subs.append(f'[sub_resource type="StyleBoxEmpty" id="{name}"]\n')
        return f'SubResource("{name}")'

    def set(self, key, value):
        self.props.append(f"{key} = {value}")


def button_type(w, p, name, colors, font_size, base="Button", radius=16, shadow=True, toggle=None):
    normal, hover, pressed, text = colors
    sh = p["shadow"] if shadow else None
    if base:
        w.set(f"{name}/base_type", f'&"{base}"')
    w.set(f"{name}/font_sizes/font_size", font_size)
    for state in ("font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"):
        w.set(f"{name}/colors/{state}", color(text))
    w.set(f"{name}/colors/font_disabled_color", color(p["muted"]))
    for state in ("icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"):
        w.set(f"{name}/colors/{state}", color(text))
    w.set(f"{name}/styles/normal", w.box(normal, radius, shadow=sh, shadow_size=3))
    w.set(f"{name}/styles/hover", w.box(hover, radius, shadow=sh, shadow_size=4))
    w.set(f"{name}/styles/pressed", w.box(pressed, radius, margins=(6, 8, 6, 4)))
    w.set(f"{name}/styles/disabled", w.box(normal, radius))
    w.set(f"{name}/styles/focus", w.empty())
    if toggle:
        bg, fg = toggle
        w.set(f"{name}/styles/pressed", w.box(bg, radius, shadow=sh, shadow_size=3))
        w.set(f"{name}/styles/hover_pressed", w.box(bg, radius, shadow=sh, shadow_size=4))
        for state in ("font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"):
            w.set(f"{name}/colors/{state}", color(fg))


def build(kind):
    p = PALETTES[kind]
    w = ThemeWriter()
    w.set("default_font", 'ExtResource("1_regular")')
    w.set("default_font_size", 20)

    button_type(w, p, "Button", p["function"], 18, base=None)
    button_type(w, p, "DigitButton", p["digit"], 26)
    button_type(w, p, "OperatorButton", p["operator"], 28)
    button_type(w, p, "FunctionButton", p["function"], 19)
    button_type(w, p, "MemoryButton", p["memory"], 17)
    button_type(w, p, "ClearButton", p["clear"], 21)
    button_type(w, p, "EqualsButton", p["equals"], 30)
    button_type(w, p, "ToggleButton", p["toggle"], 18, toggle=TOGGLE_PRESSED[kind])
    button_type(w, p, "SegmentButton", p["segment"], 16, radius=10, shadow=False, toggle=TOGGLE_PRESSED[kind])
    button_type(w, p, "ChipButton", p["toggle"], 15, radius=10, shadow=False)
    # Flat icon button (top bar)
    normal, hover, pressed, fg = p["icon"]
    button_type(w, p, "IconButton", (normal, hover, pressed, fg), 22, radius=12, shadow=False,
                toggle=(p["selection"], p["accent"]))
    w.set("IconButton/constants/icon_max_width", 22)

    # Panels
    w.set("PanelContainer/styles/panel", w.empty())
    w.set("BackgroundPanel/base_type", '&"PanelContainer"')
    w.set("BackgroundPanel/styles/panel", w.gradient_box(p["bg_top"], p["bg_bottom"]))
    w.set("DisplayPanel/base_type", '&"PanelContainer"')
    w.set("DisplayPanel/styles/panel", w.box(p["display"], 20, border=p["display_border"],
                                             shadow=p["shadow"], shadow_size=6, shadow_offset=(0, 3)))
    w.set("CardPanel/base_type", '&"PanelContainer"')
    w.set("CardPanel/styles/panel", w.box(p["card"], 18, border=p["card_border"],
                                          shadow=p["shadow"], shadow_size=4))

    # Labels
    w.set("Label/colors/font_color", color(p["text"]))
    for name, col, size in (("TitleLabel", p["text"], 17), ("ExpressionLabel", p["muted"], 22),
                            ("ResultLabel", p["text"], 48), ("StatusLabel", p["accent"], 13),
                            ("SectionLabel", p["muted"], 14), ("MutedLabel", p["muted"], 15),
                            ("HeaderLabel", p["text"], 20)):
        w.set(f"{name}/base_type", '&"Label"')
        w.set(f"{name}/colors/font_color", color(col))
        w.set(f"{name}/font_sizes/font_size", size)
    w.set("ResultLabel/fonts/font", 'ExtResource("2_bold")')
    w.set("HeaderLabel/fonts/font", 'ExtResource("2_bold")')
    w.set("TitleLabel/fonts/font", 'ExtResource("2_bold")')

    # Custom app colors (read with get_theme_color(name, "App"))
    for name in ("preview", "error", "success", "accent", "muted", "text", "bg_bottom"):
        w.set(f"App/colors/{name}", color(p[name]))

    # ItemList (history)
    w.set("ItemList/font_sizes/font_size", 17)
    w.set("ItemList/colors/font_color", color(p["text"]))
    w.set("ItemList/colors/font_hovered_color", color(p["text"]))
    w.set("ItemList/colors/font_selected_color", color(p["text"]))
    w.set("ItemList/colors/guide_color", color(p["card_border"]))
    w.set("ItemList/constants/v_separation", 14)
    w.set("ItemList/constants/line_separation", 4)
    w.set("ItemList/styles/panel", w.empty())
    w.set("ItemList/styles/focus", w.empty())
    w.set("ItemList/styles/hovered", w.box(p["selection"], 10))
    w.set("ItemList/styles/selected", w.box(p["selection"], 10))
    w.set("ItemList/styles/selected_focus", w.box(p["selection"], 10))
    w.set("ItemList/styles/cursor", w.empty())
    w.set("ItemList/styles/cursor_unfocused", w.empty())

    # RichTextLabel (self-test report)
    w.set("RichTextLabel/colors/default_color", color(p["text"]))
    w.set("RichTextLabel/font_sizes/normal_font_size", 15)
    w.set("RichTextLabel/font_sizes/bold_font_size", 15)
    w.set("RichTextLabel/fonts/bold_font", 'ExtResource("2_bold")')
    w.set("RichTextLabel/styles/normal", w.empty())

    # Scrollbars
    for bar in ("VScrollBar", "HScrollBar"):
        w.set(f"{bar}/styles/scroll", w.box(p["bg_bottom"] + "00", 4, margins=(2, 2, 2, 2)))
        w.set(f"{bar}/styles/grabber", w.box(p["card_border"], 4, margins=(3, 3, 3, 3)))
        w.set(f"{bar}/styles/grabber_highlight", w.box(p["muted"], 4, margins=(3, 3, 3, 3)))
        w.set(f"{bar}/styles/grabber_pressed", w.box(p["accent"], 4, margins=(3, 3, 3, 3)))

    # Tooltips
    w.set("TooltipPanel/styles/panel", w.box(p["card"], 8, border=p["card_border"], margins=(10, 6, 10, 6)))
    w.set("TooltipLabel/colors/font_color", color(p["text"]))
    w.set("TooltipLabel/font_sizes/font_size", 14)

    header = [f'[gd_resource type="Theme" load_steps={len(w.subs) + 3} format=3]', "",
              '[ext_resource type="FontFile" path="res://assets/fonts/DejaVuSans.ttf" id="1_regular"]',
              '[ext_resource type="FontFile" path="res://assets/fonts/DejaVuSans-Bold.ttf" id="2_bold"]', ""]
    # Later assignments override earlier ones (toggle pressed styles)
    final = {}
    for prop in w.props:
        key, value = prop.split(" = ", 1)
        final[key] = value
    used = "\n".join(final.values())
    subs = [s for s in w.subs if '"' + s.split('id="')[1].split('"')[0] + '"' in used or "Gradient" in s]
    header[0] = f'[gd_resource type="Theme" load_steps={len(subs) + 3} format=3]'
    body = [f"{k} = {v}" for k, v in final.items()]
    text = "\n".join(header) + "\n".join(s + "\n" for s in subs) + "[resource]\n" + "\n".join(body) + "\n"
    (OUT / f"{kind}_theme.tres").write_text(text)
    print("wrote", OUT / f"{kind}_theme.tres", len(subs), "sub-resources")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in PALETTES:
        build(kind)
