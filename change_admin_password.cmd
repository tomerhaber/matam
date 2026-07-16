@echo off
REM ===================================================================
REM  Change the PocketBase superuser (admin) password.
REM  Works whether PocketBase is running or not.
REM ===================================================================
setlocal
cd /d "%~dp0"

if not exist "pocketbase.exe" (
    echo [ERROR] pocketbase.exe not found in %CD%.
    pause
    exit /b 1
)

echo.
echo Change the MATAM admin account.
echo (This is the superuser used at http://<server>:8090/_/)
echo.

set /p ADMIN_EMAIL="Admin email [admin@matam.local]: "
if "%ADMIN_EMAIL%"=="" set ADMIN_EMAIL=admin@matam.local

set /p ADMIN_PW="New password: "
if "%ADMIN_PW%"=="" (
    echo [ERROR] Password cannot be empty.
    pause
    exit /b 1
)

REM upsert works whether the account exists or not
pocketbase.exe superuser upsert "%ADMIN_EMAIL%" "%ADMIN_PW%" --dir "pb_data"

if errorlevel 1 (
    echo [ERROR] Failed to update admin.
    pause
    exit /b 2
)

echo.
echo Admin password updated for %ADMIN_EMAIL%.
echo Log in at http://127.0.0.1:8090/_/ to test.
echo.
echo If you plan to run install_server.cmd again in the future, remember
echo to also update ADMIN_PASSWORD in deploy_config.env so the schema
echo bootstrap keeps working.
echo.
pause
endlocal
