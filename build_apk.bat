@echo off
REM ============================================================
REM  build_apk.bat
REM  Builds an installable Android APK (release build by default).
REM  Usage:
REM     build_apk.bat            - release APK (recommended)
REM     build_apk.bat debug      - debug APK (smaller, keeps debug symbols)
REM
REM  HOW OUTPUT IS HANDLED
REM    Each step writes to a small temporary file first. That file is then
REM    printed on screen AND appended to build_apk.log. This avoids paging
REM    tools and line counting, so logging can never block or break a step.
REM
REM  IMPORTANT NOTES
REM   * THIS FILE MUST STAY ASCII / ENGLISH ONLY. Chinese text inside a
REM     .bat file breaks on some Windows code pages. All Chinese help
REM     lives in the help_zh\ folder as UTF-8 files instead.
REM   * Every step checks ERRORLEVEL and stops on failure.
REM   * Safe to run again and again (idempotent).
REM ============================================================

setlocal EnableExtensions EnableDelayedExpansion

REM ------------------------------------------------------------
REM  >>> USER SETTINGS - this is the only part you may need to edit
REM
REM  PROXY_PORT : the local port of your Clash / VPN client.
REM               Open your proxy app, look at its settings page,
REM               and change the number below if it is not 7897.
REM ------------------------------------------------------------
set "PROXY_HOST=127.0.0.1"
set "PROXY_PORT=7897"

REM ------------------------------------------------------------
REM  Do not change anything below this line.
REM ------------------------------------------------------------
REM --- Which build flavour? "release" unless the user says "debug" ---
set "FLAVOUR=release"
if "%~1"=="debug"     set "FLAVOUR=debug"
if "%~1"=="--debug"   set "FLAVOUR=debug"
if "%~1"=="release"   set "FLAVOUR=release"
if "%~1"=="--release" set "FLAVOUR=release"

REM --- Note: PATH entries must be FOLDERS, never a path to a .bat file ---
set "FLUTTER_BIN_DIR=D:\flutter\bin"
set "FLUTTER_FALLBACK=%FLUTTER_BIN_DIR%\flutter.bat"
set "DART_BIN_DIR=%FLUTTER_BIN_DIR%\cache\dart-sdk\bin"
set "JAVA_HOME=D:\jdk-17.0.14+7"
set "ANDROID_SDK_DIR=C:\Users\19629\AppData\Local\Android\Sdk"
set "ANDROID_HOME=%ANDROID_SDK_DIR%"

set "ROOT=%~dp0"
REM This script writes its OWN log file on purpose. build_and_run.bat uses
REM build_run.log; sharing one file would mean that packaging an APK destroys
REM the run log the user was about to send for debugging.
set "LOG=%ROOT%build_apk.log"
set "STEP_LOG=%TEMP%\work_photos_apk_step.log"
set "PS_SCRIPT=%ROOT%tools\inject_permissions.ps1"
set "SHOW_HELP=%ROOT%tools\show_help.bat"
set "MANIFEST=%ROOT%android\app\src\main\AndroidManifest.xml"
set "APK_DIR=%ROOT%build\app\outputs\flutter-apk\"

title Work Photos - Build APK

cd /D "%ROOT%"

REM --- Proxy environment variables ---
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
>>"%LOG%" echo  build_apk.bat started  %DATE% %TIME%
>>"%LOG%" echo  Folder  : %ROOT%
>>"%LOG%" echo  Proxy   : %HTTP_PROXY%
>>"%LOG%" echo  Flavour : %FLAVOUR%
>>"%LOG%" echo ============================================================

