@echo off
setlocal
set "TOOLKIT_ROOT=%~dp0.."
set "OPENCODE_CONFIG=%TOOLKIT_ROOT%\opencode\opencode.jsonc"
set "OPENCODE_CONFIG_DIR=%TOOLKIT_ROOT%\opencode"
set "OPENCODE_ENABLE_EXA=1"
rem Quietly adapt to connected/free model changes before starting the TUI.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0refresh-routing.ps1" -NoRefresh -Quiet >nul 2>nul
opencode %*
