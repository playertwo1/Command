#!/usr/bin/env python3
"""
Gera os ícones oficiais do Command para Android (legado e adaptativo), Flutter assets e Web.
Cores e estilo: Amethyst Command (DESIGN.md)
- Background / Shell: #13101B
- Surface: #1E1829
- Border: #A78BFA (Amethyst) / #352B45
- Accent: #C4B5FD (Lavender) / #7C3AED (Deep Violet)
"""

import os
from PIL import Image, ImageDraw

def create_command_logo(size=1024):
    """
    Ícone completo com moldura squircle para modo legado Android, assets Flutter e Web.
    """
    scale = 2
    canvas_size = size * scale
    img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    pad = int(72 * scale)
    radius = int(210 * scale)
    
    # Outer subtle glow / elevation
    draw.rounded_rectangle(
        [pad - int(4*scale), pad - int(4*scale), canvas_size - pad + int(4*scale), canvas_size - pad + int(4*scale)],
        radius=radius + int(4*scale),
        fill=(124, 58, 237, 70)
    )
    
    # Outer border (Amethyst)
    draw.rounded_rectangle(
        [pad, pad, canvas_size - pad, canvas_size - pad],
        radius=radius,
        fill=(26, 21, 36, 255),
        outline=(167, 139, 250, 235),
        width=int(14 * scale)
    )
    
    # Inner surface (#13101B)
    inner_pad = pad + int(14 * scale)
    draw.rounded_rectangle(
        [inner_pad, inner_pad, canvas_size - inner_pad, canvas_size - inner_pad],
        radius=radius - int(10 * scale),
        fill=(19, 16, 27, 255)
    )
    
    # Title bar divider
    bar_y = pad + int(145 * scale)
    draw.line(
        [(inner_pad + int(24 * scale), bar_y), (canvas_size - inner_pad - int(24 * scale), bar_y)],
        fill=(53, 43, 69, 255),
        width=int(6 * scale)
    )
    
    # Title bar window controls (3 dots)
    dot_y = pad + int(85 * scale)
    dot_r = int(14 * scale)
    draw.ellipse([inner_pad + int(48 * scale), dot_y - dot_r, inner_pad + int(48 * scale) + dot_r*2, dot_y + dot_r], fill=(124, 58, 237, 230))
    draw.ellipse([inner_pad + int(96 * scale), dot_y - dot_r, inner_pad + int(96 * scale) + dot_r*2, dot_y + dot_r], fill=(167, 139, 250, 230))
    draw.ellipse([inner_pad + int(144 * scale), dot_y - dot_r, inner_pad + int(144 * scale) + dot_r*2, dot_y + dot_r], fill=(196, 181, 253, 230))
    
    # Command prompt chevron: >
    chevron_pts = [
        (int(310 * scale), int(400 * scale)),
        (int(475 * scale), int(565 * scale)),
        (int(310 * scale), int(730 * scale))
    ]
    draw.line(chevron_pts, fill=(167, 139, 250, 255), width=int(64 * scale), joint='curve')
    
    # Command prompt cursor: _
    cursor_y = int(730 * scale)
    draw.line(
        [(int(545 * scale), cursor_y), (int(745 * scale), cursor_y)],
        fill=(196, 181, 253, 255),
        width=int(58 * scale)
    )
    
    return img.resize((size, size), Image.Resampling.LANCZOS)

def create_adaptive_foreground(size=1024):
    """
    Foreground para ícone adaptativo Android 8+ (API 26+).
    O canvas completo é 108dp. A zona segura (safe zone) é o círculo central de 72dp (66.6%).
    O fundo oficial da adaptive icon é #13101B via ic_launcher_background.xml.
    Aqui desenhamos a janela de comando estilizada (barra, 3 pontos e o glifo > _) centralizados na safe zone.
    """
    scale = 2
    canvas_size = size * scale
    
    safe_d = int(canvas_size * 72 / 108)
    cx = canvas_size // 2
    cy = canvas_size // 2
    
    fg_img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(fg_img)
    
    # Divisor da barra de título na safe zone
    bar_y = cy - int(safe_d * 0.28)
    bar_w = int(safe_d * 0.72)
    draw.line([(cx - bar_w//2, bar_y), (cx + bar_w//2, bar_y)], fill=(53, 43, 69, 255), width=int(6 * scale))
    
    # 3 dots de controle de janela
    dot_y = bar_y - int(32 * scale)
    dot_r = int(11 * scale)
    dot_start_x = cx - bar_w//2 + int(10 * scale)
    draw.ellipse([dot_start_x, dot_y - dot_r, dot_start_x + dot_r*2, dot_y + dot_r], fill=(124, 58, 237, 240))
    draw.ellipse([dot_start_x + int(36 * scale), dot_y - dot_r, dot_start_x + int(36 * scale) + dot_r*2, dot_y + dot_r], fill=(167, 139, 250, 240))
    draw.ellipse([dot_start_x + int(72 * scale), dot_y - dot_r, dot_start_x + int(72 * scale) + dot_r*2, dot_y + dot_r], fill=(196, 181, 253, 240))
    
    # Glifo Command: chevron >
    ch_x0 = cx - int(190 * scale)
    ch_mid_x = cx - int(20 * scale)
    ch_y0 = cy - int(80 * scale)
    ch_mid_y = cy + int(70 * scale)
    ch_y1 = cy + int(220 * scale)
    draw.line([(ch_x0, ch_y0), (ch_mid_x, ch_mid_y), (ch_x0, ch_y1)], fill=(167, 139, 250, 255), width=int(56 * scale), joint='curve')
    
    # Cursor do console: _
    cur_x0 = cx + int(50 * scale)
    cur_x1 = cx + int(210 * scale)
    draw.line([(cur_x0, ch_y1), (cur_x1, ch_y1)], fill=(196, 181, 253, 255), width=int(50 * scale))
    
    return fg_img.resize((size, size), Image.Resampling.LANCZOS)

def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    app_root = os.path.join(repo_root, 'app')
    res_root = os.path.join(app_root, 'android', 'app', 'src', 'main', 'res')
    
    print(f"Gerando assets Command a partir de: {repo_root}")
    
    # 1. Gerar master images
    master_logo = create_command_logo(1024)
    master_fg = create_adaptive_foreground(1024)
    
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
    with open(os.path.join(anydpi_dir, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
        f.write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')
    print("Salvo: mipmap-anydpi-v26/ic_launcher.xml")

    values_dir = os.path.join(res_root, 'values')
    os.makedirs(values_dir, exist_ok=True)
    with open(os.path.join(values_dir, 'ic_launcher_background.xml'), 'w', encoding='utf-8') as f:
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
