#!/usr/bin/env python3
"""
Gera os ícones oficiais do Command para Windows, Android, Flutter assets e Web.
Cores e estilo: Amethyst Command (DESIGN.md)
- Background / Shell: #13101B
- Surface: #1E1829
- Border: #A78BFA (Amethyst) / #352B45
- Accent: #C4B5FD (Lavender) / #7C3AED (Deep Violet)
"""

import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


def _gradient_layer(size, mask, top, bottom):
    ramp = Image.linear_gradient('L').resize(size, Image.Resampling.BICUBIC)
    layer = ImageOps.colorize(ramp, top, bottom).convert('RGBA')
    layer.putalpha(mask)
    return layer


def _masked_color(mask, color):
    layer = Image.new('RGBA', mask.size, color)
    layer.putalpha(mask)
    return layer


def create_command_logo(size=1024):
    """Premium Command icon with a raised amethyst shell and glyph."""
    scale = 2
    canvas_size = size * scale
    img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    pad = 72 * scale
    radius = 210 * scale
    outer_box = [pad, pad, canvas_size - pad, canvas_size - pad]

    shadow_mask = Image.new('L', (canvas_size, canvas_size), 0)
    ImageDraw.Draw(shadow_mask).rounded_rectangle(
        [pad, pad + 12 * scale, canvas_size - pad, canvas_size - pad + 12 * scale],
        radius=radius,
        fill=190,
    )
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(20 * scale))
    img.alpha_composite(_masked_color(shadow_mask, (5, 3, 13, 0)))

    glow_mask = Image.new('L', (canvas_size, canvas_size), 0)
    ImageDraw.Draw(glow_mask).rounded_rectangle(outer_box, radius=radius, fill=75)
    glow_mask = glow_mask.filter(ImageFilter.GaussianBlur(16 * scale))
    img.alpha_composite(_masked_color(glow_mask, (124, 58, 237, 0)))

    shell_mask = Image.new('L', (canvas_size, canvas_size), 0)
    ImageDraw.Draw(shell_mask).rounded_rectangle(outer_box, radius=radius, fill=255)
    img.alpha_composite(_gradient_layer((canvas_size, canvas_size), shell_mask, '#E0D2FF', '#7138D5'))

    inner_pad = pad + 20 * scale
    inner_box = [inner_pad, inner_pad, canvas_size - inner_pad, canvas_size - inner_pad]
    inner_radius = radius - 18 * scale
    inner_mask = Image.new('L', (canvas_size, canvas_size), 0)
    ImageDraw.Draw(inner_mask).rounded_rectangle(inner_box, radius=inner_radius, fill=255)
    img.alpha_composite(_gradient_layer((canvas_size, canvas_size), inner_mask, '#211A30', '#110E19'))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(inner_box, radius=inner_radius, outline=(74, 57, 101, 230), width=3 * scale)
    draw.rounded_rectangle(
        [inner_pad + 6 * scale, inner_pad + 6 * scale, canvas_size - inner_pad - 6 * scale, canvas_size - inner_pad - 6 * scale],
        radius=radius - 24 * scale,
        outline=(210, 196, 245, 48),
        width=2 * scale,
    )

    bar_y = pad + 145 * scale
    bar_start = inner_pad + 24 * scale
    bar_end = canvas_size - inner_pad - 24 * scale
    draw.line([(bar_start, bar_y + 5 * scale), (bar_end, bar_y + 5 * scale)], fill=(7, 5, 13, 180), width=9 * scale)
    draw.line([(bar_start, bar_y), (bar_end, bar_y)], fill=(53, 43, 69, 255), width=5 * scale)
    draw.line([(bar_start, bar_y - 2 * scale), (bar_end, bar_y - 2 * scale)], fill=(196, 181, 253, 75), width=2 * scale)

    dot_y = pad + 85 * scale
    dot_r = 14 * scale
    dot_colors = ((124, 58, 237, 255), (167, 139, 250, 255), (196, 181, 253, 255))
    for index, color in enumerate(dot_colors):
        dot_x = inner_pad + (48 + 48 * index) * scale
        dot_box = [dot_x, dot_y - dot_r, dot_x + dot_r * 2, dot_y + dot_r]
        draw.ellipse([dot_x + 2 * scale, dot_y - dot_r + 5 * scale, dot_x + dot_r * 2 + 2 * scale, dot_y + dot_r + 5 * scale], fill=(7, 5, 13, 150))
        draw.ellipse(dot_box, fill=color)
        draw.ellipse([dot_x + 4 * scale, dot_y - dot_r + 4 * scale, dot_x + 12 * scale, dot_y - dot_r + 12 * scale], fill=(255, 250, 255, 175))

    chevron_pts = [(310 * scale, 400 * scale), (475 * scale, 565 * scale), (310 * scale, 730 * scale)]
    chevron_mask = Image.new('L', (canvas_size, canvas_size), 0)
    ImageDraw.Draw(chevron_mask).line(chevron_pts, fill=255, width=64 * scale, joint='curve')
    chevron_shadow = ImageChops.offset(chevron_mask, 14 * scale, 17 * scale).filter(ImageFilter.GaussianBlur(10 * scale))
    img.alpha_composite(_masked_color(chevron_shadow, (5, 3, 13, 0)))
    img.alpha_composite(_masked_color(ImageChops.offset(chevron_mask, 6 * scale, 8 * scale), (91, 51, 158, 255)))
    img.alpha_composite(_gradient_layer((canvas_size, canvas_size), chevron_mask, '#E0D2FF', '#8B63E5'))
    chevron_highlight = Image.new('L', (canvas_size, canvas_size), 0)
    ImageDraw.Draw(chevron_highlight).line(chevron_pts, fill=255, width=5 * scale, joint='curve')
    img.alpha_composite(_masked_color(ImageChops.offset(chevron_highlight, -4 * scale, -5 * scale), (255, 250, 255, 155)))

    cursor_y = 730 * scale
    cursor_box = [545 * scale, cursor_y - 29 * scale, 745 * scale, cursor_y + 29 * scale]
    cursor_mask = Image.new('L', (canvas_size, canvas_size), 0)
    ImageDraw.Draw(cursor_mask).rounded_rectangle(cursor_box, radius=12 * scale, fill=255)
    cursor_shadow = ImageChops.offset(cursor_mask, 13 * scale, 16 * scale).filter(ImageFilter.GaussianBlur(9 * scale))
    img.alpha_composite(_masked_color(cursor_shadow, (5, 3, 13, 0)))
    img.alpha_composite(_masked_color(ImageChops.offset(cursor_mask, 6 * scale, 8 * scale), (91, 51, 158, 255)))
    img.alpha_composite(_gradient_layer((canvas_size, canvas_size), cursor_mask, '#F0E9FF', '#B8A0F2'))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(
        [cursor_box[0] + 8 * scale, cursor_box[1] + 5 * scale, cursor_box[2] - 8 * scale, cursor_box[1] + 13 * scale],
        radius=4 * scale,
        fill=(255, 252, 255, 155),
    )

    return img.resize((size, size), Image.Resampling.LANCZOS)


