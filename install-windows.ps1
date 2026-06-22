#Requires -Version 5.1
<#
.SYNOPSIS
    Instalador "un clic" de Claude Code para Windows.
.DESCRIPTION
    - Ejecuta el instalador NATIVO oficial de Claude Code (irm install.ps1 | iex).
    - Asegura que %USERPROFILE%\.local\bin este en el PATH de usuario (solo si falta).
    - Verifica con 'claude --version' usando la ruta absoluta.
    - Crea un icono "Claude Terminal" en el Escritorio que abre una terminal
      nueva ejecutando el binario por su ruta absoluta (funciona de inmediato).
    - Es idempotente. Mensajes en espanol. No requiere administrador.
.NOTES
    Repo: https://github.com/Hainrixz/claude-cmd
    Modo avanzado (saltar permisos): se pregunta de forma interactiva, o se activa
    con la variable de entorno CLAUDE_CMD_SKIP_PERMS=1.
#>

$ErrorActionPreference = 'Stop'

# TLS 1.2 (requerido para descargar desde downloads.claude.ai) + UTF-8 en consola
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# Rutas clave
$ClaudeBinDir = Join-Path $env:USERPROFILE '.local\bin'
$ClaudeExe    = Join-Path $ClaudeBinDir 'claude.exe'
$DownloadsDir = Join-Path $env:USERPROFILE '.claude\downloads'

# Helpers de mensajes
function Write-Paso  { param([string]$m) Write-Host "`n=> $m" -ForegroundColor Cyan }
function Write-Ok    { param([string]$m) Write-Host "   [OK] $m" -ForegroundColor Green }
function Write-Aviso { param([string]$m) Write-Host "   [AVISO] $m" -ForegroundColor Yellow }
function Write-ErrMsg{ param([string]$m) Write-Host "   [ERROR] $m" -ForegroundColor Red }
function Write-Info  { param([string]$m) Write-Host "   $m" -ForegroundColor Gray }

Write-Host ""
Write-Host "  ===================================================" -ForegroundColor White
Write-Host "    Claude Code - Instalador para Windows (claude-cmd)" -ForegroundColor White
Write-Host "  ===================================================" -ForegroundColor White

# ---------------------------------------------------------------------------
# 0. Requisito: PowerShell de 64 bits
# ---------------------------------------------------------------------------
if (-not [Environment]::Is64BitProcess) {
    Write-ErrMsg "Estas usando PowerShell de 32 bits. Claude Code necesita 64 bits."
    Write-Info  "Abre 'Windows PowerShell' (no la version (x86)) y vuelve a intentarlo."
    exit 1
}

# ---------------------------------------------------------------------------
# 1. Instalador oficial nativo (idempotente)
# ---------------------------------------------------------------------------
Write-Paso "Paso 1 de 4: Instalando Claude Code (instalador oficial)..."

if (Test-Path $ClaudeExe) {
    Write-Info "Ya existe una instalacion previa. Se actualizara/reparara si hace falta."
}

# Limpiar carpeta de descargas si quedo bloqueada por antivirus (reintento limpio)
if (Test-Path $DownloadsDir) {
    try {
        Remove-Item -Recurse -Force $DownloadsDir -ErrorAction Stop
        Write-Info "Carpeta temporal de descargas limpiada."
    } catch {
        Write-Aviso "No se pudo limpiar la carpeta temporal de descargas (puede estar en uso por el antivirus)."
    }
}

try {
    Write-Info "Descargando y ejecutando el instalador oficial de Anthropic..."
    $installScript = Invoke-RestMethod -Uri 'https://claude.ai/install.ps1' -UseBasicParsing
    & ([scriptblock]::Create($installScript))
    Write-Ok "Instalador oficial ejecutado."
} catch {
    Write-Aviso "El instalador oficial reporto un problema: $($_.Exception.Message)"
    if (Test-Path $ClaudeExe) {
        Write-Info "El binario de Claude ya existe en disco. Continuamos."
    } else {
        Write-ErrMsg "No se pudo instalar Claude Code."
        Write-Info  "Posibles causas: sin internet, firewall corporativo, o antivirus bloqueando."
        Write-Info  "Puedes anadir una exclusion del antivirus para:  $ClaudeBinDir"
        Write-Info  "y volver a ejecutar este instalador."
        exit 1
    }
}

# ---------------------------------------------------------------------------
# 2. PATH de usuario (el instalador es el dueno; anadimos solo si falta)
# ---------------------------------------------------------------------------
Write-Paso "Paso 2 de 4: Configurando el PATH..."

if (-not (Test-Path $ClaudeExe)) {
    Write-ErrMsg "No se encontro claude.exe en: $ClaudeExe"
    Write-Info  "La instalacion no se completo correctamente."
    exit 1
}

