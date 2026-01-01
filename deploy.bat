@echo off
setlocal EnableExtensions EnableDelayedExpansion
pushd "%~dp0" >nul

set "REMOTE=origin"
set "BRANCH=main"
set "ENV_FILE=.env.local"

if /I "%~1"=="setup" goto setup

REM --- hard check: must have .git folder here
if not exist ".git" (
  echo ERROR: .git not found in "%cd%".
  echo Tip: deploy.bat must be in the repo root.
  popd >nul
  exit /b 1
)

REM --- verify git is callable
where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: git not found in PATH.
  echo Fix: install Git for Windows or reopen terminal after install.
  popd >nul
  exit /b 1
)

set "MSG=%~1"
if "%MSG%"=="" set "MSG=deploy update"

git add -A

git diff --cached --quiet
if errorlevel 1 (
  echo [1/3] Commit: %MSG%
  git commit -m "%MSG%"
  if errorlevel 1 goto err
) else (
  echo [1/3] No changes to commit.
)

echo [2/3] Push: %REMOTE% %BRANCH%
git push %REMOTE% %BRANCH%
if errorlevel 1 goto err

REM --- read hook from .env.local
set "HOOK_URL="
if exist "%ENV_FILE%" (
  for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    if /I "%%A"=="CLOUDFLARE_DEPLOY_HOOK_URL" set "HOOK_URL=%%B"
  )
)

set "HOOK_URL=%HOOK_URL:"=%"

if not "%HOOK_URL%"=="" (
  echo [3/3] Trigger Cloudflare Pages deploy hook...
  curl -s -X POST "%HOOK_URL%" >nul
  if errorlevel 1 (
    echo WARNING: Deploy hook call failed. Your push may still auto-deploy.
  ) else (
    echo Deploy hook triggered.
  )
) else (
  echo [3/3] Cloudflare deploy hook not set. (OK if auto-deploy is enabled)
  echo Tip: run "deploy.bat setup" to save your Deploy Hook URL.
)

echo DONE
popd >nul
exit /b 0

:setup
echo === Cloudflare Pages Deploy Hook Setup ===
set /p INPUT=Paste your CLOUDFLARE_DEPLOY_HOOK_URL (or leave blank to skip):

if "%INPUT%"=="" (
  echo Skipped.
  popd >nul
  exit /b 0
)

> "%ENV_FILE%" echo CLOUDFLARE_DEPLOY_HOOK_URL=%INPUT%
echo Saved: CLOUDFLARE_DEPLOY_HOOK_URL=******
echo SETUP DONE. Next: deploy.bat "update"
popd >nul
exit /b 0

:err
echo FAILED (see error above)
popd >nul
exit /b 1
