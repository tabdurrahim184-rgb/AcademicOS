@echo off
chcp 65001 >nul
title AcademicOS
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0baslat.ps1"
if errorlevel 1 (
  echo.
  pause
  exit /b 1
)
timeout /t 10
