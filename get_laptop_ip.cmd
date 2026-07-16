@echo off
REM Show all IPv4 addresses this laptop has, so you know what to point
REM the desktop's browser at.
echo.
echo === All IPv4 addresses on this laptop ===
echo.
powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } | Sort-Object InterfaceMetric | Select-Object InterfaceAlias, IPAddress, PrefixOrigin | Format-Table -AutoSize"
echo.
echo Look for one that starts with 192.168.* or 10.* - that's your LAN IP.
echo On the desktop, open:   http://^<that-ip^>:8090/
echo.
pause
