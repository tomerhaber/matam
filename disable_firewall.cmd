@echo off
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Must be run as Administrator.
    pause
    exit /b 1
)
netsh advfirewall firewall delete rule name="MATAM_PocketBase"
pause
