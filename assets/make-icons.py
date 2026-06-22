#!/usr/bin/env python3
"""
make-icons.py — Genera los íconos de "Claude Terminal" a partir de la mascota.

Toma la imagen fuente (mascota coral sobre fondo verde), detecta la mascota,
la recorta, la centra en un lienzo cuadrado y produce 3 variantes de fondo:
  A) transparente   B) verde (mosaico)   C) oscuro de marca (mosaico)

Para cada variante elegida luego se generan los formatos finales (.png/.icns/.ico).

Uso:
  python3 make-icons.py <imagen_fuente.png> <carpeta_salida> [--final <A|B|C>]

Sin --final: genera solo previews 512px de las 3 variantes (para elegir).
Con --final X: genera la variante X como master 1024 + .icns + .ico.

Requiere Pillow.  (Solo se usa en la máquina del desarrollador; los usuarios
finales reciben el ícono ya generado y embebido en los instaladores.)
"""
import sys, os, argparse, base64
from PIL import Image, ImageChops, ImageDraw, ImageFilter

PAD = 0.14          # margen seguro a cada lado del lienzo
DARK = (28, 26, 25) # color oscuro de marca (#1C1A19)
THR = 60            # umbral de diferencia respecto al fondo

def detect_bg(im):
    """Color de fondo = color más común en el borde."""
    from collections import Counter
    rgb = im.convert("RGB")
    W, H = rgb.size
    c = Counter()
    for x in range(0, W, 4):
        c[rgb.getpixel((x, 0))] += 1
        c[rgb.getpixel((x, H - 1))] += 1
    for y in range(0, H, 4):
        c[rgb.getpixel((0, y))] += 1
        c[rgb.getpixel((W - 1, y))] += 1
    return c.most_common(1)[0][0]

def foreground_mask(im, bg):
    """Máscara (L) de lo que NO es fondo."""
    bg_img = Image.new("RGB", im.size, bg)
    diff = ImageChops.difference(im.convert("RGB"), bg_img).convert("L")
    mask = diff.point(lambda p: 255 if p > THR else 0)
    # limpiar puntitos sueltos y suavizar 1px el borde para anti-alias
    mask = mask.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    mask = mask.filter(ImageFilter.GaussianBlur(0.6))
    return mask

def cutout(im, mask):
    """Mascota recortada (RGBA) ajustada a su bounding box, fondo transparente."""
    rgba = im.convert("RGBA")
    rgba.putalpha(mask)
    bbox = mask.getbbox()
    return rgba.crop(bbox), bbox

def flatten(mascot):
    """Aplana a colores planos: cuerpo coral + ojos negros (conserva el alfa del borde).
    Quita la textura/ruido del render (icono nítido y archivo chico) y elimina el halo verde."""
    px = mascot.load()
    w, h = mascot.size
    rs = gs = bs = n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 180 and (0.299 * r + 0.587 * g + 0.114 * b) >= 95:
                rs += r; gs += g; bs += b; n += 1
    coral = (rs // n, gs // n, bs // n) if n else (203, 112, 78)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 24:
                px[x, y] = (0, 0, 0, 0)
            elif (0.299 * r + 0.587 * g + 0.114 * b) < 80:
                px[x, y] = (26, 24, 23, a)          # ojos (negro)
            else:
                px[x, y] = (coral[0], coral[1], coral[2], a)  # cuerpo (coral)
    return mascot, coral

def rounded(size, radius_frac=0.2235):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    r = int(size * radius_frac)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
    return m

def square_canvas(mascot, size, bg=None, rounded_corners=False):
    """Centra la mascota en un lienzo cuadrado 'size' con margen PAD."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if bg is not None:
        fill = Image.new("RGBA", (size, size), bg + (255,))
        if rounded_corners:
            fill.putalpha(rounded(size))
        canvas = Image.alpha_composite(canvas, fill)
    inner = int(size * (1 - 2 * PAD))
    w, h = mascot.size
    scale = min(inner / w, inner / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    m = mascot.resize((nw, nh), Image.LANCZOS)
    ox, oy = (size - nw) // 2, (size - nh) // 2
    canvas.alpha_composite(m, (ox, oy))
    return canvas

def build_variant(mascot, which, size):
    if which == "A":
        return square_canvas(mascot, size, bg=None)
    if which == "B":
        return square_canvas(mascot, size, bg=(46, 204, 46), rounded_corners=True)
    if which == "C":
        return square_canvas(mascot, size, bg=DARK, rounded_corners=True)
    raise ValueError(which)

def make_ico(master1024, out_ico):
    # Pillow re-escala el master (1024) a cada tamaño; con color plano sale nítido.
    sizes = [16, 32, 48, 128, 256]  # tamaños estándar de Windows .ico
    master1024.save(out_ico, format="ICO", sizes=[(s, s) for s in sizes])

def emit_b64(path):
    with open(path, "rb") as f:
        b = base64.b64encode(f.read()).decode()
    with open(path + ".b64", "w") as f:
        f.write(b)
    return len(b)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("out")
    ap.add_argument("--final", choices=["A", "B", "C"])
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)

    im = Image.open(a.src)
    bg = detect_bg(im)
    mask = foreground_mask(im, bg)
    mascot, bbox = cutout(im, mask)
    mascot, coral = flatten(mascot)
    print(f"fondo detectado: {bg}   bbox mascota: {bbox}   coral: {coral}   tamaño recorte: {mascot.size}")

    if not a.final:
        for w in ("A", "B", "C"):
            build_variant(mascot, w, 512).save(os.path.join(a.out, f"preview-{w}-512.png"))
        print("Previews 512 generadas: preview-A/B/C-512.png")
        return

    master = build_variant(mascot, a.final, 1024)
    png = os.path.join(a.out, "claude-terminal.png")   # master 1024; lo embebe el instalador Mac
    ico = os.path.join(a.out, "claude-terminal.ico")   # Windows; lo embebe el instalador Win
    master.save(png)
    make_ico(master, ico)
    n_png = emit_b64(png)
    n_ico = emit_b64(ico)
    print(f"Generados (variante {a.final}): {png}, {ico}")
    print(f"base64: {png}.b64 = {n_png} chars  |  {ico}.b64 = {n_ico} chars")

if __name__ == "__main__":
    main()
