# Claude Code en 1 clic 🚀

Instala **Claude Code** correctamente y deja un ícono **"Claude Terminal"** en tu Escritorio.
Sin saber programar. Hecho para evitar los errores típicos de instalación (el clásico
`claude: command not found`, problemas de PATH, permisos, etc.).

---

## ✅ Antes de empezar

- Necesitas una cuenta **Claude Pro, Max, Team o Enterprise** (el plan gratis **no** incluye Claude Code).
- **Mac:** macOS 13 o superior. · **Windows:** Windows 10 (1809) o superior, 64 bits.
- Conexión a internet.

---

## 🍎 Mac

### Opción A — Descargar el archivo (recomendado)

1. Descarga **[`install-mac.command`](https://raw.githubusercontent.com/Hainrixz/claude-cmd/main/install-mac.command)**
   (clic derecho → "Guardar enlace como…", o desde la página del repo).
2. Haz **doble clic** en el archivo.
3. Si macOS lo bloquea ("no se puede abrir porque es de un desarrollador no identificado"):
   **clic derecho sobre el archivo → Abrir → Abrir**. (Solo la primera vez.)

> Si el doble clic falla por permisos, abre **Terminal** y pega esto una vez:
> ```bash
> chmod +x ~/Downloads/install-mac.command && xattr -dr com.apple.quarantine ~/Downloads/install-mac.command && ~/Downloads/install-mac.command
> ```

### Opción B — Un solo comando (lo más confiable)

Abre **Terminal** (⌘ + Espacio → escribe "Terminal" → Enter), pega esto y pulsa Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/Hainrixz/claude-cmd/main/install-mac.command | bash
```

Cuando termine, busca **"Claude Terminal"** en tu Escritorio y haz doble clic. ✅

---

## 🪟 Windows

### Opción A — Descargar el archivo (recomendado)

1. Descarga **[`install-windows.bat`](https://raw.githubusercontent.com/Hainrixz/claude-cmd/main/install-windows.bat)**.
2. Haz **doble clic** en el archivo.
3. Si aparece **SmartScreen** ("Windows protegió su PC"):
   **"Más información" → "Ejecutar de todas formas"**.

### Opción B — Un solo comando

Abre **PowerShell** (botón Inicio → escribe "PowerShell" → Enter), pega esto y pulsa Enter:

```powershell
irm https://raw.githubusercontent.com/Hainrixz/claude-cmd/main/install-windows.ps1 | iex
```

Cuando termine, busca **"Claude Terminal"** en tu Escritorio y haz doble clic. ✅

---

## ▶️ La primera vez

Al abrir Claude Code, se abrirá tu **navegador** para iniciar sesión. Inicia sesión con tu
cuenta de Anthropic y vuelve a la ventana de la terminal. ¡Listo!

---

## ⚙️ Opciones (avanzado)

- **Modo avanzado (saltar permisos, `--dangerously-skip-permissions`):** desactivado por defecto.
  Con él, Claude ejecuta acciones **sin pedirte confirmación** — actívalo solo si sabes lo que haces.
  - Al instalar por **doble clic**, el instalador te pregunta si quieres activarlo.
  - Al instalar por **comando**, actívalo así:
    - Mac: `CLAUDE_CMD_SKIP_PERMS=1 bash <(curl -fsSL https://raw.githubusercontent.com/Hainrixz/claude-cmd/main/install-mac.command)`
    - Windows: `$env:CLAUDE_CMD_SKIP_PERMS=1; irm https://raw.githubusercontent.com/Hainrixz/claude-cmd/main/install-windows.ps1 | iex`

---

## 🆘 Solución a problemas comunes

| Síntoma (lo que ves) | Por qué pasa | Solución |
|---|---|---|
| `command not found: claude` / `'claude' no se reconoce` | El PATH no se recargó | **Cierra y abre** una terminal nueva. Mac: o ejecuta `source ~/.zshrc`. (El ícono del Escritorio funciona igual.) |
| (Mac) "no se puede abrir porque es de un desarrollador no identificado" | Gatekeeper en un archivo descargado | **Clic derecho → Abrir → Abrir.** El ícono del Escritorio no tiene este problema (se crea en tu Mac). |
| (Mac) "no tiene privilegios de acceso" al doble clic | El archivo descargado perdió el permiso de ejecución | Usa la **Opción B** (el comando), o el comando `chmod +x …` de arriba. |
| (Windows) `irm no se reconoce` | Estás en CMD, no en PowerShell | Abre **PowerShell** (el prompt empieza con `PS C:\>`). |
| (Windows) `bash no se reconoce` | Pegaste el comando de Mac en Windows | Usa el comando de Windows (`irm … | iex`). |
| (Windows) "no se pueden ejecutar scripts / running scripts is disabled" | Política de ejecución restringida | `Set-ExecutionPolicy -Scope Process Bypass`, luego repite el comando. (El `.bat` ya lo evita.) |
| (Windows) instala pero falta `claude.exe`, o "el proceso no puede acceder al archivo …\.claude\downloads" | Antivirus bloqueó la descarga | `Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\downloads"`, añade una exclusión para `%USERPROFILE%\.local\bin`, y reintenta. |
| (Windows) "does not support 32-bit Windows" | Abriste PowerShell (x86) | Abre **"Windows PowerShell"** normal, no la versión (x86). |
| Versión vieja tras instalar / avisos de instalaciones duplicadas | Hay varias instalaciones (npm + nativa) | `npm uninstall -g @anthropic-ai/claude-code`, borra `~/.claude/local`, reinstala. |
| Pide iniciar sesión y dice que no tienes acceso | Plan gratis | Claude Code requiere **Pro / Max / Team / Enterprise**. |
| Quieres un diagnóstico | — | Ejecuta `claude doctor` en una terminal. |

---

## 🗑️ Desinstalar

- **Mac:**
  ```bash
  rm -f ~/.local/bin/claude && rm -rf ~/.local/share/claude
  rm -f ~/Desktop/"Claude Terminal.command"
  ```
- **Windows:**
  ```powershell
  Remove-Item -Force "$env:USERPROFILE\.local\bin\claude.exe"
  Remove-Item -Force "$([Environment]::GetFolderPath('Desktop'))\Claude Terminal.lnk"
  ```
  (Config de usuario opcional: `~/.claude` y `~/.claude.json`.)

---

## ¿Cómo funciona?

Estos scripts usan el **instalador nativo oficial de Anthropic** por debajo
(`https://claude.ai/install.sh` en Mac, `https://claude.ai/install.ps1` en Windows), que instala
Claude Code por-usuario, sin Node ni permisos de administrador. Encima de eso:
verifican la instalación, arreglan el PATH si hace falta, y **generan localmente** el lanzador del
Escritorio (por eso no sufre de Gatekeeper/SmartScreen). El lanzador llama al binario por su **ruta
absoluta**, así funciona de inmediato sin reiniciar la terminal. Además, al acceso directo se le pone
el ícono de la **mascota** 🟧 (embebido en los instaladores como base64; en Mac vía `osascript`+
NSWorkspace, en Windows como `.ico` en `%LOCALAPPDATA%\claude-cmd`). Si el ícono no se pudiera
aplicar, el lanzador funciona igual.

## 🎨 Personalizar / regenerar el ícono

El ícono se genera desde `assets/mascot-source.png` con herramientas locales (Python + Pillow):

```bash
# 1) Genera claude-terminal.png (.icns no hace falta) y claude-terminal.ico + sus .b64
python3 assets/make-icons.py assets/mascot-source.png assets --final A
# 2) Inyecta los base64 en install-mac.command e install-windows.ps1
python3 assets/embed-icons.py
```

`--final A` usa fondo transparente; `B` (verde) y `C` (oscuro de marca) también están disponibles.

## Licencia

[MIT](LICENSE).
