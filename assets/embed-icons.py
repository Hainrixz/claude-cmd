#!/usr/bin/env python3
"""
embed-icons.py — Inyecta los íconos (base64) en los instaladores.

Lee assets/claude-terminal.png.b64 y assets/claude-terminal.ico.b64 (generados por
make-icons.py) y reemplaza las líneas marcadoras en:
  - install-mac.command   ->  ICON_PNG_B64='...'
  - install-windows.ps1   ->  $IconBase64 = '...'

Es idempotente: cada corrida vuelve a poner el blob actual. Correr desde la raíz del repo:
  python3 assets/make-icons.py assets/mascot-source.png assets --final A
  python3 assets/embed-icons.py
"""
import re, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

def read_b64(name):
    p = ROOT / "assets" / name
    return p.read_text().strip()

def inject(path, pattern, replacement):
    f = ROOT / path
    txt = f.read_text()
    new, n = re.subn(pattern, replacement.replace("\\", "\\\\"), txt, flags=re.M)
    if n != 1:
        sys.exit(f"ERROR: el marcador no se encontró exactamente 1 vez en {path} (encontrado {n}).")
    f.write_text(new)
    print(f"OK: {path} <- {len(replacement)} chars")

def main():
    png_b64 = read_b64("claude-terminal.png.b64")
    ico_b64 = read_b64("claude-terminal.ico.b64")
    # Mac: ICON_PNG_B64='...'
    inject("install-mac.command", r"^ICON_PNG_B64=.*$", f"ICON_PNG_B64='{png_b64}'")
    # Windows: $IconBase64 = '...'
    inject("install-windows.ps1", r"^\$IconBase64 = .*$", f"$IconBase64 = '{ico_b64}'")

if __name__ == "__main__":
    main()
