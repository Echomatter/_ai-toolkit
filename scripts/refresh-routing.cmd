@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0refresh-routing.ps1" %*
