@echo off
setlocal EnableExtensions EnableDelayedExpansion
pushd "%~dp0" >nul

set "REMOTE=origin"
set "BRANCH=main"
set "ENV_FILE=.env.local"

if /I "%~1"=="setup" goto setup
if /I "%~1"=="hook"  goto hookonly

REM --- hard check: must have .git folder here
if not exist ".git" (
  echo ERROR: .git not found in "%cd%".
  echo Tip: deploy.bat must be in the repo root.
  goto done_err
)

REM --- verify git is callable
where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: git not found in PATH.
  goto done_err
)

set "MSG=%~1"
if "%MSG%"=="" set "MSG=deploy update"

git add -A

git diff --cached --quiet
if errorlevel 1 (
  echo [1/3] Commit: %MSG%
  git commit -m "%MSG%"
  if errorlevel 1 goto done_err
) else (
  echo [1/3] No changes to commit.
)

echo [2/3] Push: %REMOTE% %BRANCH%
git push %REMOTE% %BRANCH%
if errorlevel 1 goto done_err

call :read_hook
call :trigger_hook
goto done_ok

:hookonly
call :read_hook
call :trigger_hook
goto done_ok

REM =========================
REM Helpers
REM =========================
:read_hook
set "HOOK_URL="
if exist "%ENV_FILE%" (
  for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    set "K=%%A"
    set "V=%%B"
    REM trim spaces around key
    for /f "tokens=* delims= " %%k in ("!K!") do set "K=%%k"
    REM trim spaces around value
    for /f "tokens=* delims= " %%v in ("!V!") do set "V=%%v"
    if /I "!K!"=="CLOUDFLARE_DEPLOY_HOOK_URL" set "HOOK_URL=!V!"
  )
)
REM remove quotes if any
set "HOOK_URL=%HOOK_URL:"=%"
exit /b 0

:trigger_hook
if "%HOOK_URL%"=="" (
  echo Tip: run "deploy.bat setup" to save your Deploy Hook URL.
  exit /b 0
)

echo [3/3] Trigger Cloudflare Pages deploy hook...

where curl >nul 2>&1
if not errorlevel 1 (
  curl -s -X POST "%HOOK_URL%" >nul
  if errorlevel 1 (
    echo WARNING: Deploy hook call failed. Your push may still auto-deploy.
  ) else (
    echo Deploy hook triggered.
  )
  exit /b 0
)

powershell -NoProfile -Command "try { Invoke-WebRequest -Method POST -Uri '%HOOK_URL%' -UseBasicParsing | Out-Null; exit 0 } catch { exit 1 }"
if errorlevel 1 (
  echo WARNING: Deploy hook call failed (PowerShell). Your push may still auto-deploy.
) else (
  echo Deploy hook triggered.
)
exit /b 0

REM =========================
REM Setup
REM =========================
:setup
echo === Cloudflare Pages Deploy Hook Setup ===
set /p INPUT=Paste your CLOUDFLARE_DEPLOY_HOOK_URL (or leave blank to skip):

REM trim leading spaces
for /f "tokens=* delims= " %%i in ("%INPUT%") do set "INPUT=%%i"

if "%INPUT%"=="" (
  echo Skipped.
  goto done_ok
)

REM write clean file (single line, no extra junk)
> "%ENV_FILE%" (echo CLOUDFLARE_DEPLOY_HOOK_URL=%INPUT%)

echo Saved: CLOUDFLARE_DEPLOY_HOOK_URL=******
echo SETUP DONE. Next: deploy.bat "update"
goto done_ok

:done_err
echo FAILED (see error above)
popd >nul
exit /b 1

:done_ok
echo DONE
popd >nul
exit /b 0
