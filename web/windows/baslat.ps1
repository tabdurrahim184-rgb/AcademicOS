# AcademicOS — Windows 11 + Docker Desktop kurulum ve başlatma betiği.
# AcademicOS-Baslat.bat çift tıklanarak çalıştırılır. Verileri asla silmez (docker compose down -v kullanılmaz).
# Ücretli API kullanmaz: yapay zekâ ve deşifre ayarları boş bırakılır.

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Project = 'academicos'
$Volume = 'academicos_pgdata'
$Port = 3000
$StartUrl = "http://127.0.0.1:$Port/kayit"
$HealthUrl = "http://127.0.0.1:$Port/giris"
$WebDir = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $WebDir '.env.docker'
$BackupDir = Join-Path $env:LOCALAPPDATA 'AcademicOS'
$BackupFile = Join-Path $BackupDir '.env.docker.yedek'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Info($m) { Write-Host "[AcademicOS] $m" -ForegroundColor Cyan }
function Ok($m) { Write-Host "[TAMAM] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[UYARI] $m" -ForegroundColor Yellow }
function Fail($m) {
  Write-Host ''
  Write-Host "[HATA] $m" -ForegroundColor Red
  Write-Host 'Verilerin silinmedi. Sorunu giderip AcademicOS-Baslat.bat dosyasını yeniden çalıştırabilirsin.' -ForegroundColor Yellow
  exit 1
}

function Compose { & docker compose -p $Project --env-file $EnvFile @args }

function New-Secret([int]$Length) {
  $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $sb = New-Object System.Text.StringBuilder
  $buf = New-Object byte[] 1
  while ($sb.Length -lt $Length) {
    $rng.GetBytes($buf)
    # Eşit dağılım için 228'in (57*4) üstündeki baytlar atılır.
    if ($buf[0] -lt 228) { [void]$sb.Append($chars[$buf[0] % $chars.Length]) }
  }
  $rng.Dispose()
  return $sb.ToString()
}

function New-Key32 {
  $bytes = New-Object byte[] 32
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $rng.GetBytes($bytes); $rng.Dispose()
  return [Convert]::ToBase64String($bytes)
}

function Read-EnvFile([string]$Path) {
  $map = [ordered]@{}
  foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$') { $map[$Matches[1]] = $Matches[2].Trim() }
  }
  return $map
}

function Test-Key32([string]$Value) {
  try { return ([Convert]::FromBase64String($Value)).Length -eq 32 } catch { return $false }
}

Set-Location -LiteralPath $WebDir
Write-Host ''
Info "Klasör: $WebDir"

# 1) Docker Desktop
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Fail ("Docker bulunamadı. Docker Desktop'ı kur: https://www.docker.com/products/docker-desktop/`n" +
        "       Kurulumdan sonra bilgisayarı yeniden başlat, Docker Desktop'ı bir kez açıp sözleşmeyi kabul et, sonra bu dosyayı tekrar çalıştır.")
}

& docker info *> $null
if ($LASTEXITCODE -ne 0) {
  $dd = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
  if (Test-Path -LiteralPath $dd) {
    Info 'Docker Desktop başlatılıyor (ilk açılış birkaç dakika sürebilir)...'
    Start-Process -FilePath $dd
  } else {
    Warn 'Docker Desktop çalışmıyor. Başlat menüsünden Docker Desktop''ı aç; bekliyorum...'
  }
  $ready = $false
  for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 2
    & docker info *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  }
  if (-not $ready) {
    Fail ("Docker motoru 3 dakika içinde hazır olmadı.`n" +
          "       Olası nedenler: Docker Desktop açılmadı veya sözleşme ekranı bekliyor; WSL 2 kurulu/güncel değil (yönetici PowerShell'de: wsl --update);`n" +
          "       BIOS'ta sanallaştırma (Virtualization / SVM / VT-x) kapalı. Docker Desktop penceresindeki hata mesajını kontrol et.")
  }
}
Ok 'Docker çalışıyor.'

& docker compose version *> $null
if ($LASTEXITCODE -ne 0) { Fail 'Docker Compose bulunamadı. Docker Desktop''ı güncelle.' }
$osType = (& docker info --format '{{.OSType}}' 2>$null | Out-String).Trim()
if ($osType -ne 'linux') {
  Fail 'Docker "Windows containers" modunda. Görev çubuğundaki Docker simgesine sağ tıkla → "Switch to Linux containers..." seç.'
}

