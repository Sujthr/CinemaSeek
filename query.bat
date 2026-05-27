@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  CinemaSeek — Query Wrapper (Windows)
::  Usage:  query.bat "your question here"
::  Example: query.bat "Which films deal with non-linear time?"
:: ============================================================

set PROJECT_DIR=%~dp0

if "%~1"=="" (
    echo.
    echo  Usage:  query.bat "your question here"
    echo.
    echo  Examples:
    echo    query.bat "I want to watch something nostalgic and warm..."
    echo    query.bat "Which films deal with non-linear time?"
    echo    query.bat "Compare Bollywood and Hollywood class-conflict films"
    echo.
    exit /b 1
)

cd /d "%PROJECT_DIR%"
uv run agent7.py %*
endlocal
