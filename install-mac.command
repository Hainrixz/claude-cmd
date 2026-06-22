#!/bin/bash
#
# install-mac.command — Instalador "un clic" de Claude Code para macOS
# Repo: https://github.com/Hainrixz/claude-cmd
#
# Funciona de 3 formas:
#   1) Doble clic en este archivo (Finder abre Terminal y lo ejecuta).
#   2) Pegando en Terminal:
#        curl -fsSL https://raw.githubusercontent.com/Hainrixz/claude-cmd/main/install-mac.command | bash
#   3) Ejecutándolo directamente:  bash install-mac.command
#
# Qué hace:
#   - Usa el instalador NATIVO oficial de Anthropic (sin Node, sin sudo, por-usuario).
#   - Asegura el PATH solo si hace falta (deja que el instalador oficial sea el dueño).
#   - Verifica con 'claude --version'.
#   - Crea un ícono "Claude Terminal" en el Escritorio (con la ruta absoluta del binario,
#     para que funcione de inmediato sin reiniciar la terminal).
#   - Es re-ejecutable (idempotente). Mensajes en español.
#
# Modo avanzado (saltar permisos): se pregunta al instalar por doble clic, o se activa con
#   CLAUDE_CMD_SKIP_PERMS=1 en instalaciones por 'curl | bash'.
#
set -uo pipefail

# ---------------------------------------------------------------------------
# Colores (degradan a texto plano si no hay terminal con color)
# ---------------------------------------------------------------------------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET="$(tput sgr0)";  C_BOLD="$(tput bold)"
  C_GREEN="$(tput setaf 2)"; C_RED="$(tput setaf 1)"
  C_YELLOW="$(tput setaf 3)"; C_BLUE="$(tput setaf 4)"
else
  C_RESET=""; C_BOLD=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_BLUE=""
fi

titulo()  { printf "\n%s%s==> %s%s\n" "$C_BOLD" "$C_BLUE" "$1" "$C_RESET"; }
ok()      { printf "%s  ✔ %s%s\n" "$C_GREEN" "$1" "$C_RESET"; }
info()    { printf "    %s\n" "$1"; }
aviso()   { printf "%s  ! %s%s\n" "$C_YELLOW" "$1" "$C_RESET"; }
error()   { printf "%s  ✗ %s%s\n" "$C_RED" "$1" "$C_RESET" >&2; }

# ---------------------------------------------------------------------------
# Detección de "doble clic": si stdin es una terminal, lo abrió Finder.
# En 'curl | bash', stdin es el pipe (no terminal) -> no preguntamos ni pausamos.
# ---------------------------------------------------------------------------
DOUBLE_CLICK=0
[ -t 0 ] && DOUBLE_CLICK=1

pausa_final() {
  if [ "$DOUBLE_CLICK" -eq 1 ]; then
    printf "\n%sPuedes cerrar esta ventana.%s\n" "$C_BOLD" "$C_RESET"
    printf "Pulsa ENTER para salir... "
    read -r _ || true
  fi
}
trap pausa_final EXIT

# ---------------------------------------------------------------------------
# Rutas
# ---------------------------------------------------------------------------
BIN_DIR="$HOME/.local/bin"
CLAUDE_BIN="$BIN_DIR/claude"
DESKTOP_DIR="$HOME/Desktop"
LAUNCHER="$DESKTOP_DIR/Claude Terminal.command"

# PATH enriquecido para que 'claude' sea encontrable durante este script.
export PATH="$BIN_DIR:/opt/homebrew/bin:/usr/local/bin:$PATH"

# ---------------------------------------------------------------------------
clear 2>/dev/null || true
printf "%s%s" "$C_BOLD" "$C_BLUE"
printf "  ╔══════════════════════════════════════════╗\n"
printf "  ║   Claude Code — Instalador para macOS     ║\n"
printf "  ║   claude-cmd                              ║\n"
printf "  ╚══════════════════════════════════════════╝\n"
printf "%s\n" "$C_RESET"

# ---------------------------------------------------------------------------
# 0) Requisitos: macOS 13+ y curl
# ---------------------------------------------------------------------------
titulo "Comprobando tu Mac"
OS_MAJOR="$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)"
if [ -n "${OS_MAJOR:-}" ] && [ "$OS_MAJOR" -ge 13 ] 2>/dev/null; then
  ok "macOS $(sw_vers -productVersion) — compatible."
else
  aviso "No pude confirmar tu versión de macOS, o es anterior a la 13.0."
  aviso "Claude Code requiere macOS 13.0 o superior. Intentaré continuar igualmente."
fi

if ! command -v curl >/dev/null 2>&1; then
  error "No se encontró 'curl' (necesario para instalar). Instálalo y reintenta."
  exit 1
fi