# 2) Yapılandırma (.env.docker): eksikse güvenli değerler bu bilgisayarda üretilir; var olan değerler değiştirilmez.
& docker volume inspect $Volume *> $null
$hasData = ($LASTEXITCODE -eq 0)

if (-not (Test-Path -LiteralPath $EnvFile)) {
  if ($hasData) {
    if (Test-Path -LiteralPath $BackupFile) {
      Copy-Item -LiteralPath $BackupFile -Destination $EnvFile
      Warn ".env.docker bulunamadı; yedeği geri yüklendi: $BackupFile"
    } else {
      Fail (".env.docker bulunamadı ama mevcut AcademicOS veritabanı var ($Volume).`n" +
            "       Yeni parola üretmek veritabanına erişimi keser. Eski .env.docker dosyasını bu klasöre kopyala:`n" +
            "       $WebDir")
    }
  } else {
    [System.IO.File]::WriteAllText($EnvFile, "# AcademicOS yerel ayarları. Bu dosyayı paylaşma ve GitHub'a yükleme.`n", $Utf8NoBom)
    Info 'Yeni .env.docker oluşturuldu.'
  }
}

$envMap = Read-EnvFile $EnvFile
$add = [ordered]@{}
foreach ($k in 'POSTGRES_PASSWORD', 'APP_DB_PASSWORD', 'OWNER_DB_PASSWORD') {
  if (-not $envMap[$k]) {
    if ($hasData) {
      Fail ("$k .env.docker içinde boş, ancak mevcut veritabanı bu parolayla oluşturulmuş.`n" +
            "       Eski değeri .env.docker'a yaz ya da yedeği kullan: $BackupFile")
    }
    $add[$k] = New-Secret 32
  }
}
if (-not $envMap['APP_ENCRYPTION_KEY']) {
  # Anahtar boşken uygulama hiçbir veriyi şifreleyemez; bu yüzden yeni anahtar üretmek mevcut veriyi bozmaz.
  $add['APP_ENCRYPTION_KEY'] = New-Key32
} elseif (-not (Test-Key32 $envMap['APP_ENCRYPTION_KEY'])) {
  Fail 'APP_ENCRYPTION_KEY geçersiz (32 baytlık base64 olmalı). Değeri düzelt; DEBİM anahtarları bu anahtarla şifreleniyor.'
}
$defaults = [ordered]@{
  COOKIE_SECURE = 'false'; ALLOW_REGISTRATION = 'true'; TRUST_PROXY = 'false'
  AI_PROVIDER = ''; AI_MODEL = ''; OPENAI_API_KEY = ''; ANTHROPIC_API_KEY = ''; AI_DAILY_REQUEST_LIMIT = '50'
  TRANSCRIPTION_PROVIDER = ''; TRANSCRIPTION_MODEL = ''
}
foreach ($k in $defaults.Keys) { if (-not $envMap.Contains($k)) { $add[$k] = $defaults[$k] } }

if ($add.Count -gt 0) {
  $text = [System.IO.File]::ReadAllText($EnvFile)
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($line in ($text -split "`r?`n")) {
    # Boş bırakılmış gizli değer satırları yeni değerle değiştirilir.
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*$' -and $add.Contains($Matches[1]) -and $add[$Matches[1]]) {
      $k = $Matches[1]; $lines.Add("$k=$($add[$k])"); $add.Remove($k)
    } else { $lines.Add($line) }
  }
  while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
  foreach ($k in $add.Keys) { $lines.Add("$k=$($add[$k])") }
  [System.IO.File]::WriteAllText($EnvFile, (($lines -join "`n") + "`n"), $Utf8NoBom)
  Ok 'Eksik ayarlar tamamlandı (parolalar ve şifreleme anahtarı bu bilgisayarda üretildi).'
}

# Gizli değerlerin yedeği ve dosya izinleri (yalnızca bu Windows kullanıcısı).
try {
  New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
  Copy-Item -LiteralPath $EnvFile -Destination $BackupFile -Force
  foreach ($f in $EnvFile, $BackupFile) {
    & icacls $f /inheritance:r /grant:r "$($env:USERNAME):(F)" *> $null
  }
} catch { Warn "Ayar yedeği alınamadı: $($_.Exception.Message)" }
Ok "Ayarlar hazır. Yedek: $BackupFile"

