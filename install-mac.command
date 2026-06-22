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
titulo "Creando el ícono en el Escritorio"

if [ ! -d "$DESKTOP_DIR" ]; then
  aviso "No encontré la carpeta Escritorio (~/Desktop). Omito el ícono."
else
  CLAUDE_ABS="$(command -v claude || echo "$CLAUDE_BIN")"
  cat > "$LAUNCHER" <<EOF
#!/bin/bash
# Claude Terminal — Lanzador de Claude Code (generado por claude-cmd).
# Doble clic para abrir Claude.
export PATH="\$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH"
clear 2>/dev/null || true
echo "Abriendo Claude... (para salir escribe /exit o pulsa Ctrl+C)"
echo
"$CLAUDE_ABS"$SKIP_FLAG "\$@"
echo
echo "Claude se cerró. Pulsa ENTER para cerrar esta ventana..."
read -r _
EOF
  chmod +x "$LAUNCHER"
  xattr -d com.apple.quarantine "$LAUNCHER" >/dev/null 2>&1 || true
  ok "Ícono creado: 'Claude Terminal' en tu Escritorio (doble clic para abrir)."
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
