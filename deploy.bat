@echo off
setlocal
pushd "%~dp0" >nul

set "REMOTE=origin"
set "BRANCH=main"

set "MSG=%~1"
if "%MSG%"=="" set "MSG=update"

echo [1/4] Staging changes...
git add -A

git diff --cached --quiet
if errorlevel 1 (
  echo [2/4] Commit: %MSG%
  git commit -m "%MSG%" || goto done_err
) else (
  echo [2/4] No changes to commit.
)

echo [3/4] Sync with remote (rebase)...
git pull --rebase %REMOTE% %BRANCH%
if errorlevel 1 goto done_err

echo [4/4] Push to GitHub (Cloudflare Pages auto-deploy)...
git push %REMOTE% %BRANCH% || goto done_err

echo DONE — GitHub updated; Cloudflare Pages will deploy 🚀
goto done_ok

:done_err
echo FAILED
popd >nul
exit /b 1

:done_ok
popd >nul
exit /b 0
