@echo off
chcp 65001 >nul
title تثبيت وبناء تطبيق Taskaty للديسك توب

:: التحقق من صلاحيات المسؤول (Administrator)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ========================================================
    echo جاري طلب صلاحيات المسؤول (Administrator)...
    echo يرجى الضغط على "نعم" (Yes) في النافذة المنبثقة للمتابعة.
    echo ========================================================
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

set PATH=C:\develop\flutter\bin;%PATH%
cd /d "c:\Users\i-seven\StudioProjects\my_tasks"

echo.
echo ========================================================
echo          [1/3] تثبيت أدوات Visual Studio C++
echo ========================================================
echo جاري تثبيت حزمة Desktop development with C++ المطلوبة من Flutter...
echo قد يستغرق التثبيت بضع دقائق اعتماداً على سرعة الاتصال.
echo.

set INSTALLER="C:\Users\i-seven\AppData\Local\Temp\WinGet\Microsoft.VisualStudio.2022.BuildTools.17.14.41\vs_BuildTools.exe"

if exist %INSTALLER% (
    %INSTALLER% --passive --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended
) else (
    winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--passive --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" --accept-source-agreements --accept-package-agreements
)

echo.
echo ========================================================
echo          [2/3] بناء التطبيق لويندوز (Release)
echo ========================================================
echo جاري بناء ملف التطبيق التنفيذي my_tasks.exe...
echo.

call flutter build windows --release

if %errorlevel% neq 0 (
    echo.
    echo حدث خطأ أثناء بناء التطبيق.
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo          [3/3] إنشاء اختصار على الديسك توب
echo ========================================================
powershell -ExecutionPolicy Bypass -File "c:\Users\i-seven\StudioProjects\my_tasks\create_desktop_shortcut.ps1"

echo.
echo ========================================================
echo   تم تثبيت التطبيق وإنشاء الاختصار على الديسك توب بنجاح!
echo ========================================================
echo يمكنك الآن فتح التطبيق مباشرة من سطح المكتب (Taskaty).
echo.
pause