# ---------------------------------------------------------------------------
# 1) Instalaciones previas (idempotencia + evitar conflictos de PATH)
# ---------------------------------------------------------------------------
titulo "Revisando instalaciones previas"

if [ -d "$HOME/.claude/local" ]; then
  aviso "Detecté una instalación antigua en ~/.claude/local (formato legado)."
  info  "La dejo intacta. Si luego ves conflictos: rm -rf ~/.claude/local"
fi

if command -v npm >/dev/null 2>&1 && npm ls -g @anthropic-ai/claude-code >/dev/null 2>&1; then
  aviso "Detecté Claude Code instalado por npm global (puede tapar la instalación nativa)."
  info  "Voy a intentar quitarlo para dejar una sola instalación limpia (la nativa)."
  info  "Esto puede tardar unos segundos…"
  if npm uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1; then
    ok "Instalación de npm global eliminada."
    command -v rehash >/dev/null 2>&1 && rehash 2>/dev/null || true
  else
    aviso "No pude eliminar la versión de npm automáticamente."
    info  "Si ves una versión vieja, ejecuta: npm uninstall -g @anthropic-ai/claude-code"
  fi
fi

if [ -x "$CLAUDE_BIN" ]; then
  ok "Ya existe una instalación nativa en ~/.local/bin/claude (la actualizaré)."
else
  info "No hay instalación nativa todavía. La instalaré ahora."
fi

# ---------------------------------------------------------------------------
# 2) Instalador NATIVO oficial de Anthropic
# ---------------------------------------------------------------------------
titulo "Instalando Claude Code (instalador oficial)"
info "Descargando y ejecutando https://claude.ai/install.sh ..."

if curl -fsSL https://claude.ai/install.sh | bash; then
  ok "El instalador oficial terminó."
else
  error "Falló la instalación (descarga o ejecución del instalador oficial)."
  error "Revisa tu conexión a internet y vuelve a ejecutar este instalador."
  info  "Si persiste, prueba el canal estable:"
  info  "    curl -fsSL https://claude.ai/install.sh | bash -s stable"
  exit 1
fi

# Refrescar PATH/caché tras instalar.
export PATH="$BIN_DIR:$PATH"
hash -r 2>/dev/null || true
command -v rehash >/dev/null 2>&1 && rehash 2>/dev/null || true

# ---------------------------------------------------------------------------
# 3) PATH: el instalador oficial es el dueño. Solo añadimos un fallback
#    si 'claude' AÚN no se encuentra (idempotente, con marcador único).
# ---------------------------------------------------------------------------
titulo "Configurando el PATH (si hace falta)"

if command -v claude >/dev/null 2>&1; then
  ok "El instalador oficial ya configuró el PATH."
else
  aviso "El comando 'claude' aún no está en el PATH. Añado un respaldo."
  PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
  MARKER='# >>> claude-cmd PATH >>>'
  asegurar_path_en() {
    local rc="$1"
    [ -e "$rc" ] || : > "$rc"
    if grep -qF "$MARKER" "$rc" 2>/dev/null; then
      ok "PATH ya configurado en $(basename "$rc")."
    else
      {
        printf '\n%s\n' "$MARKER"
        printf '%s\n' "$PATH_LINE"
        printf '%s\n' "# <<< claude-cmd PATH <<<"
      } >> "$rc"
      ok "PATH añadido a $(basename "$rc")."
    fi
  }
  asegurar_path_en "$HOME/.zshrc"
  asegurar_path_en "$HOME/.bash_profile"
  asegurar_path_en "$HOME/.bashrc"
fi

# ---------------------------------------------------------------------------
# 4) Verificación: SOLO 'claude --version' (compuerta de éxito)
# ---------------------------------------------------------------------------
titulo "Verificando la instalación"

VERSION_OK=0
if [ -x "$CLAUDE_BIN" ] && VER_OUT="$("$CLAUDE_BIN" --version </dev/null 2>/dev/null)"; then
  VERSION_OK=1
elif command -v claude >/dev/null 2>&1 && VER_OUT="$(claude --version </dev/null 2>/dev/null)"; then
  VERSION_OK=1
  CLAUDE_BIN="$(command -v claude)"
fi

if [ "$VERSION_OK" -ne 1 ]; then
  error "La instalación terminó pero no pude ejecutar 'claude --version'."
  error "Cierra esta ventana, abre una NUEVA Terminal y prueba:  claude --version"
  info  "Si sigue sin funcionar:  source ~/.zshrc   y reintenta."
  exit 1
fi
ok "Claude Code instalado correctamente: $VER_OUT"

# ---------------------------------------------------------------------------
# 5) Modo avanzado (saltar permisos): opcional
# ---------------------------------------------------------------------------
SKIP_FLAG=""
if [ "${CLAUDE_CMD_SKIP_PERMS:-0}" = "1" ]; then
  SKIP_FLAG=" --dangerously-skip-permissions"
