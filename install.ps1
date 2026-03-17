<#
.SYNOPSIS
    Установка AnyDesk с принудительным размещением в Program Files и полной настройкой.
.DESCRIPTION
    Скачивает AnyDesk, принудительно устанавливает в Program Files, настраивает службу,
    пароль и включает unattended access.
#>

$Password = "YourSecurePass123!"   # ⚠️ ОБЯЗАТЕЛЬНО ЗАМЕНИТЕ!
$DownloadUrl = "https://download.anydesk.com/AnyDesk.exe"

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   УСТАНОВКА ANYDESK (СИСТЕМНАЯ ВЕРСИЯ)" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 1. Определение папки установки (используем Program Files)
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
Write-Host "[1/6] Скачивание AnyDesk..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadedExe -UseBasicParsing
    Write-Host "   ✅ Скачивание завершено." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Ошибка скачивания: $_" -ForegroundColor Red
    exit 1
}

# 4. Принудительная распаковка в целевую папку (AnyDesk portable mode)
Write-Host "[2/6] Копирование файлов в $InstallPath ..." -ForegroundColor Cyan
try {
    # Создаём целевую папку, если её нет
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    # Копируем скачанный exe в целевую папку
    Copy-Item -Path $DownloadedExe -Destination (Join-Path $InstallPath "AnyDesk.exe") -Force
    Write-Host "   ✅ Файлы скопированы." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Ошибка копирования: $_" -ForegroundColor Red
    exit 1
}

$TargetExe = Join-Path $InstallPath "AnyDesk.exe"
if (-not (Test-Path $TargetExe)) {
    Write-Host "   ❌ AnyDesk.exe не найден после копирования!" -ForegroundColor Red
    exit 1
}

# 5. Установка и запуск службы AnyDesk
Write-Host "[3/6] Установка службы AnyDesk..." -ForegroundColor Cyan
try {
    # Устанавливаем службу (AnyDesk должен быть запущен хотя бы раз)
    Start-Process -FilePath $TargetExe -ArgumentList "--install" -Wait -NoNewWindow
    Write-Host "   ✅ Служба установлена." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Ошибка установки службы: $_" -ForegroundColor Red
    exit 1
}

# 6. Ожидание инициализации службы
Write-Host "[4/6] Ожидание запуска службы..." -ForegroundColor Cyan
Start-Sleep -Seconds 15

# 7. Настройка пароля и неконтролируемого доступа
Write-Host "[5/6] Настройка пароля и unattended access..." -ForegroundColor Cyan
try {
    # Останавливаем процесс, чтобы избежать конфликтов (служба продолжит работу)
    Stop-Process -Name "AnyDesk" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Устанавливаем пароль (работает со службой)
    echo $Password | & $TargetExe --set-password
    Write-Host "   ✅ Пароль установлен." -ForegroundColor Green

    # Включаем неконтролируемый доступ через реестр
    $regPath = "HKLM:\SOFTWARE\AnyDesk"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "ad.security.expose_options" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $regPath -Name "ad.security.unattended_access" -Value 1 -Type DWord -Force

    # Для 64-битных систем также записываем в WOW6432Node
    if ([Environment]::Is64BitOperatingSystem) {
        $regPathWow = "HKLM:\SOFTWARE\WOW6432Node\AnyDesk"
        if (-not (Test-Path $regPathWow)) {
            New-Item -Path $regPathWow -Force | Out-Null
        }
        Set-ItemProperty -Path $regPathWow -Name "ad.security.expose_options" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $regPathWow -Name "ad.security.unattended_access" -Value 1 -Type DWord -Force
    }

    Write-Host "   ✅ Неконтролируемый доступ включён." -ForegroundColor Green
} catch {
    Write-Host "   ⚠️ Ошибка настройки: $_" -ForegroundColor Yellow
    Write-Host "   Вы можете настроить параметры вручную позже." -ForegroundColor Yellow
}

# 8. Запуск AnyDesk в фоне (без окна)
Write-Host "[6/6] Запуск AnyDesk..." -ForegroundColor Cyan
try {
    Start-Process -FilePath $TargetExe -ArgumentList "--silent" -WindowStyle Hidden
    Write-Host "   ✅ Процесс запущен." -ForegroundColor Green
} catch {
    Write-Host "   ⚠️ Не удалось запустить: $_" -ForegroundColor Yellow
}

# 9. Получение ID с проверкой
Write-Host "Получение AnyDesk ID..." -ForegroundColor Cyan
$ID = $null
$maxAttempts = 12
$attempt = 0

while ($attempt -lt $maxAttempts) {
    Start-Sleep -Seconds 5
    $ID = & $TargetExe --get-id | Out-String
    $ID = $ID.Trim()
    if ($ID -match "^\d+$" -and $ID -ne "0") {
        Write-Host "   ✅ ID получен: $ID" -ForegroundColor Green
        break
    }
    Write-Host "   ⏳ Ожидание ID (попытка $($attempt+1))..." -ForegroundColor Gray
    $attempt++
}

if (-not $ID -or $ID -eq "0") {
    $ID = "Не удалось определить (возможно, требуется перезагрузка)"
}

# 10. Итог
Write-Host "===================================================" -ForegroundColor Green
Write-Host "✅ УСТАНОВКА ЗАВЕРШЕНА!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host "🔑 AnyDesk ID: $ID" -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "🔑 Пароль: $Password" -ForegroundColor White
Write-Host "📂 Расположение: $InstallPath" -ForegroundColor Gray
Write-Host "🔄 Служба: AnyDesk (запускается автоматически)" -ForegroundColor Gray
Write-Host "🔓 Неконтролируемый доступ: ВКЛЮЧЁН" -ForegroundColor Green

# 11. Очистка временных файлов
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue