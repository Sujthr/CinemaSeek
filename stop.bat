@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  CinemaSeek — Stop Script (Windows)
::  Kills LLMGatewayV7 (port 8107) if running.
:: ============================================================

set GATEWAY_URL=http://localhost:8107

echo.
echo  ========================================
echo   CinemaSeek ^| Stop
echo  ========================================
echo.

:: ── Check if gateway is running ──────────────────────────────
curl -s -o nul -w "%%{http_code}" %GATEWAY_URL%/v1/routers > "%TEMP%\gw_status.txt" 2>nul
set /p GW_STATUS=<"%TEMP%\gw_status.txt"

if not "%GW_STATUS%"=="200" (
    echo  [INFO] LLMGatewayV7 is not running on port 8107.
    goto :done
)

echo  [INFO] Stopping LLMGatewayV7 on port 8107 ...

:: Find and kill the process listening on port 8107
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8107 " ^| findstr "LISTENING"') do (
    echo  [INFO] Killing PID %%p
    taskkill /PID %%p /F >nul 2>&1
)

:: Also kill any uv run main.py process that may be running in the gateway window
:: (taskkill by window title as a belt-and-suspenders approach)
taskkill /FI "WINDOWTITLE eq LLMGatewayV7" /F >nul 2>&1

:: Verify it stopped
timeout /t 2 /nobreak >nul
curl -s -o nul -w "%%{http_code}" %GATEWAY_URL%/v1/routers > "%TEMP%\gw_status.txt" 2>nul
set /p GW_STATUS=<"%TEMP%\gw_status.txt"

if "%GW_STATUS%"=="200" (
    echo  [WARN] Gateway may still be running. Check Task Manager if needed.
) else (
    echo  [OK] LLMGatewayV7 stopped.
)

:done
echo.
echo  ========================================
echo   CinemaSeek stopped.
echo  ========================================
echo.
endlocal
