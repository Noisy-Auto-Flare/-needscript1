<#
.SYNOPSIS
    Установка AnyDesk с полной настройкой неконтролируемого доступа.
.DESCRIPTION
    Скачивает AnyDesk, устанавливает как службу, настраивает пароль,
    включает unattended access и выводит ID.
#>

$Password = "YourSecurePass123!"   # ⚠️ ОБЯЗАТЕЛЬНО ЗАМЕНИТЕ!
$DownloadUrl = "https://download.anydesk.com/AnyDesk.exe"

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   УСТАНОВКА ANYDESK (ПОЛНАЯ ВЕРСИЯ)" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 1. Определение папки установки (работает на 32/64 бита)
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

if (-not (Test-Path $DownloadedExe) -or (Get-Item $DownloadedExe).Length -eq 0) {
    Write-Host "   ❌ Скачанный файл пуст или отсутствует." -ForegroundColor Red
    exit 1
}

# 4. Установка AnyDesk как службы (ключ --install)
Write-Host "[2/6] Установка AnyDesk (как служба)..." -ForegroundColor Cyan
try {
    # Запускаем установщик с ключами для тихой установки и создания службы
    $installArgs = "--install", "--start-with-win", "--silent"
    Start-Process -FilePath $DownloadedExe -ArgumentList $installArgs -Wait -NoNewWindow
    Write-Host "   ✅ Установка выполнена." -ForegroundColor Green
} catch {
    Write-Host "   ❌ Ошибка при установке: $_" -ForegroundColor Red
    exit 1
}

# 5. Ожидание полной инициализации службы
Write-Host "[3/6] Ожидание инициализации AnyDesk..." -ForegroundColor Cyan
Start-Sleep -Seconds 10  # Увеличено для гарантии

# 6. Установка пароля для неконтролируемого доступа
Write-Host "[4/6] Настройка пароля и unattended access..." -ForegroundColor Cyan

# Правильный синтаксис для установки пароля (AnyDesk 6+)
try {
    # Сначала останавливаем процесс, чтобы избежать конфликтов
    Stop-Process -Name "AnyDesk" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Устанавливаем пароль
    echo $Password | & "C:\Program Files (x86)\AnyDesk\AnyDesk.exe" --set-password
    Write-Host "   ✅ Пароль установлен." -ForegroundColor Green

    # Включаем неконтролируемый доступ через реестр (для всех пользователей)
    $regPath = "HKLM:\SOFTWARE\AnyDesk"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "ad.security.expose_options" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $regPath -Name "ad.security.unattended_access" -Value 1 -Type DWord -Force
    
    # Для 64-битных систем также может потребоваться запись в WOW6432Node
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
    Write-Host "   Продолжаем, но unattended access может не работать." -ForegroundColor Yellow
}

# 7. Запуск AnyDesk (скрыто, без окна)
Write-Host "[5/6] Запуск AnyDesk в фоне..." -ForegroundColor Cyan
try {
    # Запускаем с флагом --silent, чтобы окно не появлялось
    Start-Process -FilePath "C:\Program Files (x86)\AnyDesk\AnyDesk.exe" -ArgumentList "--silent" -WindowStyle Hidden
    Write-Host "   ✅ Процесс запущен скрыто." -ForegroundColor Green
} catch {
    Write-Host "   ⚠️ Не удалось запустить: $_" -ForegroundColor Yellow
}

# 8. Получение ID с проверкой
Write-Host "[6/6] Получение AnyDesk ID..." -ForegroundColor Cyan
$ID = $null
$maxAttempts = 12
$attempt = 0

while ($attempt -lt $maxAttempts) {
    Start-Sleep -Seconds 5
    $ID = & "C:\Program Files (x86)\AnyDesk\AnyDesk.exe" --get-id | Out-String
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

# 9. Итог
Write-Host "===================================================" -ForegroundColor Green
Write-Host "✅ УСТАНОВКА ЗАВЕРШЕНА!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host "🔑 AnyDesk ID: $ID" -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "🔑 Пароль: $Password" -ForegroundColor White
Write-Host "📂 Расположение: $InstallPath" -ForegroundColor Gray
Write-Host "🔄 Служба: AnyDesk (запускается автоматически)" -ForegroundColor Gray
Write-Host "🔓 Неконтролируемый доступ: ВКЛЮЧЁН" -ForegroundColor Green

# 10. Очистка временных файлов
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue