@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Always run from the script directory (repo root)
cd /d "%~dp0"

REM Debug (optional)
REM echo Running in: "%cd%"

set REMOTE=origin
set ENV_FILE=.env.local

if /I "%~1"=="setup" goto setup

REM --- must be inside git repo
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  echo ERROR: Not a git repository in "%cd%".
  exit /b 1
)

for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set BRANCH=%%b

git remote get-url %REMOTE% >nul 2>&1
if errorlevel 1 (
  echo ERROR: Remote "%REMOTE%" not found.
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

REM --- Optional: trigger Cloudflare Pages Deploy Hook from .env.local
set HOOK_URL=
if exist "%ENV_FILE%" (
  for /f "usebackq tokens=1,* delims==" %%A in (`findstr /I /B "CLOUDFLARE_DEPLOY_HOOK_URL=" "%ENV_FILE%" 2^>nul`) do (
    set HOOK_URL=%%B
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
  echo Tip: run "deploy.bat setup" to save your Deploy Hook URL.
)

echo DONE
exit /b 0

:setup
echo === Cloudflare Pages Deploy Hook Setup ===
set /p INPUT=Paste your CLOUDFLARE_DEPLOY_HOOK_URL (or leave blank to skip): 

if "%INPUT%"=="" (
  echo Skipped.
  exit /b 0
)

REM Replace or add the key in .env.local
if exist "%ENV_FILE%" (
  del /q "%ENV_FILE%.tmp" >nul 2>&1
  for /f "usebackq delims=" %%L in ("%ENV_FILE%") do (
    echo %%L | findstr /I /B "CLOUDFLARE_DEPLOY_HOOK_URL=" >nul
    if errorlevel 1 echo %%L>>"%ENV_FILE%.tmp"
  )
  echo CLOUDFLARE_DEPLOY_HOOK_URL=%INPUT%>>"%ENV_FILE%.tmp"
  move /y "%ENV_FILE%.tmp" "%ENV_FILE%" >nul
) else (
  echo CLOUDFLARE_DEPLOY_HOOK_URL=%INPUT%>"%ENV_FILE%"
)

echo Saved: CLOUDFLARE_DEPLOY_HOOK_URL=******
echo SETUP DONE. Next: deploy.bat "update"
exit /b 0

:err
echo FAILED (see error above)
exit /b 1
