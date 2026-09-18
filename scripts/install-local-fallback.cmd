@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-local-fallback.ps1" %*
