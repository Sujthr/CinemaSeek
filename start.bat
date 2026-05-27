@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  CinemaSeek — Start Script (Windows)
::  Starts LLMGatewayV7, then optionally indexes the corpus.
:: ============================================================

set GATEWAY_DIR=D:\EAG\EAG\Class 23 May\LLMGateway\llm_gatewayV7
set GATEWAY_URL=http://localhost:8107
set PROJECT_DIR=%~dp0
set STATE_DIR=%PROJECT_DIR%state
set ENV_FILE=%PROJECT_DIR%.env

echo.
echo  ========================================
echo   CinemaSeek ^| Start
echo  ========================================

:: ── 1. Check .env ────────────────────────────────────────────
if not exist "%ENV_FILE%" (
    echo.
    echo  [WARN] .env not found. Copying from .env.example ...
    copy "%PROJECT_DIR%.env.example" "%ENV_FILE%" >nul
    echo  [WARN] Open .env and fill in your GEMINI_API_KEY before continuing.
    echo  [WARN] Press any key to continue anyway, or Ctrl+C to abort.
    pause >nul
)

:: ── 2. Check if gateway is already running ───────────────────
curl -s -o nul -w "%%{http_code}" %GATEWAY_URL%/v1/routers > "%TEMP%\gw_status.txt" 2>nul
set /p GW_STATUS=<"%TEMP%\gw_status.txt"
if "%GW_STATUS%"=="200" (
    echo  [OK] LLMGatewayV7 already running on %GATEWAY_URL%
    goto :check_index
)

:: ── 3. Start LLMGatewayV7 ────────────────────────────────────
echo.
echo  [INFO] Starting LLMGatewayV7 from:
echo         %GATEWAY_DIR%
echo.

if not exist "%GATEWAY_DIR%" (
    echo  [ERROR] Gateway directory not found: %GATEWAY_DIR%
    echo  [ERROR] Check the path in start.bat and update GATEWAY_DIR.
    exit /b 1
)

:: Copy .env to gateway dir so it picks up keys
if exist "%ENV_FILE%" (
    copy /Y "%ENV_FILE%" "%GATEWAY_DIR%\.env" >nul
)

start "LLMGatewayV7" /MIN cmd /c "cd /d "%GATEWAY_DIR%" && uv run main.py"

:: Wait up to 45 seconds for gateway to be ready
echo  [INFO] Waiting for gateway to be ready ...
set /a WAIT=0
:wait_loop
timeout /t 2 /nobreak >nul
set /a WAIT+=2
curl -s -o nul -w "%%{http_code}" %GATEWAY_URL%/v1/routers > "%TEMP%\gw_status.txt" 2>nul
set /p GW_STATUS=<"%TEMP%\gw_status.txt"
if "%GW_STATUS%"=="200" (
    echo  [OK] Gateway is up! (%WAIT%s)
    goto :check_index
)
if %WAIT% GEQ 45 (
    echo  [ERROR] Gateway failed to start within 45s.
    echo  [ERROR] Check the LLMGatewayV7 window for errors.
    exit /b 1
)
goto :wait_loop

:: ── 4. Index corpus if state/ is empty ───────────────────────
:check_index
echo.
if not exist "%STATE_DIR%\index.faiss" (
    echo  [INFO] No FAISS index found. Running corpus indexer ...
    echo  [INFO] This will take 5-15 minutes on first run.
    echo.
    cd /d "%PROJECT_DIR%"
    uv run index_corpus.py
    echo.
    echo  [OK] Corpus indexed. Index saved to state/
) else (
    echo  [OK] FAISS index already exists — skipping re-index.
    echo       (Delete state\ to force a full re-index)
)

:: ── 5. Done ──────────────────────────────────────────────────
echo.
echo  ========================================
echo   CinemaSeek is ready!
echo  ========================================
echo.
echo  Run a query:
echo    uv run agent7.py "I want to watch something nostalgic..."
echo.
echo  Or use query.bat:
echo    query.bat "Which films deal with non-linear time?"
echo.
echo  Gateway dashboard: %GATEWAY_URL%
echo.
endlocal
