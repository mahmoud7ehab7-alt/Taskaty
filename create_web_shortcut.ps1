$WshShell = New-Object -ComObject WScript.Shell
$desktopPaths = @(
    [Environment]::GetFolderPath('Desktop'),
    "C:\Users\i-seven\Desktop",
    "C:\Users\i-seven\OneDrive\Desktop"
) | Where-Object { Test-Path $_ } | Select-Object -Unique

$batPath = "c:\Users\i-seven\StudioProjects\my_tasks\run_desktop.bat"
$iconPath = "c:\Users\i-seven\StudioProjects\my_tasks\windows\runner\resources\app_icon.ico"

foreach ($desktop in $desktopPaths) {
    $shortcutPath = Join-Path $desktop "Taskaty.lnk"
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $batPath
    $shortcut.WorkingDirectory = "c:\Users\i-seven\StudioProjects\my_tasks"
    $shortcut.Description = "Taskaty App"
    if (Test-Path $iconPath) {
        $shortcut.IconLocation = "$iconPath,0"
    }
    $shortcut.Save()
    Write-Host "Created shortcut: $shortcutPath"
}