echo(
echo ============================================================
echo   WORK PHOTOS  -  BUILD APK   [%FLAVOUR%]
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
echo   of build_apk.bat and double-click it again.
echo(

REM ============================================================
REM  STEP 1 - pre-flight checks
REM  Note: each check runs exactly once. There is deliberately no
REM  retry loop, because re-testing 'where flutter' in a loop would
REM  spin forever.
REM ============================================================
echo(
echo [1/4] Checking the environment...
>>"%LOG%" echo.
>>"%LOG%" echo [1/4] pre-flight checks

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

where powershell >nul 2>&1
if errorlevel 1 goto :fail_no_powershell

if not exist "%ROOT%pubspec.yaml" goto :fail_no_pubspec

echo       Flutter SDK : found
echo       PowerShell  : found
echo       Project     : pubspec.yaml found

REM ============================================================
REM  STEP 2 - android\ folder + permissions (both idempotent)
REM ============================================================
echo(
echo [2/4] Preparing the Android project and the permissions...
if exist "%MANIFEST%" goto :step2_perm
echo       android\ not found yet - running flutter create now.
echo       It only adds the missing Android files.
echo       Your lib\ code is never overwritten.
call :backup_pubspec
call :begin_step "2/4" "flutter create --platforms android ."
call flutter create --platforms android . >>"%STEP_LOG%" 2>&1
call :end_step
if not "%RC%"=="0" goto :fail_create
:step2_perm
if not exist "%MANIFEST%" goto :fail_no_manifest
if not exist "%PS_SCRIPT%" goto :fail_no_helper
call :begin_step "2/4" "inject Android permissions"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -ManifestPath "%MANIFEST%" >>"%STEP_LOG%" 2>&1
call :end_step
if not "%RC%"=="0" goto :fail_permissions
echo       Android project and permissions are ready.

REM ============================================================
REM  STEP 3 - dependencies + code generation
REM ============================================================
echo(
echo [3/4] Downloading packages and generating the database code...
echo       The first run downloads about 123 packages, this takes a while.
call :begin_step "3/4" "flutter pub get"
call flutter pub get >>"%STEP_LOG%" 2>&1
call :end_step
if not "%RC%"=="0" goto :fail_pubget

call :begin_step "3/4" "build_runner (dart run)"
call dart run build_runner build >>"%STEP_LOG%" 2>&1
call :end_step
if "%RC%"=="0" goto :step3_ok
echo(
echo       'dart run build_runner' returned %RC%. Trying the older
echo       command 'flutter pub run build_runner' before giving up...
call :begin_step "3/4" "build_runner (flutter pub run, fallback)"
call flutter pub run build_runner build >>"%STEP_LOG%" 2>&1
call :end_step
if not "%RC%"=="0" goto :fail_codegen
:step3_ok
echo       Packages and database code are ready.

REM ============================================================
REM  STEP 4 - build the APK
REM ============================================================
echo(
echo [4/4] Building the %FLAVOUR% APK. The first build can take 5-15 minutes.
call :begin_step "4/4" "flutter build apk --%FLAVOUR%"
call flutter build apk --%FLAVOUR% >>"%STEP_LOG%" 2>&1
call :end_step
if not "%RC%"=="0" goto :fail_build

call "%SHOW_HELP%" "%ROOT%help_zh\07_apk.txt"

echo(
echo ============================================================
echo   APK IS READY.
echo ============================================================
if exist "%APK_DIR%" goto :apk_listed
echo   The APK folder was not found at:
echo     %APK_DIR%
echo   Check build_apk.log for the real output path.
goto :apk_end
:apk_listed
echo   APK folder:
echo     %APK_DIR%
echo(
echo   Files inside:
dir /b "%APK_DIR%*.apk"
:apk_end
echo(
echo   To install on a phone:  adb install -r app-release.apk
echo   Or simply copy the .apk to the phone and tap it.
echo(
echo   Full log: %LOG%
goto :the_end

REM ============================================================
REM  FAILURE HANDLERS
REM
REM  NOTE: the explanation text is kept short on purpose and stored in a
REM  variable first. A single command line in a .bat file must stay well
REM  under 255 characters, otherwise cmd.exe can no longer resolve the
REM  'call :label' targets later in the file.
REM ============================================================
:fail_no_flutter
set "M=Open a NEW command prompt and type:  flutter --version"
set "M=!M!  /  If that fails, add D:\flutter\bin to PATH, then restart Windows."
call :fail_pre "Flutter was not found on your PATH." "%M%"
goto :the_end

:fail_no_powershell
set "M=This script uses PowerShell for one small job: adding the permissions."
set "M=!M!  PowerShell ships with Windows 10 and 11."
set "M=!M!  Try right-clicking the script and choosing Run as administrator."
call :fail_pre "PowerShell was not found." "%M%"
goto :the_end

:fail_no_pubspec
set "M=The script must run inside the project folder. Expected location:"
set "M=!M!  D:\work_photos\pubspec.yaml"
call :fail_pre "pubspec.yaml is missing." "%M%"
goto :the_end

:fail_create
set "M=This step generates the android\ folder. Most common cause:"
set "M=!M!  no internet, or the wrong proxy port."
set "M=!M!  Edit PROXY_PORT near the top of this script."
set "M=!M!  If android\ exists but is broken, delete it and try again."
call :fail_step "2/4" "flutter create --platforms android ." "%M%"
goto :the_end

:fail_no_manifest
set "M=Expected file: android\app\src\main\AndroidManifest.xml"
set "M=!M!  Delete the android\ folder and try again, so flutter create can rebuild it."
call :fail_step "2/4" "AndroidManifest.xml was not created." "%M%"
goto :the_end

:fail_no_helper
set "M=The permission helper script was deleted or moved."
set "M=!M!  Restore tools\inject_permissions.ps1 next to this .bat file,"
set "M=!M!  or add the two permission lines to AndroidManifest.xml by hand."
call :fail_step "2/4" "tools\inject_permissions.ps1 is missing." "%M%"
goto :the_end

:fail_permissions
set "M=Close any program that currently has AndroidManifest.xml open,"
set "M=!M!  such as Android Studio, then try again."
call :fail_step "2/4" "Adding the Android permissions failed." "%M%"
goto :the_end

:fail_pubget
set "M=The packages could not be downloaded. Usual causes:"
set "M=!M!  1. The proxy port is wrong - edit PROXY_PORT near the top of this script."
set "M=!M!  2. The proxy app is closed - open Clash and try again."
set "M=!M!  3. No internet at all - try a phone hotspot."
set "M=!M!  Nothing in your code was changed - fix the network and try again."
call :fail_step "3/4" "flutter pub get failed." "%M%"
goto :the_end

:fail_codegen
set "M=This step reads every Dart file in lib\ and writes the generated database code."
set "M=!M!  It fails when a Dart file has a syntax or type error, NOT because of the network."
set "M=!M!  Look in the log above for lines starting with Error or error -"
set "M=!M!  they contain the file name and the line number."
set "M=!M!  Fix that file in lib\ , then try again."
call :fail_step "3/4" "build_runner failed." "%M%"
goto :the_end

:fail_build
set "M=The Gradle build did not finish. Usual causes:"
set "M=!M!  1. The proxy blocked the Gradle / Maven download - edit PROXY_PORT at the top."
set "M=!M!  2. A Dart compile error - the log will name the file and the line."
set "M=!M!  3. The Android SDK or a JDK is missing - flutter doctor will say which one."
set "M=!M!  The full output is printed above and saved in build_apk.log."
call :fail_step "4/4" "flutter build apk failed." "%M%"
goto :the_end

REM ============================================================
REM  SUBROUTINES
REM ============================================================

REM :begin_step <n> <description>
REM   Prepares the per-step log file and writes a separator into build_apk.log.
:begin_step
if exist "%STEP_LOG%" del /q "%STEP_LOG%" >nul 2>&1
>>"%LOG%" echo.
>>"%LOG%" echo ------------------------------------------------------------
>>"%LOG%" echo [%~1] %~2
goto :eof

REM :end_step
REM   Prints the step output on screen, appends it to build_apk.log, and
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
REM                   'flutter create' touches the project.
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

:the_end
echo(
echo Press any key to close this window...
pause >nul
endlocal
