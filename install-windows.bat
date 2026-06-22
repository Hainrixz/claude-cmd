@echo off
REM ============================================================================
REM  install-windows.bat  -  Instalador "un clic" de Claude Code para Windows
REM  Repo: https://github.com/Hainrixz/claude-cmd
REM
REM  Doble clic en este archivo. Si Windows muestra SmartScreen:
REM     "Mas informacion" -> "Ejecutar de todas formas".
REM
REM  Este envoltorio arranca PowerShell con -ExecutionPolicy Bypass a nivel de
REM  PROCESO (no persiste, no requiere admin) y ejecuta install-windows.ps1.
REM  Si el .ps1 no esta al lado, lo descarga desde GitHub a una carpeta temporal.
REM ============================================================================

setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

echo.
echo ============================================================
echo    Instalador de Claude Code para Windows
echo ============================================================
echo.

set "PS1_LOCAL=%~dp0install-windows.ps1"
set "PS1_URL=https://raw.githubusercontent.com/Hainrixz/claude-cmd/main/install-windows.ps1"
set "PS1_TEMP=%TEMP%\claude-cmd-install-windows.ps1"
set "RC=0"

if exist "%PS1_LOCAL%" (
    echo Ejecutando el instalador local...
    echo.
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1_LOCAL%"
    set "RC=!ERRORLEVEL!"
    goto :done
)

echo No se encontro install-windows.ps1 junto a este archivo.
echo Descargandolo desde GitHub...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -UseBasicParsing -Uri '%PS1_URL%' -OutFile '%PS1_TEMP%' } catch { Write-Host 'Error al descargar el instalador.' -ForegroundColor Red; exit 1 }"

if not exist "%PS1_TEMP%" (
    echo.
    echo No se pudo descargar el instalador. Revisa tu conexion a internet.
    set "RC=1"
    goto :done
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1_TEMP%"
set "RC=!ERRORLEVEL!"

:done
echo.
if "!RC!"=="0" (
    echo ============================================================
    echo    Proceso finalizado.
    echo ============================================================
) else (
    echo ============================================================
    echo    El instalador termino con avisos o errores ^(codigo !RC!^).
    echo    Revisa los mensajes de arriba.
    echo ============================================================
)
echo.
pause
endlocal & exit /b %RC%