# 3) Son kod (git ile indirildiyse)
$repoRoot = Split-Path -Parent $WebDir
if ((Test-Path -LiteralPath (Join-Path $repoRoot '.git')) -and (Get-Command git -ErrorAction SilentlyContinue)) {
  $dirty = (& git -C $repoRoot status --porcelain 2>$null | Out-String).Trim()
  if ($dirty) {
    Warn 'Klasörde kaydedilmemiş değişiklikler var; güncelleme atlandı, mevcut kod kullanılacak.'
  } else {
    Info 'Çalışma dalının son kodu indiriliyor (git pull)...'
    & git -C $repoRoot pull --ff-only
    if ($LASTEXITCODE -ne 0) { Warn 'Güncelleme yapılamadı (internet veya git sorunu); mevcut kod kullanılacak.' }
  }
} else {
  Info 'Klasör git ile indirilmemiş; en yeni sürüm için dal ZIP''ini yeniden indir.'
}

# 4) Port kontrolü
$appId = (Compose ps -q app 2>$null | Out-String).Trim()
$appRunning = $false
if ($appId) { $appRunning = ((& docker inspect -f '{{.State.Running}}' $appId 2>$null | Out-String).Trim() -eq 'true') }
if (-not $appRunning -and (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
  $busy = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($busy) {
    $pname = (Get-Process -Id $busy.OwningProcess -ErrorAction SilentlyContinue).ProcessName
    Fail "$Port numaralı port başka bir program tarafından kullanılıyor ($pname, PID $($busy.OwningProcess)). O programı kapatıp tekrar dene."
  }
}

# 5) Derle ve başlat
Info 'Uygulama derleniyor ve başlatılıyor. İlk seferde 5-15 dakika sürebilir (internet gerekir)...'
Compose up -d --build
if ($LASTEXITCODE -ne 0) {
  Write-Host ''
  Compose ps
  Fail ("Docker uygulamayı derleyemedi veya başlatamadı. Yukarıdaki çıktıyı kontrol et.`n" +
        "       Sık nedenler: internet bağlantısı yok veya kesildi (paket indirme), disk dolu,`n" +
        "       Docker Desktop'a yeterli bellek verilmemiş (en az 4 GB önerilir), veritabanı sağlık kontrolü geçmedi.")
}

# 6) Hazır olmasını bekle
Info 'Uygulamanın hazır olması bekleniyor...'
$ready = $false
for ($i = 0; $i -lt 100; $i++) {
  try {
    $r = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5
    if ($r.StatusCode -eq 200) { $ready = $true; break }
  } catch {}
  $appId = (Compose ps -a -q app 2>$null | Out-String).Trim()
  if ($appId) {
    $st = (& docker inspect -f '{{.State.Status}} {{.RestartCount}}' $appId 2>$null | Out-String).Trim().Split(' ')
    if ($st[0] -eq 'exited' -or ($st.Length -gt 1 -and [int]$st[1] -gt 0)) { break }
  }
  Start-Sleep -Seconds 3
}

if (-not $ready) {
  $logs = (Compose logs --no-color --tail 60 app 2>&1 | Out-String)
  Write-Host $logs
  $hint = 'Uygulama 5 dakika içinde yanıt vermedi.'
  if ($logs -match 'password authentication failed') {
    $hint = "Veritabanı parolası uyuşmuyor. .env.docker değiştirilmiş olabilir; yedeği geri koy: $BackupFile"
  } elseif ($logs -match 'ECONNREFUSED|ENOTFOUND|getaddrinfo') {
    $hint = 'Uygulama veritabanına bağlanamadı. Docker Desktop''ı yeniden başlatıp tekrar dene.'
  } elseif ($logs -match 'APP_ENCRYPTION_KEY') {
    $hint = 'APP_ENCRYPTION_KEY sorunu: .env.docker içindeki anahtarı kontrol et.'
  } elseif ($logs -match 'EADDRINUSE') {
    $hint = "$Port numaralı port kullanımda."
  } elseif ($logs -match 'migrat|relation .* does not exist|syntax error') {
    $hint = 'Veritabanı güncellemesi (migration) başarısız oldu. Yukarıdaki günlük satırlarını kaydet.'
  }
  Fail $hint
}

Ok "AcademicOS çalışıyor: $StartUrl"

# 7) Chrome'da aç
$chromeCandidates = foreach ($base in $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA) {
  if ($base) { Join-Path $base 'Google\Chrome\Application\chrome.exe' }
}
$chrome = $chromeCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if ($chrome) {
  Start-Process -FilePath $chrome -ArgumentList $StartUrl
} else {
  Warn 'Google Chrome bulunamadı; varsayılan tarayıcıda açılıyor.'
  Start-Process $StartUrl
}
Write-Host ''
Write-Host 'Durdurmak için: AcademicOS-Durdur.bat (verilerin korunur).' -ForegroundColor Gray
exit 0
