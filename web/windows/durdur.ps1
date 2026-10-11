# AcademicOS'u durdurur. Veriler (Docker birimi academicos_pgdata ve .env.docker) korunur.
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$WebDir = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $WebDir
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Write-Host '[HATA] Docker bulunamadı.' -ForegroundColor Red; exit 1 }
& docker info *> $null
if ($LASTEXITCODE -ne 0) { Write-Host '[AcademicOS] Docker çalışmıyor; AcademicOS zaten durmuş.' -ForegroundColor Cyan; exit 0 }
$ids = & docker ps -q --filter 'label=com.docker.compose.project=academicos'
if (-not $ids) { Write-Host '[AcademicOS] Zaten durmuş.' -ForegroundColor Cyan; exit 0 }
& docker stop $ids | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host '[HATA] Durdurulamadı. Docker Desktop''ı kontrol et.' -ForegroundColor Red; exit 1 }
Write-Host '[TAMAM] AcademicOS durduruldu. Verilerin korunuyor; yeniden açmak için AcademicOS-Baslat.bat.' -ForegroundColor Green
exit 0
