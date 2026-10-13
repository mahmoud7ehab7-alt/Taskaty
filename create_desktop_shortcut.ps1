$ErrorActionPreference = "Stop"

$desktopPaths = @(
    [Environment]::GetFolderPath('Desktop'),
    "C:\Users\i-seven\Desktop",
    "C:\Users\i-seven\OneDrive\Desktop"
) | Where-Object { Test-Path $_ } | Select-Object -Unique

# Find my_tasks.exe in build/windows
$exe = Get-ChildItem -Path "c:\Users\i-seven\StudioProjects\my_tasks\build\windows" -Filter "my_tasks.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $exe) {
    Write-Warning "Could not find my_tasks.exe in build/windows directory."
    exit 1
}

$WshShell = New-Object -ComObject WScript.Shell
$iconPath = "c:\Users\i-seven\StudioProjects\my_tasks\windows\runner\resources\app_icon.ico"

foreach ($desktop in $desktopPaths) {
    $shortcutPath = Join-Path $desktop "Taskaty.lnk"
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exe.FullName
    $shortcut.WorkingDirectory = $exe.DirectoryName
    $shortcut.Description = "Taskaty App"
    if (Test-Path $iconPath) {
        $shortcut.IconLocation = "$iconPath,0"
    }
    $shortcut.Save()
    Write-Host "Created shortcut: $shortcutPath"
}
