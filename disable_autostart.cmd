@echo off
setlocal
set "STUB=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\MATAM_PocketBase.cmd"
if not exist "%STUB%" (
    echo Auto-start is not registered. Nothing to do.
    pause
    exit /b 0
)
del "%STUB%"
echo Auto-start removed:  %STUB%
pause
endlocal
