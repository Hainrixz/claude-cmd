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
    $sc.IconLocation     = "$ClaudeExe,0"
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
