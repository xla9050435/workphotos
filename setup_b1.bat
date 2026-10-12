@echo off
REM ============================================================
REM B1 setup script for photo_manager (Windows, double-click to run)
REM Steps: set proxy, create android platform dir, inject permissions,
REM        fetch deps, generate drift code, run the app.
REM NOTE: comments are English on purpose to avoid encoding issues.
REM ============================================================

REM --- Set proxy (adjust port if your Clash/Proxy is different) ---
set HTTP_PROXY=http://127.0.0.1:7897
set HTTPS_PROXY=http://127.0.0.1:7897

REM --- Switch to the directory containing this bat file ---
CD /D %~dp0

REM --- Generate the Android platform folder (keeps existing lib/) ---
echo [1/5] Creating Android platform directory...
flutter create --platforms android .

REM --- Inject storage permission lines into AndroidManifest.xml ---
echo [2/5] Injecting Android permissions...
powershell -Command "if (Test-Path 'android\app\src\main\AndroidManifest.xml') { $p = '    <uses-permission android:name=""android.permission.READ_MEDIA_IMAGES"" />' + [Environment]::NewLine + '    <uses-permission android:name=""android.permission.READ_EXTERNAL_STORAGE"" android:maxSdkVersion=""32"" />'; (Get-Content 'android\app\src\main\AndroidManifest.xml') -replace '</manifest>', ($p + [Environment]::NewLine + '</manifest>') | Set-Content 'android\app\src\main\AndroidManifest.xml'; Write-Host 'Permissions injected into AndroidManifest.xml.' } else { Write-Host 'AndroidManifest.xml not found. Please add permissions manually (see README_B1.md).' }"

REM --- Fetch Flutter dependencies ---
echo [3/5] Fetching dependencies (flutter pub get)...
flutter pub get

REM --- Generate Drift code (app_database.g.dart) ---
echo [4/5] Generating Drift code (build_runner)...
flutter pub run build_runner build --delete-conflicting-outputs

REM --- Run the app ---
echo [5/5] Running the app (flutter run)...
flutter run

pause
