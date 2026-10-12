@echo off
REM ============================================================
REM  build_and_run.bat
REM  One-click build + run for the "Work Photos" Flutter app.
REM  Double-click this file. That is all a normal user has to do.
REM
REM  STEPS
REM    0/6  pre-flight checks (Flutter SDK, Dart, PowerShell)
REM    1/6  flutter doctor                             (warn only)
REM    2/6  flutter create --platforms android .      (idempotent)
REM    3/6  inject Android photo permissions           (idempotent)
REM    4/6  flutter pub get
REM    5/6  build_runner, generates lib/data/db/app_database.g.dart
REM    6/6  flutter run                               (interactive)
REM
REM  HOW OUTPUT IS HANDLED
REM    Each step writes to a small temporary file first. That file is then
REM    printed on screen AND appended to build_run.log. This avoids paging
REM    tools and line counting, so logging can never block or break a step.
REM
REM  IMPORTANT NOTES
REM   * THIS FILE MUST STAY ASCII / ENGLISH ONLY. Chinese text inside a
REM     .bat file breaks on some Windows code pages. All Chinese help
REM     lives in the help_zh\ folder as UTF-8 files instead.
REM   * Every step checks ERRORLEVEL and stops on failure.
REM   * Safe to run again and again (idempotent).
REM   * Every flutter / dart command is prefixed with CALL. On Windows both
REM     are .bat files, and running a .bat from inside a .bat without CALL
REM     transfers control and NEVER comes back, which would silently kill
REM     this script after the first step.
REM ============================================================

setlocal EnableExtensions EnableDelayedExpansion

REM ------------------------------------------------------------
REM  >>> USER SETTINGS - this is the only part you may need to edit
REM
REM  PROXY_PORT : the local port of your Clash / VPN client.
REM               Open your proxy app, look at its settings page,
REM               and change the number below if it is not 7897.
REM               Getting packages from pub.dev / Google needs this.
REM ------------------------------------------------------------
set "PROXY_HOST=127.0.0.1"
set "PROXY_PORT=7897"

REM ------------------------------------------------------------
REM  Do not change anything below this line.
REM ------------------------------------------------------------
REM --- Note: PATH entries must be FOLDERS, never a path to a .bat file ---
set "FLUTTER_BIN_DIR=D:\flutter\bin"
set "FLUTTER_FALLBACK=%FLUTTER_BIN_DIR%\flutter.bat"
set "DART_BIN_DIR=%FLUTTER_BIN_DIR%\cache\dart-sdk\bin"
set "JAVA_HOME=D:\jdk-17.0.14+7"
set "ANDROID_SDK_DIR=C:\Users\19629\AppData\Local\Android\Sdk"
set "ANDROID_HOME=%ANDROID_SDK_DIR%"

set "ROOT=%~dp0"
set "LOG=%ROOT%build_run.log"
set "STEP_LOG=%TEMP%\work_photos_step.log"
set "PS_SCRIPT=%ROOT%tools\inject_permissions.ps1"
set "SHOW_HELP=%ROOT%tools\show_help.bat"
set "MANIFEST=%ROOT%android\app\src\main\AndroidManifest.xml"

title Work Photos - Build and Run

REM --- Always work inside the folder that holds this script ---
cd /D "%ROOT%"

REM --- Proxy environment variables (lowercase copies: some tools need them) ---
set "HTTP_PROXY=http://%PROXY_HOST%:%PROXY_PORT%"
set "HTTPS_PROXY=%HTTP_PROXY%"
set "http_proxy=%HTTP_PROXY%"
set "https_proxy=%HTTP_PROXY%"
set "NO_PROXY=localhost,127.0.0.1,::1"
set "no_proxy=%NO_PROXY%"

REM --- Gradle does NOT read HTTP_PROXY. It only reads JVM system properties,
REM --- so the Android build needs its own proxy settings, otherwise the
REM --- first Gradle / Maven download stalls until it times out.
REM ---
REM --- DO NOT add  -Dhttp.nonProxyHosts=localhost|127.0.0.1  to this line.
REM --- '|' is the cmd.exe PIPE operator, and android\gradlew.bat builds its
REM --- java command line with an UNQUOTED GRADLE_OPTS in the middle:
REM ---     java  ...  GRADLE_OPTS  "-Dorg.gradle.appname=..."  ...
REM --- cmd splits that command line at the pipe and then tries to RUN the
REM --- text after it, which prints "'127.0.0.1' is not recognized as an
REM --- internal or external command" and aborts the build with exit code 255.
REM --- Escaping it as ^| is NOT a real fix either: inside set "VAR=..."
REM --- cmd keeps the caret, so the variable really holds "^|", and it only
REM --- seems to work because gradlew.bat happens to expand it unquoted.
REM --- That is a silent trap waiting for the next Gradle update.
REM --- The proxy host and port below are what Gradle actually needs, so
REM --- the nonProxyHosts part is deliberately left out on purpose.
set "GRADLE_OPTS=-Dhttp.proxyHost=%PROXY_HOST% -Dhttp.proxyPort=%PROXY_PORT% -Dhttps.proxyHost=%PROXY_HOST% -Dhttps.proxyPort=%PROXY_PORT%"

