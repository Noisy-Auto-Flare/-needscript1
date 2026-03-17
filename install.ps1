<#
.SYNOPSIS
    Установка AnyDesk с автоматической настройкой удалённого доступа.
.DESCRIPTION
    Скачивает AnyDesk, копирует в Program Files, устанавливает пароль,
    создаёт задачу в планировщике для автозапуска и выводит ID.
#>

$Password = "YourSecurePass123!"   # ⚠️ ЗАМЕНИТЕ НА СВОЙ ПАРОЛЬ
$DownloadUrl = "https://download.anydesk.com/AnyDesk.exe"

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   УСТАНОВКА ANYDESK (УЛУЧШЕННАЯ ВЕРСИЯ)" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 1. Определение папки установки (работает и на 32, и на 64 битах)
if ([Environment]::Is64BitOperatingSystem) {
    $InstallPath = "${env:ProgramFiles(x86)}\AnyDesk"
} else {
    $InstallPath = "${env:ProgramFiles}\AnyDesk"
}
Write-Host "Целевая папка: $InstallPath" -ForegroundColor Gray

# 2. Создание временной папки для загрузки
$TempDir = Join-Path $env:TEMP "AnyDeskSetup_$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
$DownloadedExe = Join-Path $TempDir "AnyDesk.exe"

# 3. Скачивание
Write-Host "[1/5] Скачивание AnyDesk..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadedExe -UseBasicParsing
    Write-Host "   ✅ Скачивание завершено." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Ошибка скачивания: $_" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $DownloadedExe) -or (Get-Item $DownloadedExe).Length -eq 0) {
    Write-Host "   ❌ Скачанный файл пуст или отсутствует." -ForegroundColor Red
    exit 1
}

# 4. Создание целевой папки и копирование
Write-Host "[2/5] Копирование в $InstallPath ..." -ForegroundColor Cyan
try {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Copy-Item -Path $DownloadedExe -Destination (Join-Path $InstallPath "AnyDesk.exe") -Force
    Write-Host "   ✅ Файл скопирован." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Ошибка копирования: $_" -ForegroundColor Red
    exit 1
}

$TargetExe = Join-Path $InstallPath "AnyDesk.exe"
if (-not (Test-Path $TargetExe)) {
    Write-Host "   ❌ AnyDesk.exe не найден после копирования!" -ForegroundColor Red
    exit 1
}

# 5. Установка пароля
Write-Host "[3/5] Установка пароля для неконтролируемого доступа..." -ForegroundColor Cyan
try {
    $Password | & $TargetExe --set-password
    Write-Host "   ✅ Пароль установлен." -ForegroundColor Green
} catch {
    Write-Host "   ⚠️ Ошибка установки пароля (можно установить позже вручную)" -ForegroundColor Yellow
}

# 6. Создание задачи в планировщике (запуск при старте системы)
Write-Host "[4/5] Настройка автозапуска..." -ForegroundColor Cyan
$TaskName = "AnyDesk_SilentService"
$Action = New-ScheduledTaskAction -Execute $TargetExe
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Compatibility Win8 -Hidden
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Удаляем старую задачу, если есть
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Force | Out-Null
    Write-Host "   ✅ Задача создана." -ForegroundColor Green
} catch {
    Write-Host "   ⚠️ Ошибка создания задачи: $_" -ForegroundColor Yellow
}

# 7. Запуск AnyDesk сейчас (скрыто)
Write-Host "[5/5] Запуск AnyDesk..." -ForegroundColor Cyan
try {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $TargetExe
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $pinfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    Start-Sleep -Seconds 5
    Write-Host "   ✅ Процесс запущен." -ForegroundColor Green
} catch {
    Write-Host "   ⚠️ Не удалось запустить процесс: $_" -ForegroundColor Yellow
}

# 8. Получение ID AnyDesk
$ID = & $TargetExe --get-id | Out-String
$ID = $ID.Trim()

# 9. Итог
Write-Host "===================================================" -ForegroundColor Green
Write-Host "✅ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host "🔑 AnyDesk ID: $ID" -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "🔑 Пароль: $Password" -ForegroundColor White
Write-Host "📂 Расположение: $InstallPath" -ForegroundColor Gray
Write-Host "🔄 Автозапуск: при старте системы (через планировщик)" -ForegroundColor Gray

# Очистка временных файлов
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue