#!/bin/bash
#
# install-linux.sh — Instalador "un comando" de Claude Code para Linux
# Repo: https://github.com/Hainrixz/claude-cmd
#
# Funciona de 2 formas:
#   1) Pegando en tu terminal:
#        curl -fsSL https://raw.githubusercontent.com/Hainrixz/claude-cmd/main/install-linux.sh | bash
#   2) Descargándolo y ejecutándolo:  bash install-linux.sh
#
# Qué hace:
#   - Usa el instalador NATIVO oficial de Anthropic (sin Node, sin sudo, por-usuario).
#   - Asegura el PATH solo si hace falta (.bashrc / .zshrc / .profile).
#   - Verifica con 'claude --version'.
#   - Crea un lanzador "Claude Terminal" (comando + ícono en el menú de aplicaciones
#     y, si hay Escritorio, también ahí). Al abrirlo pregunta en qué carpeta abrir Claude.
#   - En servidores / WSL sin entorno gráfico: instala igual y omite el ícono (sin fallar).
#   - Es re-ejecutable (idempotente). Mensajes en español.
#
# Modo avanzado (--dangerously-skip-permissions): se elige POR SESIÓN en el hub.
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
# Si se ejecuta en una terminal interactiva (no 'curl | bash'), pausamos al
# final para que la ventana no se cierre de golpe.
# ---------------------------------------------------------------------------
INTERACTIVO=0
[ -t 0 ] && INTERACTIVO=1

pausa_final() {
  if [ "$INTERACTIVO" -eq 1 ]; then
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
LAUNCHER_SCRIPT="$BIN_DIR/claude-terminal"
ICON_DIR="$HOME/.local/share/icons"
ICON_PATH="$ICON_DIR/claude-terminal.png"
APPS_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$APPS_DIR/claude-terminal.desktop"

# PATH enriquecido para que 'claude' sea encontrable durante este script.
export PATH="$BIN_DIR:$PATH"

# ---------------------------------------------------------------------------
clear 2>/dev/null || true
printf "%s%s" "$C_BOLD" "$C_BLUE"
printf "  ╔══════════════════════════════════════════╗\n"
printf "  ║   Claude Code — Instalador para Linux     ║\n"
printf "  ║   claude-cmd                              ║\n"
printf "  ╚══════════════════════════════════════════╝\n"
printf "%s\n" "$C_RESET"

# ---------------------------------------------------------------------------
# 0) Requisitos: Linux y curl
# ---------------------------------------------------------------------------
titulo "Comprobando tu sistema"
if [ "$(uname -s 2>/dev/null)" = "Linux" ]; then
  ok "Linux detectado ($(uname -m 2>/dev/null))."
else
  aviso "Esto no parece Linux. Este instalador es para Linux; en Mac usa install-mac.command."
fi

# Aviso suave para distros con musl (Alpine): Claude Code oficial pide glibc.
if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
  aviso "Tu sistema usa musl (p. ej. Alpine). Claude Code oficial está pensado para glibc."
  info  "Puede que necesites una distro basada en glibc (Ubuntu, Debian, Fedora, etc.)."
fi

if ! command -v curl >/dev/null 2>&1; then
  error "No se encontró 'curl' (necesario para instalar)."
  info  "Instálalo y reintenta. Ejemplos:"
  info  "    Debian/Ubuntu:  sudo apt install curl"
  info  "    Fedora:         sudo dnf install curl"
  info  "    Arch:           sudo pacman -S curl"
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
  asegurar_path_en "$HOME/.bashrc"
  asegurar_path_en "$HOME/.zshrc"
  asegurar_path_en "$HOME/.profile"
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
  error "Cierra esta terminal, abre una NUEVA y prueba:  claude --version"
  info  "Si sigue sin funcionar:  source ~/.bashrc   (o ~/.zshrc) y reintenta."
  exit 1
fi
ok "Claude Code instalado correctamente: $VER_OUT"

# ---------------------------------------------------------------------------
# 5) Modo avanzado (saltar permisos): ahora se elige POR SESIÓN en el hub.
# ---------------------------------------------------------------------------
# El Centro de Mando ofrece [N] sesión normal y [A] sesión avanzada
# (--dangerously-skip-permissions); ya no se hornea un flag global aquí.

# ---------------------------------------------------------------------------
# 6) Lanzador "Claude Terminal": script + ícono (.desktop) con menú de carpeta
# ---------------------------------------------------------------------------
# Ícono de la mascota: PNG embebido en base64 (autocontenible, funciona en
# 'curl | bash' sin archivos locales). En Linux el ícono se aplica vía el
# archivo .desktop (campo Icon=), no hace falta nada extra.
# (El blob lo inyecta assets/embed-icons.py desde assets/claude-terminal.png.b64.)
ICON_PNG_B64='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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGLn/j+o2S3KFTT4VgAAAABJRU5ErkJggg=='

titulo "Creando el lanzador 'Claude Terminal'"

CLAUDE_ABS="$(command -v claude || echo "$CLAUDE_BIN")"
mkdir -p "$BIN_DIR" 2>/dev/null || true

# 6a) Script lanzador (~/.local/bin/claude-terminal): el CENTRO DE MANDO.
# Cabecera EOF (expandida) que hornea la ruta del binario + cuerpo del hub
# en un heredoc LITERAL <<'MENU' (bash tal cual).
cat > "$LAUNCHER_SCRIPT" <<EOF
#!/bin/bash
CLAUDE_BIN_BAKED="$CLAUDE_ABS"
EOF
cat >> "$LAUNCHER_SCRIPT" <<'MENU'
# Claude Terminal — Centro de Mando (generado por claude-cmd).
# Abre tu panel: lanza, observa y cierra sesiones de Claude Code.
export PATH="$HOME/.local/bin:$PATH"

# ---- Estado / registro de sesiones ----
STATE_DIR="$HOME/.local/state/claude-cmd"
SESS_DIR="$STATE_DIR/sessions"
RUN_DIR="$STATE_DIR/runners"
STATE_FILE="$STATE_DIR/lastdir"
GRACE_CLOSE=10   # seg. que una sesión cerrada sigue visible antes de auto-borrarse
mkdir -p "$SESS_DIR" "$RUN_DIR" 2>/dev/null || true
chmod 700 "$STATE_DIR" "$SESS_DIR" "$RUN_DIR" 2>/dev/null || true

# ---- Colores (degradan a vacío si no hay terminal con color) ----
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RESET="$(tput sgr0)"; C_BOLD="$(tput bold)"; C_DIM="$(tput dim)"
  C_GREEN="$(tput setaf 2)"; C_RED="$(tput setaf 1)"; C_YEL="$(tput setaf 3)"
  C_CYAN="$(tput setaf 6)"; C_MAG="$(tput setaf 5)"
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_GREEN=""; C_RED=""; C_YEL=""; C_CYAN=""; C_MAG=""
fi

# ---- Geometría del panel (caja de 70 cols + sangría de 2) ----
IND="  "
_repeat() { local n="$1" c="$2" o=''; while [ "$n" -gt 0 ]; do o="$o$c"; n=$((n-1)); done; printf '%s' "$o"; }
EQ68="$(_repeat 68 '=')"; DSH68="$(_repeat 68 '-')"; DSH66="$(_repeat 66 '-')"

_top()  { printf '%s+%s+\n' "$IND" "$EQ68"; }
_bot()  { printf '%s+%s+\n' "$IND" "$EQ68"; }
_div()  { printf '%s+%s+\n' "$IND" "$DSH68"; }
_isep() { printf '%s| %s |\n' "$IND" "$DSH66"; }

_left() {
  local v="$1" c="${2:-$1}" len pad
  len=${#v}
  if [ "$len" -gt 66 ]; then v="${v:0:65}…"; c="$v"; len=66; fi
  pad=$((66 - len)); [ "$pad" -lt 0 ] && pad=0
  printf '%s| %s%*s |\n' "$IND" "$c" "$pad" ''
}
_center() {
  local v="$1" c="${2:-$1}" len l r
  len=${#v}
  if [ "$len" -gt 66 ]; then v="${v:0:65}…"; c="$v"; len=66; fi
  l=$(( (66 - len) / 2 )); r=$(( 66 - len - l ))
  printf '%s| %*s%s%*s |\n' "$IND" "$l" '' "$c" "$r" ''
}
_cell() {
  local w="$1" t="$2" col="$3" len pad
  len=${#t}
  if [ "$len" -gt "$w" ]; then t="${t:0:$((w-1))}…"; len="$w"; fi
  pad=$((w - len)); [ "$pad" -lt 0 ] && pad=0
  printf '%s%s%s%*s' "$col" "$t" "$C_RESET" "$pad" ''
}
_hk() { printf '[%s%s%s]' "$C_CYAN$C_BOLD" "$1" "$C_RESET"; }

# ---- Utilidades de registro ----
dir_xdg() { # $1=DESKTOP|DOCUMENTS|DOWNLOAD   $2=respaldo
  local d=""
  if command -v xdg-user-dir >/dev/null 2>&1; then d="$(xdg-user-dir "$1" 2>/dev/null)"; fi
  if [ -n "$d" ] && [ "$d" != "$HOME" ]; then printf '%s' "$d"; else printf '%s' "$2"; fi
}
_limpiar_ruta() {
  local s="$1"
  s="${s#\"}"; s="${s%\"}"
  s="${s#\'}"; s="${s%\'}"
  s="${s#file://}"
  s="${s//\\ / }"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}
elegir_grafico() {
  if command -v zenity >/dev/null 2>&1; then
    zenity --file-selection --directory --title="Elige la carpeta para abrir Claude Code" 2>/dev/null
  elif command -v kdialog >/dev/null 2>&1; then
    kdialog --getexistingdirectory "$HOME" 2>/dev/null
  else
    return 2
  fi
}
_escribir() {
  local f="$1" tmp="$1.tmp.$$"
  cat > "$tmp" 2>/dev/null && mv -f "$tmp" "$f" 2>/dev/null
}
# Marca (o limpia) la hora de cierre en el archivo de sesión, de forma atómica.
_stamp_closed() {
  local f="$1" t="$2" tmp="$1.tmp.$$"
  { grep -v '^CLOSED_AT=' "$f" 2>/dev/null; printf 'CLOSED_AT=%s\n' "$t"; } > "$tmp" 2>/dev/null && mv -f "$tmp" "$f" 2>/dev/null
}
_get() {
  local f="$1" k="$2" line
  [ -f "$f" ] || return 1
  line="$(grep -m1 "^$k=" "$f" 2>/dev/null)" || return 1
  printf '%s' "${line#*=}"
}
_vivo() {
  case "$1" in ''|*[!0-9]*) return 1;; esac
  kill -0 "$1" 2>/dev/null
}

# ---- Escaneo de sesiones ----
_scan() {
  SESS_IDX=(); ROW_N=(); ROW_BADGE=(); ROW_BCOL=(); ROW_MODO=(); ROW_MCOL=(); ROW_FOLDER=(); ROW_PID=()
  SES_TOT=0; SES_ACT=0; SES_CLS=0
  local f n=0 pid folder estado modo now st age badge badgecol modocol fdisp closed_at sid finished
  now="$(date +%s)"
  for f in "$SESS_DIR"/*.session; do
    [ -e "$f" ] || continue
    pid="$(_get "$f" PID)"; folder="$(_get "$f" FOLDER)"; estado="$(_get "$f" STATUS)"; modo="$(_get "$f" MODE)"
    st="$(_get "$f" START)"; age=$(( now - ${st:-$now} ))
    finished=0
    if _vivo "$pid"; then
      badge="[ACTIVA]"; badgecol="$C_GREEN$C_BOLD"
    elif [ "$estado" = "launching" ] && [ "$age" -le 3 ]; then
      badge="[INICIANDO]"; badgecol="$C_YEL"
    else
      finished=1
      if [ "$estado" = "launching" ]; then badge="[FALLO]"; badgecol="$C_YEL$C_BOLD"; else badge="[CERRADA]"; badgecol="$C_DIM"; fi
    fi
    # Auto-borrado: una sesión terminada se sella con CLOSED_AT y, pasada la gracia, se elimina sola.
    if [ "$finished" = "1" ]; then
      closed_at="$(_get "$f" CLOSED_AT)"
      case "$closed_at" in ''|*[!0-9]*) closed_at="$now"; _stamp_closed "$f" "$now" ;; esac
      if [ $(( now - closed_at )) -gt "$GRACE_CLOSE" ]; then
        sid="$(basename "$f" .session)"; rm -f "$f" "$RUN_DIR/$sid.sh" 2>/dev/null; continue
      fi
      SES_CLS=$((SES_CLS+1))
    elif [ "$badge" = "[ACTIVA]" ]; then
      SES_ACT=$((SES_ACT+1))
    fi
    n=$((n+1)); SESS_IDX[$n]="$f"
    if [ "$modo" = "avanzada" ]; then modocol="$C_MAG"; else modo="normal"; modocol="$C_DIM"; fi
    fdisp="${folder/#$HOME/~}"
    ROW_N[$n]="$n"; ROW_BADGE[$n]="$badge"; ROW_BCOL[$n]="$badgecol"
    ROW_MODO[$n]="$modo"; ROW_MCOL[$n]="$modocol"; ROW_FOLDER[$n]="$fdisp"; ROW_PID[$n]="${pid:--}"
  done
  SES_TOT=$n
}

_panel() {
  _scan
  clear 2>/dev/null || true
  _top
  _center "CLAUDE TERMINAL · CENTRO DE MANDO" "${C_BOLD}${C_CYAN}CLAUDE TERMINAL${C_RESET} ${C_DIM}·${C_RESET} ${C_BOLD}CENTRO DE MANDO${C_RESET}"
  _center "panel de control de sesiones" "${C_DIM}panel de control de sesiones${C_RESET}"
  _div
  local sb_plain sb_col
  sb_plain=" ESTADO DEL PANEL     Activas: ${SES_ACT}    Cerradas: ${SES_CLS}    Total: ${SES_TOT}"
  sb_col=" ${C_BOLD}ESTADO DEL PANEL${C_RESET}     ${C_GREEN}Activas: ${SES_ACT}${C_RESET}    ${C_RED}Cerradas: ${SES_CLS}${C_RESET}    Total: ${SES_TOT}"
  _left "$sb_plain" "$sb_col"
  _div
  _left " SESIONES" " ${C_BOLD}SESIONES${C_RESET}"
  _isep
  local hN hE hM hF hP
  hN="$(_cell 3 'No.' "$C_DIM")"; hE="$(_cell 11 'ESTADO' "$C_DIM")"; hM="$(_cell 8 'MODO' "$C_DIM")"
  hF="$(_cell 33 'CARPETA' "$C_DIM")"; hP="$(_cell 7 'PID' "$C_DIM")"
  printf '%s| %s %s %s %s %s |\n' "$IND" "$hN" "$hE" "$hM" "$hF" "$hP"
  _isep
  _print_rows
  _div
  _left " ACCIONES" " ${C_BOLD}ACCIONES${C_RESET}"
  _isep
  _left "  [N] Nueva sesion      [A] Nueva avanzada    [R] Refrescar" \
        "  $(_hk N) Nueva sesion      $(_hk A) Nueva avanzada    $(_hk R) Refrescar"
  _left "  [C] Cerrar una        [X] Cerrar todas     [L] Limpiar cerradas" \
        "  $(_hk C) Cerrar una        $(_hk X) Cerrar todas     $(_hk L) Limpiar cerradas"
  _left "  [S] Salir" "  $(_hk S) Salir"
  _div
  _center "Creado por @soy Enrique Rocha" "${C_DIM}${C_MAG}Creado por @soy Enrique Rocha${C_RESET}"
  _bot
}

_print_rows() {
  if [ "$SES_TOT" -eq 0 ]; then
    _left "  sin sesiones todavia — pulsa [N] para abrir la primera" \
          "  ${C_DIM}sin sesiones todavia — pulsa [N] para abrir la primera${C_RESET}"
    return
  fi
  local i nC eC mC fC pC
  i=1
  while [ "$i" -le "$SES_TOT" ]; do
    nC="$(_cell 3 "${ROW_N[$i]}" "$C_DIM")"
    eC="$(_cell 11 "${ROW_BADGE[$i]}" "${ROW_BCOL[$i]}")"
    mC="$(_cell 8 "${ROW_MODO[$i]}" "${ROW_MCOL[$i]}")"
    fC="$(_cell 33 "${ROW_FOLDER[$i]}" "")"
    pC="$(_cell 7 "${ROW_PID[$i]}" "$C_DIM")"
    printf '%s| %s %s %s %s %s |\n' "$IND" "$nC" "$eC" "$mC" "$fC" "$pC"
    i=$((i+1))
  done
}

_mini() {
  clear 2>/dev/null || true
  _top
  _center "CLAUDE TERMINAL · CENTRO DE MANDO" "${C_BOLD}${C_CYAN}CLAUDE TERMINAL${C_RESET} ${C_DIM}·${C_RESET} ${C_BOLD}CENTRO DE MANDO${C_RESET}"
  _center "$1" "${C_DIM}$1${C_RESET}"
  _bot
}

# ---- Selector de carpeta (fija DESTINO; 1 = volver) ----
elegir_carpeta() {
  DESTINO=""
  local ULTIMA="" ELECCION elegida escrita rc
  local DIR_ESCRITORIO DIR_DOCUMENTOS DIR_DESCARGAS
  DIR_ESCRITORIO="$(dir_xdg DESKTOP   "$HOME/Desktop")"
  DIR_DOCUMENTOS="$(dir_xdg DOCUMENTS "$HOME/Documents")"
  DIR_DESCARGAS="$(dir_xdg DOWNLOAD  "$HOME/Downloads")"
  [ -f "$STATE_FILE" ] && ULTIMA="$(cat "$STATE_FILE" 2>/dev/null)"
  if [ -n "$ULTIMA" ] && [ ! -d "$ULTIMA" ]; then ULTIMA=""; fi
  while :; do
    _mini "elegir carpeta para la nueva sesion"
    echo
    printf "    %s[Enter]%s  Tu carpeta personal\n" "$C_BOLD" "$C_RESET"
    printf "       %s1%s     Escritorio\n" "$C_CYAN" "$C_RESET"
    printf "       %s2%s     Documentos\n" "$C_CYAN" "$C_RESET"
    printf "       %s3%s     Descargas\n" "$C_CYAN" "$C_RESET"
    printf "       %s4%s     Elegir una carpeta…  (selector gráfico)\n" "$C_CYAN" "$C_RESET"
    printf "       %s5%s     Escribir o pegar una carpeta\n" "$C_CYAN" "$C_RESET"
    [ -n "$ULTIMA" ] && printf "       %s6%s     Última usada:  %s\n" "$C_CYAN" "$C_RESET" "$ULTIMA"
    printf "       %sv%s     Volver al panel\n" "$C_CYAN" "$C_RESET"
    echo
    printf "  %sTu elección%s %s>%s " "$C_BOLD" "$C_RESET" "$C_GREEN$C_BOLD" "$C_RESET"
    read -r ELECCION || return 1
    case "$ELECCION" in
      "")  DESTINO="$HOME" ;;
      1)   DESTINO="$DIR_ESCRITORIO" ;;
      2)   DESTINO="$DIR_DOCUMENTOS" ;;
      3)   DESTINO="$DIR_DESCARGAS" ;;
      4)
        elegida="$(elegir_grafico)"; rc=$?
        if [ "$rc" -eq 2 ]; then
          echo; echo "  No hay selector gráfico (instala 'zenity' o 'kdialog'). Usa la opción 5."; sleep 2; continue
        fi
        elegida="$(_limpiar_ruta "$elegida")"
        if [ -n "$elegida" ] && [ -d "$elegida" ]; then DESTINO="$elegida"; else continue; fi
        ;;
      5)
        printf "  Escribe o pega la carpeta y pulsa Enter: "
        read -r escrita
        escrita="$(_limpiar_ruta "$escrita")"
        case "$escrita" in "~") escrita="$HOME";; "~/"*) escrita="$HOME/${escrita#\~/}";; esac
        if [ -n "$escrita" ] && [ -d "$escrita" ]; then DESTINO="$escrita"; else echo "  No encontré esa carpeta."; sleep 1; continue; fi
        ;;
      6)
        if [ -n "$ULTIMA" ] && [ -d "$ULTIMA" ]; then DESTINO="$ULTIMA"; else continue; fi
        ;;
      v|V) return 1 ;;
      *)   continue ;;
    esac
    break
  done
  if [ -z "$DESTINO" ] || [ ! -d "$DESTINO" ]; then DESTINO="$HOME"; fi
  mkdir -p "$STATE_DIR" 2>/dev/null && printf '%s\n' "$DESTINO" > "$STATE_FILE" 2>/dev/null
  return 0
}

# ---- Abrir el runner en una ventana nueva del emulador disponible ----
abrir_ventana() {
  local runner="$1"
  [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ] || return 1
  if   command -v gnome-terminal >/dev/null 2>&1; then nohup gnome-terminal -- bash "$runner" >/dev/null 2>&1 &
  elif command -v konsole        >/dev/null 2>&1; then nohup konsole -e bash "$runner" >/dev/null 2>&1 &
  elif command -v xfce4-terminal >/dev/null 2>&1; then nohup xfce4-terminal -x bash "$runner" >/dev/null 2>&1 &
  elif command -v kitty          >/dev/null 2>&1; then nohup kitty bash "$runner" >/dev/null 2>&1 &
  elif command -v alacritty      >/dev/null 2>&1; then nohup alacritty -e bash "$runner" >/dev/null 2>&1 &
  elif command -v tilix          >/dev/null 2>&1; then nohup tilix -e bash "$runner" >/dev/null 2>&1 &
  elif command -v mate-terminal  >/dev/null 2>&1; then nohup mate-terminal -- bash "$runner" >/dev/null 2>&1 &
  elif command -v x-terminal-emulator >/dev/null 2>&1; then nohup x-terminal-emulator -e bash "$runner" >/dev/null 2>&1 &
  elif command -v xterm          >/dev/null 2>&1; then nohup xterm -e bash "$runner" >/dev/null 2>&1 &
  else return 1
  fi
  return 0
}

# ---- Lanzar una sesión en una ventana nueva. $1 = normal|avanzada. Usa DESTINO. ----
spawn_sesion() {
  local modo="$1" destino="$DESTINO" sid sessf runner flag=""
  sid="$(date +%s)-$$-$RANDOM"
  sessf="$SESS_DIR/$sid.session"
  runner="$RUN_DIR/$sid.sh"
  [ "$modo" = "avanzada" ] && flag=" --dangerously-skip-permissions"

  _escribir "$sessf" <<SEED
PID=
FOLDER=$destino
START=$(date +%s)
STARTED_AT=
MODE=$modo
STATUS=launching
SEED

  cat > "$runner" <<RUNNER
#!/bin/bash
export PATH="\$HOME/.local/bin:\$PATH"
SESSF="$sessf"
FOLDER="\$(grep -m1 '^FOLDER=' "\$SESSF" 2>/dev/null)"; FOLDER="\${FOLDER#FOLDER=}"
cd "\$FOLDER" 2>/dev/null || cd "\$HOME"
clear 2>/dev/null || true
( while kill -0 \$\$ 2>/dev/null; do sleep 2; done
  T="\$SESSF.tmp.\$\$"
  sed 's/^STATUS=.*/STATUS=closed/' "\$SESSF" > "\$T" 2>/dev/null && mv -f "\$T" "\$SESSF" 2>/dev/null
) >/dev/null 2>&1 &
ARR="\$(date +%s)"
LSTART="\$(ps -o lstart= -p \$\$ 2>/dev/null | tr -s ' ')"
T="\$SESSF.tmp.\$\$"
{
  printf 'PID=%s\n' "\$\$"
  printf 'FOLDER=%s\n' "\$FOLDER"
  printf 'START=%s\n' "\$ARR"
  printf 'STARTED_AT=%s\n' "\$LSTART"
  printf 'MODE=%s\n' "$modo"
  printf 'STATUS=running\n'
} > "\$T" 2>/dev/null && mv -f "\$T" "\$SESSF" 2>/dev/null
echo "  Claude Code — sesión activa"
echo "  (para salir escribe /exit o pulsa Ctrl+C)"
echo
exec "$CLAUDE_BIN_BAKED"$flag
RUNNER
  chmod +x "$runner" 2>/dev/null || true

  if abrir_ventana "$runner"; then
    printf "\n  %s✔%s Abriendo Claude en una ventana nueva — %s\n" "$C_GREEN" "$C_RESET" "$destino"; sleep 1
    return 0
  fi
  echo; echo "  No pude abrir una ventana separada (sin entorno gráfico o sin"
  echo "  un emulador conocido). Abro Claude aquí mismo."; sleep 1
  rm -f "$sessf" "$runner" 2>/dev/null
  cd "$destino" 2>/dev/null || cd "$HOME" 2>/dev/null || cd /
  "$CLAUDE_BIN_BAKED"$flag
  return 0
}

cerrar_sesion() {
  if [ "${SES_TOT:-0}" -eq 0 ]; then echo "  No hay sesiones."; sleep 1; return; fi
  local num f pid saved cur i=0
  printf "  %sNº a cerrar%s (Enter = cancelar) %s>%s " "$C_BOLD" "$C_RESET" "$C_GREEN$C_BOLD" "$C_RESET"
  read -r num
  [ -z "$num" ] && return
  case "$num" in *[!0-9]*) echo "  Número inválido."; sleep 1; return;; esac
  f="${SESS_IDX[$num]:-}"
  if [ -z "$f" ] || [ ! -f "$f" ]; then echo "  Número inválido."; sleep 1; return; fi
  pid="$(_get "$f" PID)"
  case "$pid" in ''|*[!0-9]*) echo "  Esa sesión aún se está iniciando (sin PID)."; sleep 1; return;; esac
  saved="$(_get "$f" STARTED_AT)"
  cur="$(ps -o lstart= -p "$pid" 2>/dev/null | tr -s ' ')"
  if [ -n "$saved" ] && [ -n "$cur" ] && [ "$saved" != "$cur" ]; then
    echo "  Ese proceso cambió (PID reciclado). No cierro nada."; sleep 1; return
  fi
  kill "$pid" 2>/dev/null
  while [ $i -lt 5 ] && kill -0 "$pid" 2>/dev/null; do sleep 1; i=$((i+1)); done
  kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
  printf "  %s✔%s Sesión cerrada.\n" "$C_GREEN" "$C_RESET"; sleep 1
}

cerrar_todas() {
  if [ "${SES_TOT:-0}" -eq 0 ]; then echo "  No hay sesiones."; sleep 1; return; fi
  local r f pid
  printf "  ¿Cerrar %sTODAS%s las sesiones activas? [s/N] " "$C_BOLD" "$C_RESET"
  read -r r
  case "$r" in [sS]*) ;; *) return;; esac
  for f in "$SESS_DIR"/*.session; do
    [ -e "$f" ] || continue
    pid="$(_get "$f" PID)"
    case "$pid" in ''|*[!0-9]*) continue;; esac
    kill "$pid" 2>/dev/null
  done
  echo "  Listo."; sleep 1
}

limpiar_cerradas() {
  local f pid estado sid now start age
  now="$(date +%s)"
  for f in "$SESS_DIR"/*.session; do
    [ -e "$f" ] || continue
    pid="$(_get "$f" PID)"; estado="$(_get "$f" STATUS)"
    start="$(_get "$f" START)"; age=$(( now - ${start:-$now} ))
    if ! _vivo "$pid" && ! { [ "$estado" = "launching" ] && [ "$age" -le 3 ]; }; then
      sid="$(basename "$f" .session)"
      rm -f "$f" "$RUN_DIR/$sid.sh" 2>/dev/null
    fi
  done
  printf "  %s✔%s Registro limpio.\n" "$C_GREEN" "$C_RESET"; sleep 1
}

# Poda agresiva al arrancar/salir: borra todo lo terminado (protege lo que recién arranca).
cleanup() {
  local f pid estado start now age sid
  now="$(date +%s)"
  for f in "$SESS_DIR"/*.session; do
    [ -e "$f" ] || continue
    pid="$(_get "$f" PID)"; estado="$(_get "$f" STATUS)"
    start="$(_get "$f" START)"; age=$(( now - ${start:-$now} ))
    if ! _vivo "$pid" && ! { [ "$estado" = "launching" ] && [ "$age" -le 3 ]; }; then
      sid="$(basename "$f" .session)"
      rm -f "$f" "$RUN_DIR/$sid.sh" 2>/dev/null
    fi
  done
}

salir() {
  local vivas=0 f pid r
  for f in "$SESS_DIR"/*.session; do
    [ -e "$f" ] || continue
    pid="$(_get "$f" PID)"
    _vivo "$pid" && vivas=$((vivas+1))
  done
  if [ "$vivas" -gt 0 ]; then
    echo
    printf "  Hay %s sesión(es) activa(s). ¿Cerrarlas al salir? [s/N] " "$vivas"
    read -r r
    case "$r" in
      [sS]*)
        for f in "$SESS_DIR"/*.session; do
          [ -e "$f" ] || continue
          pid="$(_get "$f" PID)"
          case "$pid" in ''|*[!0-9]*) continue;; esac
          kill "$pid" 2>/dev/null
        done ;;
      *) echo "  Las dejo abiertas (aparecerán al volver a abrir el Centro de Mando)."; sleep 1 ;;
    esac
  fi
  clear 2>/dev/null || true
  exit 0
}

hub_loop() {
  trap cleanup EXIT
  cleanup
  local OP
  while :; do
    _panel
    echo
    printf "  %sAcción%s %s>%s " "$C_BOLD" "$C_RESET" "$C_GREEN$C_BOLD" "$C_RESET"
    read -r OP || salir
    case "$OP" in
      n|N) if elegir_carpeta; then spawn_sesion "normal";   fi ;;
      a|A) if elegir_carpeta; then spawn_sesion "avanzada"; fi ;;
      r|R) : ;;
      c|C) cerrar_sesion ;;
      x|X) cerrar_todas ;;
      l|L) limpiar_cerradas ;;
      s|S) salir ;;
      *)   : ;;
    esac
  done
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  hub_loop
fi
MENU
chmod +x "$LAUNCHER_SCRIPT" 2>/dev/null || true
ok "Centro de Mando creado: ~/.local/bin/claude-terminal"

# 6b) Ícono (.desktop) para el menú de aplicaciones (y el Escritorio si existe).
# Solo tiene sentido si hay entorno gráfico; en servidores/WSL sin GUI se omite.
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
  # Escribir el PNG de la mascota.
  if [ -n "$ICON_PNG_B64" ] && ! printf '%s' "$ICON_PNG_B64" | grep -q '__ICONO'; then
    mkdir -p "$ICON_DIR" 2>/dev/null || true
    if printf '%s' "$ICON_PNG_B64" | { base64 -d 2>/dev/null || base64 -D 2>/dev/null; } > "$ICON_PATH" 2>/dev/null && [ -s "$ICON_PATH" ]; then
      ICON_REF="$ICON_PATH"
    else
      ICON_REF="utilities-terminal"   # ícono genérico del sistema como respaldo
    fi
  else
    ICON_REF="utilities-terminal"
  fi

  mkdir -p "$APPS_DIR" 2>/dev/null || true
  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Claude Terminal
GenericName=Claude Code
Comment=Centro de Mando de Claude Code (lanza y gestiona sesiones)
Exec=$LAUNCHER_SCRIPT
Icon=$ICON_REF
Terminal=true
Categories=Development;Utility;
Keywords=claude;ai;code;terminal;
EOF
  chmod +x "$DESKTOP_FILE" 2>/dev/null || true
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
  ok "Ícono 'Claude Terminal' añadido al menú de aplicaciones."

  # Copiar también al Escritorio si existe (respeta nombre localizado).
  DESKTOP_DIR=""
  if command -v xdg-user-dir >/dev/null 2>&1; then DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null)"; fi
  [ -n "$DESKTOP_DIR" ] && [ "$DESKTOP_DIR" != "$HOME" ] || DESKTOP_DIR="$HOME/Desktop"
  if [ -d "$DESKTOP_DIR" ]; then
    cp -f "$DESKTOP_FILE" "$DESKTOP_DIR/claude-terminal.desktop" 2>/dev/null || true
    chmod +x "$DESKTOP_DIR/claude-terminal.desktop" 2>/dev/null || true
    # GNOME exige marcar el lanzador como "de confianza" para mostrarlo.
    gio set "$DESKTOP_DIR/claude-terminal.desktop" metadata::trusted true >/dev/null 2>&1 || true
    info "También lo dejé en tu Escritorio."
  fi
else
  info "Sin entorno gráfico (servidor/WSL): omito el ícono. Usa el comando de abajo."
fi

# ---------------------------------------------------------------------------
# 7) Resumen
# ---------------------------------------------------------------------------
titulo "¡Listo!"
ok "Claude Code está instalado y verificado."
printf "\n"
info "Cómo abrirlo:"
info "  • Busca 'Claude Terminal' en tu menú de aplicaciones (si hay escritorio), o"
info "  • Escribe en una terminal NUEVA:  claude-terminal   (abre tu Centro de Mando), o"
info "  • Escribe simplemente:  claude"
printf "\n"
aviso "La primera vez, Claude abrirá tu navegador para iniciar sesión."
info  "Necesitas una cuenta Claude Pro, Max, Team o Enterprise (el plan gratis no incluye Claude Code)."
printf "\n"
info "Si 'claude' no aparece en una terminal que ya tenías abierta, ciérrala y abre una nueva."

exit 0
