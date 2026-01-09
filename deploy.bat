@echo off
setlocal EnableExtensions EnableDelayedExpansion
pushd "%~dp0" >nul

set "REMOTE=origin"
set "BRANCH=main"

if not exist ".git" (
  echo ERROR: This folder is not a git repo.
  goto done_err
)

where git >nul 2>&1 || (
  echo ERROR: git not found in PATH.
  goto done_err
)

set "MSG=%~1"
if "%MSG%"=="" set "MSG=update"

echo [1/3] Staging changes...
git add -A

git diff --cached --quiet
if errorlevel 1 (
  echo [2/3] Commit: %MSG%
  git commit -m "%MSG%" || goto done_err
) else (
  echo [2/3] No changes to commit.
)

echo [3/3] Push to GitHub (Vercel auto-deploy)...
git push %REMOTE% %BRANCH% || goto done_err

echo DONE — Vercel is deploying 🚀
goto done_ok

:done_err
echo FAILED
popd >nul
exit /b 1

:done_ok
popd >nul
exit /b 0
