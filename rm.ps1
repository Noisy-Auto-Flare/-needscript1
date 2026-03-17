<#
.SYNOPSIS
    Скрипт для полного удаления AnyDesk, установленного вручную или через автоматический скрипт.
.DESCRIPTION
    Останавливает процесс AnyDesk, удаляет задачу из планировщика, удаляет папку установки
    и очищает ключи реестра. Требует прав администратора.
.PARAMETER Force
    Если указан, удаляет без запроса подтверждения.
.EXAMPLE
    .\Remove-AnyDesk.ps1 -Force
#>

param(
    [switch]$Force
)

# Проверка прав администратора
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ Этот скрипт необходимо запускать от имени администратора!" -ForegroundColor Red
    exit 1
}

# Запрос подтверждения, если не указан -Force
if (-not $Force) {
    $confirmation = Read-Host "Это приведёт к полному удалению AnyDesk с этого компьютера. Продолжить? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "Операция отменена." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "🔄 Начинаем удаление AnyDesk..." -ForegroundColor Cyan

# 1. Остановка процесса AnyDesk (если запущен)
try {
    $proc = Get-Process -Name "AnyDesk" -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "⏹ Останавливаем процесс AnyDesk..." -ForegroundColor Yellow
        Stop-Process -Name "AnyDesk" -Force
        Start-Sleep -Seconds 2
    }
} catch {
    Write-Host "⚠️ Не удалось остановить процесс: $_" -ForegroundColor Yellow
}

# 2. Удаление задачи из планировщика (AnyDesk_SilentService)
$taskName = "AnyDesk_SilentService"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($taskExists) {
    Write-Host "🗑 Удаляем задачу из планировщика: $taskName" -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
} else {
    Write-Host "✅ Задача '$taskName' не найдена." -ForegroundColor Green
}

# 3. Удаление папки установки (проверяем оба возможных пути)
$installPaths = @(
    "${env:ProgramFiles}\AnyDesk",
    "${env:ProgramFiles(x86)}\AnyDesk"
)

foreach ($path in $installPaths) {
    if (Test-Path $path) {
        Write-Host "🗑 Удаляем папку: $path" -ForegroundColor Yellow
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "❌ Не удалось удалить $path : $_" -ForegroundColor Red
        }
    } else {
        Write-Host "✅ Папка $path не существует." -ForegroundColor Green
    }
}

# 4. Очистка реестра (HKCU:\Software\AnyDesk)
$regPath = "HKCU:\Software\AnyDesk"
if (Test-Path $regPath) {
    Write-Host "🗑 Удаляем ключ реестра: $regPath" -ForegroundColor Yellow
    Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "✅ Ключ реестра не найден." -ForegroundColor Green
}

# 5. Дополнительно: удаление возможного конфигурационного файла в других местах (например, в AppData)
$appDataPath = "$env:APPDATA\AnyDesk"
if (Test-Path $appDataPath) {
    Write-Host "🗑 Удаляем папку в AppData: $appDataPath" -ForegroundColor Yellow
    Remove-Item -Path $appDataPath -Recurse -Force -ErrorAction SilentlyContinue
}

# 6. Поиск и удаление других возможных копий (например, временных)
$tempFiles = Get-ChildItem -Path $env:TEMP -Filter "AnyDesk*.exe" -ErrorAction SilentlyContinue
if ($tempFiles) {
    Write-Host "🗑 Удаляем временные файлы AnyDesk:" -ForegroundColor Yellow
    $tempFiles | ForEach-Object {
        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "   Удалён: $($_.Name)" -ForegroundColor Gray
    }
}

Write-Host "===================================================" -ForegroundColor Green
Write-Host "✅ AnyDesk успешно удалён!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green