# install.ps1 – тихая установка AnyDesk с GitHub
# Запускать от имени администратора

# --- НАСТРОЙКИ (измените под себя) ---
$AnyDeskURL = "https://download.anydesk.com/AnyDesk.exe"
$Password = "YourSecurePass123!"   # пароль для unattended доступа
$HideTrayIcon = $true              # скрыть иконку в трее
# --------------------------------------

$Installer = "$env:TEMP\AnyDesk.exe"

# 1. Скачивание
Write-Host "Скачивание AnyDesk..."
try {
    Invoke-WebRequest -Uri $AnyDeskURL -OutFile $Installer -UseBasicParsing
} catch {
    Write-Host "Ошибка скачивания: $_"
    exit 1
}

# 2. Тихая установка (системная служба)
Write-Host "Установка AnyDesk..."
Start-Process -FilePath $Installer -ArgumentList "--install", "--start-with-win", "--silent", "--accept-license" -Wait -NoNewWindow

# Удаление установщика
Remove-Item $Installer -Force -ErrorAction SilentlyContinue

# 3. Настройка AnyDesk
Start-Sleep -Seconds 5  # дать службе время запуститься

$AnyDeskPath = "${env:ProgramFiles}\AnyDesk\AnyDesk.exe"
if (-not (Test-Path $AnyDeskPath)) {
    $AnyDeskPath = "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe"
}

if (Test-Path $AnyDeskPath) {
    # Установка пароля
    & $AnyDeskPath --set-password $Password

    # Включение unattended access
    & $AnyDeskPath --set-settings "ad.security.expose_options=1"
    & $AnyDeskPath --set-settings "ad.security.unattended_access=1"

    # Скрытие иконки в трее (через реестр текущего пользователя)
    if ($HideTrayIcon) {
        $regPath = "HKCU:\Software\AnyDesk"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "TrayIcon" -Value 0 -Type DWord -Force
    }

    Write-Host "Установка завершена. AnyDesk ID:"
    & $AnyDeskPath --get-id
    Write-Host "Пароль unattended: $Password"
} else {
    Write-Host "Ошибка: AnyDesk не найден после установки."
}