$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($null -eq $userPath) { $userPath = '' }
$yaEnPath = ($userPath -split ';' | Where-Object { $_ -ne '' } |
             Where-Object { $_.TrimEnd('\') -ieq $ClaudeBinDir.TrimEnd('\') })

if ($yaEnPath) {
    Write-Ok "La carpeta de Claude ya esta en tu PATH de usuario."
} else {
    try {
        $nuevoPath = if ($userPath.TrimEnd(';') -eq '') { $ClaudeBinDir } else { "$($userPath.TrimEnd(';'));$ClaudeBinDir" }
        [Environment]::SetEnvironmentVariable('PATH', $nuevoPath, 'User')
        Write-Ok "Se anadio Claude a tu PATH de usuario."
    } catch {
        Write-Aviso "No se pudo modificar el PATH automaticamente: $($_.Exception.Message)"
        Write-Info  "Anade manualmente esta ruta a tu PATH de usuario:  $ClaudeBinDir"
    }
}

# Anadir tambien a ESTA sesion para poder verificar ahora
if (($env:PATH -split ';') -notcontains $ClaudeBinDir) {
    $env:PATH = "$env:PATH;$ClaudeBinDir"
}

# ---------------------------------------------------------------------------
# 3. Verificacion: SOLO 'claude --version' (por ruta absoluta)
# ---------------------------------------------------------------------------
Write-Paso "Paso 3 de 4: Verificando la instalacion..."

$versionOK = $false
try {
    $version = (& $ClaudeExe --version 2>&1 | Out-String).Trim()
    if ($version) {
        Write-Ok "Claude Code instalado correctamente."
        Write-Info "Version: $version"
        $versionOK = $true
    }
} catch {
    Write-Aviso "No se pudo ejecutar 'claude --version' en esta sesion."
}

if (-not $versionOK) {
    Write-Aviso "Claude se instalo, pero no respondio en esta ventana."
    Write-Info  "Suele resolverse cerrando y abriendo de nuevo la terminal."
}

# ---------------------------------------------------------------------------
# 3b. Modo avanzado (saltar permisos): opcional
# ---------------------------------------------------------------------------
$skipArg = ''
if ($env:CLAUDE_CMD_SKIP_PERMS -eq '1') {
    $skipArg = ' --dangerously-skip-permissions'
} else {
    try {
        Write-Host ""
        Write-Info "Modo de apertura del icono:"
        Write-Info "  Normal (seguro): Claude pide confirmacion antes de acciones sensibles."
        Write-Info "  Avanzado: Claude actua sin pedir confirmacion (--dangerously-skip-permissions)."
        $resp = Read-Host "   Activar modo avanzado? (s/N)"
        if ($resp -match '^(s|si|sí|y|yes)$') {
            $skipArg = ' --dangerously-skip-permissions'
            Write-Aviso "Modo avanzado activado para el icono del Escritorio."
        } else {
            Write-Ok "Modo normal (seguro)."
        }
    } catch {
        Write-Ok "Modo normal (seguro)."
    }
}

# ---------------------------------------------------------------------------
# 4. Icono del Escritorio "Claude Terminal" (.lnk con ruta absoluta)
# ---------------------------------------------------------------------------
Write-Paso "Paso 4 de 4: Creando el icono en el Escritorio..."

# Desplegar el icono de la mascota (.ico embebido en base64) a una ruta PERSISTENTE
# (NO %TEMP%, que se limpia). El .lnk referencia el .ico por ruta, no lo incrusta.
# Si algo falla, se usa el icono del propio claude.exe como respaldo (nunca aborta).
# (El blob lo inyecta assets/embed-icons.py desde assets/claude-terminal.ico.b64.)
$IconBase64 = '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'
$iconRef = "$ClaudeExe,0"
if ($IconBase64) {
    try {
        $iconDir  = Join-Path $env:LOCALAPPDATA 'claude-cmd'
        $iconPath = Join-Path $iconDir 'claude-terminal.ico'
        New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
        [IO.File]::WriteAllBytes($iconPath, [Convert]::FromBase64String($IconBase64))
        if (Test-Path $iconPath) { $iconRef = "$iconPath,0" }
    } catch {
        Write-Info "(No se pudo preparar el icono personalizado; uso el icono por defecto.)"
    }
}

try {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnkPath = Join-Path $desktop 'Claude Terminal.lnk'

    $wsh = New-Object -ComObject WScript.Shell
    $sc  = $wsh.CreateShortcut($lnkPath)
    # cmd.exe /k "<ruta-abs-claude.exe>"  -> abre terminal nueva, ejecuta claude por ruta
    # absoluta (funciona antes del refresco de PATH) y mantiene la ventana abierta.
    $sc.TargetPath       = Join-Path $env:SystemRoot 'System32\cmd.exe'
    $sc.Arguments        = "/k `"`"$ClaudeExe`"$skipArg`""
    $sc.WorkingDirectory = $env:USERPROFILE
    $sc.IconLocation     = $iconRef
    $sc.WindowStyle      = 1
    $sc.Description      = 'Abrir Claude Code'
    $sc.Save()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null

    if (Test-Path $lnkPath) {
        Write-Ok "Icono creado: 'Claude Terminal' en tu Escritorio."
    } else {
        Write-Aviso "No se pudo confirmar la creacion del icono."
    }
} catch {
    Write-Aviso "No se pudo crear el icono: $($_.Exception.Message)"
    Write-Info  "Puedes abrir Claude escribiendo 'claude' en una terminal nueva."
}

# ---------------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  ===================================================" -ForegroundColor Green
Write-Host "    Todo listo!" -ForegroundColor Green
Write-Host "  ===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Como abrir Claude:" -ForegroundColor White
Write-Host "    1. Doble clic en 'Claude Terminal' en tu Escritorio (funciona ya)." -ForegroundColor White
Write-Host "    2. O escribe 'claude' en una terminal NUEVA." -ForegroundColor White
Write-Host ""
Write-Host "  IMPORTANTE: si ya tenias una terminal abierta, cierrala y abre una" -ForegroundColor Yellow
Write-Host "  nueva para que el comando 'claude' funcione." -ForegroundColor Yellow
Write-Host ""
Write-Host "  La primera vez, Claude abrira tu navegador para iniciar sesion" -ForegroundColor Gray
Write-Host "  (necesitas cuenta Pro, Max, Team o Enterprise)." -ForegroundColor Gray
Write-Host ""

exit 0
