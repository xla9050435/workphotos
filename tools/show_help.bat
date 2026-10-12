@echo off
REM ============================================================
REM  show_help.bat  -  prints one UTF-8 Chinese help text file.
REM
REM  WHY THIS IS A SEPARATE FILE
REM    cmd.exe resolves "call :label" targets using a cached byte offset in
REM    the batch file. After several goto jumps that cache can go stale, and
REM    the call then fails with "The system cannot find the batch label".
REM    Calling a separate .bat file has no such problem, so the help display
REM    lives here and is reused by both build_and_run.bat and build_apk.bat.
REM
REM  Usage:  show_help.bat <file name inside the help_zh folder>
REM          example:  call show_help.bat 01_doctor.txt
REM
REM  The caller passes the FULL path as %1, so this script does not care
REM  what the current directory is.
REM
REM  This script is intentionally forgiving: if the text file or PowerShell
REM  is missing, it simply prints nothing and returns. A missing help text
REM  must never stop a build.
REM ============================================================

setlocal EnableExtensions DisableDelayedExpansion

if "%~1"=="" goto :done
if not exist "%~1" goto :done

where powershell >nul 2>&1
if errorlevel 1 goto :done

rem PowerShell reads the file as UTF-8 and writes it to the console using
rem the console's own code page. This avoids chcp switching, which is
rem locale dependent and can leave the console in a broken state.
powershell -NoProfile -Command "try { Get-Content -LiteralPath '%~1' -Encoding UTF8 -ErrorAction Stop } catch { exit 1 }"
echo(

:done
endlocal & exit /b 0