REM --- Fresh log for every run ---
>  "%LOG%" echo ============================================================
>>"%LOG%" echo  build_and_run.bat started  %DATE% %TIME%
>>"%LOG%" echo  Folder : %ROOT%
>>"%LOG%" echo  Proxy  : %HTTP_PROXY%
>>"%LOG%" echo ============================================================

echo(
echo ============================================================
echo   WORK PHOTOS  -  BUILD AND RUN
echo ============================================================
echo   Folder : %ROOT%
echo   Proxy  : %HTTP_PROXY%
echo   Log    : %LOG%
echo ============================================================
echo(
echo   PROXY WARNING - READ THIS FIRST
echo   If anything cannot be downloaded - errors mentioning
echo   pub.dev, dartlang.org, maven.google.com, or a timeout -
echo   your proxy port is wrong. Open your proxy app, find the
echo   port it actually uses, then edit PROXY_PORT near the top
echo   of build_and_run.bat and double-click it again.
echo(

call "%SHOW_HELP%" "%ROOT%help_zh\00_intro.txt"

REM ============================================================
REM  STEP 0 - pre-flight checks
REM  Note: each check runs exactly once. There is deliberately no
REM  retry loop, because re-testing 'where flutter' in a loop would
REM  spin forever.
REM ============================================================
echo(
echo [0/6] Checking the environment...
>>"%LOG%" echo.
>>"%LOG%" echo [0/6] pre-flight checks

REM --- Is Flutter on PATH? If not, fall back to the known local install ---
where flutter >nul 2>&1
if not errorlevel 1 goto :preflight_flutter_ok
if not exist "%FLUTTER_FALLBACK%" goto :fail_no_flutter
echo       Flutter is not on PATH, using %FLUTTER_FALLBACK% instead.
echo       To fix this permanently, add %FLUTTER_BIN_DIR% to your PATH.
REM Add the FOLDER, not the .bat file, otherwise 'where' still cannot find it.
set "PATH=%FLUTTER_BIN_DIR%;%DART_BIN_DIR%;%PATH%"

:preflight_flutter_ok
where flutter >nul 2>&1
if errorlevel 1 goto :fail_no_flutter

where dart >nul 2>&1
if errorlevel 1 goto :fail_no_dart

where powershell >nul 2>&1
if errorlevel 1 goto :fail_no_powershell

if not exist "%ROOT%pubspec.yaml" goto :fail_no_pubspec

echo       Flutter SDK : found
echo       Dart        : found
echo       PowerShell  : found
echo       Project     : pubspec.yaml found

REM ============================================================
REM  STEP 1 - flutter doctor  (warnings only, never fatal)
REM ============================================================
echo(
echo [1/6] Checking that the Flutter toolchain is healthy...
call :begin_step "1/6" "flutter doctor"
call flutter doctor >>"%STEP_LOG%" 2>&1
call :end_step
if not "%RC%"=="0" echo       NOTE: flutter doctor reported issues. We keep going, because
if not "%RC%"=="0" echo             real errors, if any, will be reported by the later steps.
call "%SHOW_HELP%" "%ROOT%help_zh\01_doctor.txt"

REM ============================================================
REM  STEP 2 - make sure the android\ project folder exists
REM ============================================================
echo(
echo [2/6] Preparing the Android project folder...
if exist "%MANIFEST%" goto :step2_skip
echo       android\ not found yet - running flutter create now.
echo       It only adds the missing Android files.
echo       Your lib\ code is never overwritten.
call :backup_pubspec
call :begin_step "2/6" "flutter create --platforms android ."
call flutter create --platforms android . >>"%STEP_LOG%" 2>&1
call :end_step
if not "%RC%"=="0" goto :fail_create
:step2_skip
if not exist "%MANIFEST%" goto :fail_no_manifest
echo       android\ is ready.
call "%SHOW_HELP%" "%ROOT%help_zh\02_android.txt"

REM ============================================================
REM  STEP 3 - inject the photo read permissions (idempotent)
REM ============================================================
echo(
echo [3/6] Adding the photo permissions to AndroidManifest.xml...
if not exist "%PS_SCRIPT%" goto :fail_no_helper
call :begin_step "3/6" "inject Android permissions"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -ManifestPath "%MANIFEST%" >>"%STEP_LOG%" 2>&1
call :end_step
if not "%RC%"=="0" goto :fail_permissions
call "%SHOW_HELP%" "%ROOT%help_zh\03_permissions.txt"

REM ============================================================
REM  STEP 4 - fetch dependencies
REM ============================================================
echo(
echo [4/6] Downloading the Dart / Flutter packages...
echo       The first run downloads about 123 packages, this takes a while.
call :begin_step "4/6" "flutter pub get"
call flutter pub get >>"%STEP_LOG%" 2>&1
call :end_step
if not "%RC%"=="0" goto :fail_pubget
call "%SHOW_HELP%" "%ROOT%help_zh\04_pubget.txt"

REM ============================================================
REM  STEP 5 - code generation for Drift (app_database.g.dart)
REM ============================================================
echo(
echo [5/6] Generating the database code...
echo       This scans every Dart file in lib\ and writes
echo       lib\data\db\app_database.g.dart
echo       The first run can take 1-3 minutes.
call :begin_step "5/6" "build_runner (dart run)"
call dart run build_runner build --delete-conflicting-outputs >>"%STEP_LOG%" 2>&1
call :end_step
if "%RC%"=="0" goto :step5_ok
echo(
echo       'dart run build_runner' returned %RC%. Trying the older
echo       command 'flutter pub run build_runner' before giving up...
call :begin_step "5/6" "build_runner (flutter pub run, fallback)"
call flutter pub run build_runner build --delete-conflicting-outputs >>"%STEP_LOG%" 2>&1
call :end_step
if not "%RC%"=="0" goto :fail_codegen
:step5_ok
echo       Database code is ready.
call "%SHOW_HELP%" "%ROOT%help_zh\05_codegen.txt"

REM ============================================================
REM  STEP 6 - build and launch on the phone / emulator
REM ============================================================
echo(
echo [6/6] Building and starting the app...
call "%SHOW_HELP%" "%ROOT%help_zh\06_run.txt"
echo       NOTE: this last step is interactive, so its output is shown live
echo       here on screen instead of inside build_run.log. Only the exit
echo       code is recorded in the log.
echo(
>>"%LOG%" echo.
>>"%LOG%" echo [6/6] flutter run (interactive, live on screen)
call flutter run
set "RC=%ERRORLEVEL%"
>>"%LOG%" echo [6/6] flutter run finished with exit code %RC%
if "%RC%"=="0" goto :all_done
echo(
echo       flutter run stopped with exit code %RC%. The reason is printed
echo       just above. Common causes: no phone connected, USB debugging
echo       off, or a Gradle download that needs the proxy.
>>"%LOG%" echo       see the console output for the failure reason

:all_done
echo(
echo ============================================================
echo   FINISHED.  Full log: %LOG%
echo ============================================================
goto :the_end

REM ============================================================
REM  FAILURE HANDLERS - each one explains what to do next
REM
REM  NOTE: the explanation text is kept short on purpose and stored in a
REM  variable first. A single command line in a .bat file must stay well
REM  under 255 characters, otherwise cmd.exe can no longer resolve the
REM  'call :label' targets later in the file.
REM ============================================================
:fail_no_flutter
set "M=Open a NEW command prompt and type:  flutter --version"
set "M=!M!  /  If that fails, Flutter is not installed."
set "M=!M!  Expected SDK folder is D:\flutter - add D:\flutter\bin to PATH, then restart Windows."
call :fail_pre "Flutter was not found on your PATH." "%M%"
goto :the_end

:fail_no_dart
set "M=The Dart SDK ships inside Flutter. Fix the Flutter PATH first:"
set "M=!M!  add D:\flutter\bin to PATH, then restart Windows."
call :fail_pre "'dart' was not found on your PATH." "%M%"
goto :the_end

:fail_no_powershell
set "M=This script uses PowerShell for one small job: adding the permissions."
set "M=!M!  PowerShell ships with Windows 10 and 11."
set "M=!M!  Try right-clicking the script and choosing Run as administrator."
call :fail_pre "PowerShell was not found." "%M%"
goto :the_end

:fail_no_pubspec
set "M=The script must run inside the project folder."
set "M=!M!  Expected location:"
set "M=!M!  D:\work_photos\pubspec.yaml"
call :fail_pre "pubspec.yaml is missing." "%M%"
goto :the_end

:fail_create
set "M=This step generates the android\ folder. Read the log lines above."
set "M=!M!  Most common cause: no internet, or the wrong proxy port."
set "M=!M!  Edit PROXY_PORT near the top of this script."
set "M=!M!  If android\ exists but is broken, delete the android\ folder and run this again."
call :fail_step "2/6" "flutter create --platforms android ." "%M%"
goto :the_end

:fail_no_manifest
set "M=Expected file: android\app\src\main\AndroidManifest.xml"
set "M=!M!  Delete the android\ folder and double-click this script again,"
set "M=!M!  so flutter create can rebuild it."
call :fail_step "3/6" "AndroidManifest.xml was not created." "%M%"
goto :the_end

:fail_no_helper
set "M=The permission helper script was deleted or moved."
set "M=!M!  Restore tools\inject_permissions.ps1 next to this .bat file,"
set "M=!M!  or add the two permission lines to AndroidManifest.xml by hand."
call :fail_step "3/6" "tools\inject_permissions.ps1 is missing." "%M%"
goto :the_end

:fail_permissions
set "M=Read the messages above. Close any program that currently has"
set "M=!M!  AndroidManifest.xml open, such as Android Studio,"
set "M=!M!  then double-click this script again."
call :fail_step "3/6" "Adding the Android permissions failed." "%M%"
goto :the_end

:fail_pubget
set "M=The packages could not be downloaded. Usual causes:"
set "M=!M!  1. The proxy port is wrong - edit PROXY_PORT near the top of this script."
set "M=!M!  2. The proxy app is closed - open Clash and try again."
set "M=!M!  3. No internet at all - try a phone hotspot."
set "M=!M!  Nothing in your code was changed, so just fix the network and run it again."
call :fail_step "4/6" "flutter pub get failed." "%M%"
goto :the_end

:fail_codegen
set "M=This step reads every Dart file in lib\ and writes the generated database code."
set "M=!M!  It fails when a Dart file has a syntax or type error, NOT because of the network."
set "M=!M!  Look in the log above for lines starting with Error or error -"
set "M=!M!  they contain the file name and the line number."
set "M=!M!  Fix that file in lib\ , then double-click this script again."
set "M=!M!  The script stopped on purpose so that nothing else gets built"
set "M=!M!  on top of a broken database file."
call :fail_step "5/6" "build_runner failed." "%M%"
goto :the_end

REM ============================================================
REM  SUBROUTINES
REM ============================================================

REM :begin_step <n> <description>
REM   Prepares the per-step log file and writes a separator into build_run.log.
:begin_step
if exist "%STEP_LOG%" del /q "%STEP_LOG%" >nul 2>&1
>>"%LOG%" echo.
>>"%LOG%" echo ------------------------------------------------------------
>>"%LOG%" echo [%~1] %~2
goto :eof

REM :end_step
REM   Prints the step output on screen, appends it to build_run.log, and
REM   leaves the exit code of the step in RC for the caller to test.
REM   The exit code is captured on the FIRST line, before 'type' can
REM   overwrite it. !ERRORLEVEL! is used because the block below is parsed
REM   as a unit, so %ERRORLEVEL% would expand too late.
:end_step
set "RC=!ERRORLEVEL!"
if exist "%STEP_LOG%" (
    type "%STEP_LOG%"
    type "%STEP_LOG%" >>"%LOG%"
)
goto :eof

REM :backup_pubspec - keep one safety copy of pubspec.yaml before
REM                   'flutter create' touches the project. Copying the whole
REM                   lib\ folder is not needed: flutter create does not write
REM                   into an existing lib\ folder.
:backup_pubspec
if not exist "%ROOT%pubspec.yaml" goto :eof
if exist "%ROOT%pubspec.yaml.scriptbak" goto :eof
copy /Y "%ROOT%pubspec.yaml" "%ROOT%pubspec.yaml.scriptbak" >nul 2>&1
echo       Safety copy made: pubspec.yaml.scriptbak
goto :eof

REM :fail_pre <headline> <what to do>
:fail_pre
echo(
echo ============================================================
echo   STOPPED BEFORE ANYTHING WAS CHANGED.
echo ============================================================
echo   %~1
echo(
echo   WHAT TO DO:
echo   %~2
echo(
call "%SHOW_HELP%" "%ROOT%help_zh\99_errors.txt"
goto :eof

REM :fail_step <step> <command> <what to do>
:fail_step
echo(
echo ============================================================
echo   FAILED AT STEP %~1   (%~2)
echo ============================================================
echo(
echo   WHAT TO DO:
echo   %~3
echo(
echo   FULL LOG: %LOG%
echo(
call "%SHOW_HELP%" "%ROOT%help_zh\99_errors.txt"
goto :eof

REM :showzh <file> - REMOVED, see tools\show_help.bat
REM   The Chinese help display now lives in a separate batch file, because
REM   cmd.exe can fail to resolve an in-file "call :label" after several
REM   goto jumps. Calling another .bat file is reliable.

:the_end
echo(
echo Press any key to close this window...
pause >nul
endlocal
