@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM =========================
REM CONFIG
REM =========================
set REMOTE=origin
set ENV_FILE=.env.local

REM =========================
REM SETUP MODE
REM Usage: deploy.bat setup
REM =========================
if /I "%~1"=="setup" goto setup

REM =========================
REM MAIN MODE
REM Usage: deploy.bat "message"
REM =========================
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  echo ERROR: Not a git repository.
  exit /b 1
)

for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set BRANCH=%%b

git remote get-url %REMOTE% >nul 2>&1
if errorlevel 1 (
  echo ERROR: Remote "%REMOTE%" not found.
  echo Fix: git remote add %REMOTE% ^<YOUR_GITHUB_REPO_URL^>
  exit /b 1
)

set MSG=%~1
if "%MSG%"=="" set MSG=deploy update

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

REM =========================
REM Optional: trigger Cloudflare Pages Deploy Hook
REM =========================
set HOOK_URL=
if exist "%ENV_FILE%" (
  for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    if /I "%%A"=="CLOUDFLARE_DEPLOY_HOOK_URL" set HOOK_URL=%%B
  )
)

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
  echo Tip: run ^"deploy.bat setup^" to save your Deploy Hook URL.
)

echo DONE
exit /b 0

:setup
echo === Cloudflare Pages Deploy Hook Setup ===
echo 1) In Cloudflare Pages: Settings ^> Builds ^& deployments ^> Deploy hooks
echo 2) Create a Deploy Hook and copy the URL
echo.

set /p INPUT=Paste your CLOUDFLARE_DEPLOY_HOOK_URL (or leave blank to skip): 

if "%INPUT%"=="" (
  echo Skipped. Auto-deploy will work on git push if enabled.
  exit /b 0
)

REM Create or update .env.local
if not exist "%ENV_FILE%" (
  echo CLOUDFLARE_DEPLOY_HOOK_URL=%INPUT%>"%ENV_FILE%"
) else (
  REM Remove existing key and rewrite
  (for /f "usebackq delims=" %%L in ("%ENV_FILE%") do (
    echo %%L | findstr /I /B "CLOUDFLARE_DEPLOY_HOOK_URL=" >nul
    if errorlevel 1 echo %%L
  )) > "%ENV_FILE%.tmp"
  echo CLOUDFLARE_DEPLOY_HOOK_URL=%INPUT%>>"%ENV_FILE%.tmp"
  move /y "%ENV_FILE%.tmp" "%ENV_FILE%" >nul
)

echo Saved in %ENV_FILE%:
echo CLOUDFLARE_DEPLOY_HOOK_URL=******

echo SETUP DONE. Next: deploy.bat "update"
exit /b 0

:err
echo FAILED (see error above)
exit /b 1