elif [ "$DOUBLE_CLICK" -eq 1 ]; then
  titulo "Modo de apertura"
  info  "Normal (seguro): Claude pide confirmación antes de acciones sensibles."
  info  "Avanzado: Claude actúa sin pedir confirmación (--dangerously-skip-permissions)."
  printf "    ¿Activar modo avanzado? [s/N] "
  read -r RESP || RESP=""
  case "$RESP" in
    [sS]|[sS][ií]|[yY]) SKIP_FLAG=" --dangerously-skip-permissions"
         aviso "Modo avanzado activado para el ícono del Escritorio." ;;
    *)   ok "Modo normal (seguro)." ;;
  esac
fi

# ---------------------------------------------------------------------------
# 6) Ícono del Escritorio "Claude Terminal" (generado localmente -> sin quarantine)
#    Se hornea la RUTA ABSOLUTA del binario para que funcione de inmediato.
# ---------------------------------------------------------------------------
# Ícono de la mascota: PNG embebido en base64 (autocontenible, funciona en
# 'curl | bash' sin archivos locales). Se aplica con osascript + NSWorkspace
# (stock de macOS, sin Xcode). Como el lanzador se re-escribe en cada corrida,
# el ícono se RE-APLICA siempre. Si algo falla, NO es fatal.
# (El blob lo inyecta assets/embed-icons.py desde assets/claude-terminal.png.b64.)
ICON_PNG_B64='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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGLn/j+o2S3KFTT4VgAAAABJRU5ErkJggg=='
aplicar_icono() {
  local target="$1" tmp png
  [ -n "$ICON_PNG_B64" ] || return 1
  tmp="$(mktemp -d 2>/dev/null)" || return 1
  png="$tmp/claude-terminal.png"
  printf '%s' "$ICON_PNG_B64" | { base64 -D 2>/dev/null || base64 -d 2>/dev/null; } > "$png" || { rm -rf "$tmp"; return 1; }
  [ -s "$png" ] || { rm -rf "$tmp"; return 1; }
  osascript - "$png" "$target" >/dev/null 2>&1 <<'OSA'
use framework "Cocoa"
use scripting additions
on run argv
  set img to current application's NSImage's alloc()'s initWithContentsOfFile:(item 1 of argv)
  if img is missing value then error "img"
  set okv to current application's NSWorkspace's sharedWorkspace()'s setIcon:img forFile:(item 2 of argv) options:0
  if okv is false then error "setIcon"
end run
OSA
  local rc=$?
  rm -rf "$tmp"
  return $rc
}

titulo "Creando el ícono en el Escritorio"

if [ ! -d "$DESKTOP_DIR" ]; then
  aviso "No encontré la carpeta Escritorio (~/Desktop). Omito el ícono."
else
  CLAUDE_ABS="$(command -v claude || echo "$CLAUDE_BIN")"
  # El cuerpo del lanzador (incluido el menú) se escribe en un heredoc ENTRE
  # COMILLAS (<<'MENU'), así el bash queda literal y no hay que escapar cada $.
  # Solo la línea de lanzamiento (con la ruta absoluta del binario) va en un
  # heredoc normal al final, donde sí se expanden $CLAUDE_ABS y $SKIP_FLAG.
  cat > "$LAUNCHER" <<'MENU'
#!/bin/bash
# Claude Terminal — Lanzador de Claude Code (generado por claude-cmd).
# Doble clic para abrir Claude. Pregunta en qué carpeta abrirlo.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
clear 2>/dev/null || true

# ---- Menú "elegir carpeta" ----
STATE_DIR="$HOME/.local/state/claude-cmd"
STATE_FILE="$STATE_DIR/lastdir"

