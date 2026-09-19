@echo off
setlocal
set "TOOLKIT_ROOT=%~dp0.."
rem Use the same installed global integration as Desktop. Loading this source
rem directory as well would register plugin hooks twice and bypass installed QA.
rem Quietly adapt to connected/free model changes before starting the TUI.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0refresh-routing.ps1" -NoRefresh -Quiet >nul 2>nul
opencode %*