def create_adaptive_foreground(size=1024):
    """Scale the same raised mark to fit the Android adaptive-icon safe zone."""
    foreground_size = round(size * 0.74)
    mark = create_command_logo(size).resize((foreground_size, foreground_size), Image.Resampling.LANCZOS)
    foreground = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    foreground.alpha_composite(mark, ((size - foreground_size) // 2, (size - foreground_size) // 2))
    return foreground

def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    app_root = os.path.join(repo_root, 'app')
    res_root = os.path.join(app_root, 'android', 'app', 'src', 'main', 'res')
    
    print(f"Gerando assets Command a partir de: {repo_root}")
    
    # 1. Gerar master images
    master_logo = create_command_logo(1024)
    master_fg = create_adaptive_foreground(1024)
    assert master_logo.size == (1024, 1024) and master_logo.getchannel('A').getbbox()
    assert master_fg.size == (1024, 1024) and master_fg.getchannel('A').getbbox()

    # Ícone do executável Windows e do tray, com a mesma arte do launcher Android.
    windows_icon_path = os.path.join(repo_root, 'CommandPC', 'volume-_2_.ico')
    master_logo.save(
        windows_icon_path,
        format='ICO',
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print(f"Salvo: {windows_icon_path}")
    
    # 2. Ícones legados Android (ic_launcher.png)
    densities_legacy = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    for folder, px in densities_legacy.items():
        out_dir = os.path.join(res_root, folder)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, 'ic_launcher.png')
        resized = master_logo.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(out_path, format='PNG')
        print(f"Salvo: {out_path} ({px}x{px})")

    # 3. Ícones adaptativos Android (ic_launcher_foreground.png)
    # Dimensões da especificação do Android: mdpi=108, hdpi=162, xhdpi=216, xxhdpi=324, xxxhdpi=432
    densities_adaptive = {
        'mipmap-mdpi': 108,
        'mipmap-hdpi': 162,
        'mipmap-xhdpi': 216,
        'mipmap-xxhdpi': 324,
        'mipmap-xxxhdpi': 432,
    }
    for folder, px in densities_adaptive.items():
        out_dir = os.path.join(res_root, folder)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, 'ic_launcher_foreground.png')
        resized = master_fg.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(out_path, format='PNG')
        print(f"Salvo: {out_path} ({px}x{px})")

    # 4. XMLs de ícone adaptativo e cor de fundo
    anydpi_dir = os.path.join(res_root, 'mipmap-anydpi-v26')
    os.makedirs(anydpi_dir, exist_ok=True)
    with open(os.path.join(anydpi_dir, 'ic_launcher.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')
    print("Salvo: mipmap-anydpi-v26/ic_launcher.xml")

    values_dir = os.path.join(res_root, 'values')
    os.makedirs(values_dir, exist_ok=True)
    with open(os.path.join(values_dir, 'ic_launcher_background.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#13101B</color>
</resources>
''')
    print("Salvo: values/ic_launcher_background.xml")

    # 5. Asset de runtime Flutter (assets/images/logo.png)
    flutter_logo_path = os.path.join(app_root, 'assets', 'images', 'logo.png')
    os.makedirs(os.path.dirname(flutter_logo_path), exist_ok=True)
    master_logo.resize((512, 512), Image.Resampling.LANCZOS).save(flutter_logo_path, format='PNG')
    print(f"Salvo: {flutter_logo_path} (512x512)")

    # 6. Web icons e favicon
    web_icons_dir = os.path.join(app_root, 'web', 'icons')
    os.makedirs(web_icons_dir, exist_ok=True)
    master_logo.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-192.png'), format='PNG')
    master_logo.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-512.png'), format='PNG')
    master_logo.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-maskable-192.png'), format='PNG')
    master_logo.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-maskable-512.png'), format='PNG')
    
    favicon_path = os.path.join(app_root, 'web', 'favicon.png')
    master_logo.resize((64, 64), Image.Resampling.LANCZOS).save(favicon_path, format='PNG')
    print("Salvos: ícones web e favicon")

if __name__ == '__main__':
    main()
