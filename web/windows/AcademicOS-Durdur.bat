@echo off
chcp 65001 >nul
title AcademicOS - Durdur
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0durdur.ps1"
echo.
pause
