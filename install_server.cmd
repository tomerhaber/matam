@echo off
REM ===================================================================
REM  MATAM Car System - Server one-click installer  (idempotent)
REM
REM  Usage:
REM    install_server.cmd                   - interactive
REM    install_server.cmd --user yes        - non-interactive, create admin user
REM    install_server.cmd --user no         - non-interactive, only superuser
REM
REM  Reads deploy_config.env for defaults (ADMIN_EMAIL, ADMIN_PASSWORD,
REM  BIND, CREATE_INITIAL_USER) if present.
REM ===================================================================
setlocal
cd /d "%~dp0"

echo.
echo =====================================================
echo   MATAM Server Install
echo =====================================================
echo.

REM ---- 1. Preflight ---------------------------------------------------
if not exist "pocketbase.exe" (
    echo [ERROR] pocketbase.exe not found in %CD%
    pause
    exit /b 1
)
if not exist "collections_schema.json" (
    echo [ERROR] collections_schema.json not found.
    pause
    exit /b 1
)
if not exist "setup_schema.ps1" (
    echo [ERROR] setup_schema.ps1 not found.
    pause
    exit /b 1
)
if not exist "pb_public\index.html" (
    echo [WARN] pb_public\index.html not found - server will start but nothing to serve.
    echo.
)

REM ---- 2. Config defaults + load from deploy_config.env --------------
set "ADMIN_EMAIL=admin@matam.local"
set "ADMIN_PASS=matam2026"
set "BIND=0.0.0.0:8090"
set "CREATE_INITIAL_USER=ask"
if exist "deploy_config.env" (
    for /f "usebackq tokens=1,* delims==" %%A in ("deploy_config.env") do (
        if /I "%%A"=="ADMIN_EMAIL"          set "ADMIN_EMAIL=%%B"
        if /I "%%A"=="ADMIN_PASSWORD"       set "ADMIN_PASS=%%B"
        if /I "%%A"=="BIND"                 set "BIND=%%B"
        if /I "%%A"=="CREATE_INITIAL_USER"  set "CREATE_INITIAL_USER=%%B"
    )
)

REM ---- CLI override:  --user yes  or  --user no ----------------------
if /I "%~1"=="--user" set "CREATE_INITIAL_USER=%~2"

REM ---- Interactive prompt only when we truly don't know --------------
if /I "%CREATE_INITIAL_USER%"=="ask" (
    set /p _tmpUser="Create the initial admin manager account (email + password from deploy_config.env)? [Y/n]: "
    call :setuser %%_tmpUser%%
)

REM ---- Normalize to yes/no -------------------------------------------
call :normalize_yesno "%CREATE_INITIAL_USER%"
set "CREATE_INITIAL_USER=%_RESULT%"

echo Admin email      : %ADMIN_EMAIL%
echo Server bind addr : %BIND%
echo Initial user     : %CREATE_INITIAL_USER%   (creates a manager account in the app)
echo.

REM ---- 3. Stop any running PB (release DB lock) ----------------------
echo [1/7] Stopping any running PocketBase process...
taskkill /F /IM pocketbase.exe >nul 2>&1
timeout /t 1 /nobreak >nul

REM ---- 4. Create/update superuser via CLI ----------------------------
echo [2/7] Creating/updating superuser %ADMIN_EMAIL%...
pocketbase.exe superuser upsert "%ADMIN_EMAIL%" "%ADMIN_PASS%" --dir "pb_data"
if errorlevel 1 (
    echo [ERROR] superuser upsert failed. See message above.
    pause
    exit /b 2
)

REM ---- 5. Start PocketBase in background -----------------------------
echo [3/7] Starting PocketBase on %BIND%...
start "PocketBase" /min pocketbase.exe serve --http "%BIND%" --dir "pb_data" --publicDir "pb_public"

REM ---- 6. Wait for /api/health ---------------------------------------
echo [4/7] Waiting for PocketBase to be ready...
set /a TRIES=0
:waitloop
set /a TRIES+=1
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8090/api/health' -UseBasicParsing -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto ready
if %TRIES% GEQ 30 (
    echo [ERROR] PocketBase did not become ready within 30 seconds.
    pause
    exit /b 3
)
timeout /t 1 /nobreak >nul
goto waitloop
:ready
echo         PocketBase is up.

REM ---- 7. Apply schema -----------------------------------------------
echo [5/7] Applying collection schema...
set "USER_FLAG="
if /I "%CREATE_INITIAL_USER%"=="yes" set "USER_FLAG=-CreateInitialUser"
powershell -NoProfile -ExecutionPolicy Bypass -File "setup_schema.ps1" -PbUrl "http://127.0.0.1:8090" -AdminEmail "%ADMIN_EMAIL%" -AdminPass "%ADMIN_PASS%" -SchemaFile "collections_schema.json" -InitialUsersFile "initial_users.json" %USER_FLAG%
if errorlevel 1 (
    echo [ERROR] Schema setup failed. See PowerShell output above.
    pause
    exit /b 4
)

REM ---- 8. Register Windows auto-start --------------------------------
echo [6/7] Registering Windows auto-start...
call "%~dp0enable_autostart.cmd" quiet

REM ---- 9. Print URLs -------------------------------------------------
echo [7/7] Determining server URLs...
echo.
echo =====================================================
echo   Install complete.
echo =====================================================
echo.
echo Server is running on this PC. Client URLs:
call "%~dp0show_server_url.cmd" quiet
echo.
echo Admin UI on this PC ONLY:  http://127.0.0.1:8090/_/
if /I NOT "%CREATE_INITIAL_USER%"=="yes" goto skip_user_note
echo.
echo Log in with:
echo    Email    : %ADMIN_EMAIL%
echo    Password : (as set in deploy_config.env)
echo    Role     : manager  ^(can create additional users inside the app^)
echo.
echo Once logged in, open Settings -^> User Management to create employees.
:skip_user_note
echo.
echo Next steps:
echo    - Right-click enable_firewall.cmd and choose Run as administrator
echo    - On each client, open one of the URLs above in a browser
echo      or copy client\install_client_shortcut.cmd to that machine
echo.
pause
goto :eof

REM ---- helper: normalize yes/no value --------------------------------
:normalize_yesno
set "_RESULT=no"
if /I "%~1"=="y"     set "_RESULT=yes"
if /I "%~1"=="yes"   set "_RESULT=yes"
if /I "%~1"=="true"  set "_RESULT=yes"
if /I "%~1"=="1"     set "_RESULT=yes"
if /I "%~1"==""      set "_RESULT=yes"
goto :eof

REM ---- helper: set user choice from prompt string --------------------
:setuser
set "CREATE_INITIAL_USER=%~1"
if "%CREATE_INITIAL_USER%"=="" set "CREATE_INITIAL_USER=yes"
goto :eof
