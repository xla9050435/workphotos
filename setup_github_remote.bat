@echo off
REM ============================================================
REM  setup_github_remote.bat
REM  One-time helper: connect this project to its GitHub repo
REM  and push. A browser login window pops up on first push.
REM  Usage: double-click, press Enter to accept the default URL.
REM ============================================================
setlocal
cd /d "%~dp0"
echo(
echo ============================================================
echo   WORK PHOTOS - GITHUB REMOTE SETUP
echo ============================================================
echo   This will push to:
echo     https://github.com/xla9050435/workphotos.git
echo   (create the repo on github.com first if you have not)
echo(
set "REPO=https://github.com/xla9050435/workphotos.git"
set /p ANSWER=Press Enter to push, or paste a different URL :
if not "%ANSWER%"=="" set "REPO=%ANSWER%"
git remote remove origin >nul 2>&1
git remote add origin %REPO%
echo(
echo   Pushing to %REPO% ...
git push -u origin main
if errorlevel 1 goto :push_failed
echo(
echo   DONE. Future pushes:  git push
goto :the_end
:push_failed
echo(
echo   Push failed. Common causes:
echo     1. Repo does not exist yet - create it at github.com/new
echo        name=workphotos, Private, NO README/.gitignore/license
echo     2. Login window dismissed - run this script again
echo     3. Proxy issue - make sure Clash is running on port 7897
:the_end
echo(
pause
endlocal