# Limpia una ruta pegada o arrastrada: quita comillas, des-escapa el "\ " que
# Finder mete al arrastrar, y recorta espacios sobrantes al inicio/fin.
_limpiar_ruta() {
  local s="$1"
  s="${s#\"}"; s="${s%\"}"
  s="${s#\'}"; s="${s%\'}"
  s="${s//\\ / }"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Memoria: última carpeta usada (si existe y sigue siendo una carpeta válida).
ULTIMA=""
if [ -f "$STATE_FILE" ]; then ULTIMA="$(cat "$STATE_FILE" 2>/dev/null)"; fi
if [ -n "$ULTIMA" ] && [ ! -d "$ULTIMA" ]; then ULTIMA=""; fi

DESTINO=""
while :; do
  echo "¿En qué carpeta quieres abrir Claude Code? 📂"
  echo "Elige una opción (o pulsa Enter para usar la de siempre)."
  echo
  echo "  [Enter]  Tu carpeta personal  (por defecto)"
  echo "       1   Escritorio"
  echo "       2   Documentos"
  echo "       3   Descargas"
  echo "       4   Elegir una carpeta…  (se abre una ventana para buscarla)"
  echo "       5   Escribir o arrastrar una carpeta aquí"
  if [ -n "$ULTIMA" ]; then
    echo "       6   Última carpeta que usaste:  $ULTIMA"
  fi
  echo
  printf "Tu elección: "
  read -r ELECCION

  case "$ELECCION" in
    "")  DESTINO="$HOME" ;;
    1)   DESTINO="$HOME/Desktop" ;;
    2)   DESTINO="$HOME/Documents" ;;
    3)   DESTINO="$HOME/Downloads" ;;
    4)
      # Selector gráfico nativo de macOS.
      elegida="$(osascript -e 'try' -e 'POSIX path of (choose folder with prompt "Elige la carpeta para abrir Claude Code")' -e 'end try' 2>/dev/null)"
      elegida="$(_limpiar_ruta "$elegida")"
      if [ -n "$elegida" ] && [ -d "$elegida" ]; then
        DESTINO="$elegida"
      else
        echo; echo "  No se eligió ninguna carpeta. Volvamos al menú."; echo; continue
      fi
      ;;
    5)
      printf "  Escribe o arrastra la carpeta y pulsa Enter: "
      read -r escrita
      escrita="$(_limpiar_ruta "$escrita")"
      case "$escrita" in
        "~")   escrita="$HOME" ;;
        "~/"*) escrita="$HOME/${escrita#\~/}" ;;
      esac
      if [ -n "$escrita" ] && [ -d "$escrita" ]; then
        DESTINO="$escrita"
      else
        echo; echo "  No encontré esa carpeta. Volvamos al menú."; echo; continue
      fi
      ;;
    6)
      if [ -n "$ULTIMA" ] && [ -d "$ULTIMA" ]; then
        DESTINO="$ULTIMA"
      else
        echo; echo "  Opción no válida. Volvamos al menú."; echo; continue
      fi
      ;;
    *)   echo; echo "  Opción no válida. Volvamos al menú."; echo; continue ;;
  esac
  break
done

# Validación final: si el destino no sirve, caer a la carpeta personal.
if [ -z "$DESTINO" ] || [ ! -d "$DESTINO" ]; then
  echo "  No encontré esa carpeta. Abro tu carpeta personal."
  DESTINO="$HOME"
fi
if ! cd "$DESTINO" 2>/dev/null; then
  echo "  No encontré esa carpeta. Abro tu carpeta personal."
  cd "$HOME" 2>/dev/null || cd /
fi

# Guardar la carpeta realmente usada como "última carpeta".
mkdir -p "$STATE_DIR" 2>/dev/null && printf '%s\n' "$(pwd)" > "$STATE_FILE" 2>/dev/null

clear 2>/dev/null || true
echo "  ✔ Abriendo Claude Code en:  $(pwd)"
echo "  (para salir escribe /exit o pulsa Ctrl+C)"
echo
echo "💡 ¿Primera vez? Pulsa Enter sin escribir nada y listo: usamos tu carpeta personal."
echo
# ---- /Menú ----
MENU
  cat >> "$LAUNCHER" <<EOF
"$CLAUDE_ABS"$SKIP_FLAG "\$@"
echo
echo "Claude se cerró. Pulsa ENTER para cerrar esta ventana..."
read -r _
EOF
  chmod +x "$LAUNCHER"
  xattr -d com.apple.quarantine "$LAUNCHER" >/dev/null 2>&1 || true
  xattr -dr com.apple.provenance "$LAUNCHER" >/dev/null 2>&1 || true
  ok "Lanzador creado: 'Claude Terminal' en tu Escritorio."
  if aplicar_icono "$LAUNCHER"; then
    ok "Ícono de la mascota aplicado."
    touch "$LAUNCHER" 2>/dev/null || true
  else
    info "(No se pudo poner el ícono personalizado; el lanzador funciona igual.)"
  fi
  info "Doble clic en 'Claude Terminal' para abrir Claude."
fi

# ---------------------------------------------------------------------------
# 7) Resumen
# ---------------------------------------------------------------------------
titulo "¡Listo!"
ok "Claude Code está instalado y verificado."
printf "\n"
info "Cómo abrirlo:"
info "  • Doble clic en 'Claude Terminal' en tu Escritorio (funciona ya), o"
info "  • Abre una Terminal NUEVA y escribe:  claude"
printf "\n"
aviso "La primera vez, Claude abrirá tu navegador para iniciar sesión."
info  "Necesitas una cuenta Claude Pro, Max, Team o Enterprise (el plan gratis no incluye Claude Code)."
printf "\n"
info "Si 'claude' no aparece en una Terminal que ya tenías abierta, ciérrala y abre una nueva."

exit 0
