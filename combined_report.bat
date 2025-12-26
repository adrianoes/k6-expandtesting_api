@echo off
REM combined_report.bat
REM Invoke the PowerShell combiner to build a timestamped general report.

setlocal
set PS_SCRIPT=%~dp0scripts\combine_reports.ps1

if not exist "%~dp0scripts\combine_reports.ps1" (
    echo PowerShell combiner not found: "%~dp0scripts\combine_reports.ps1"
    exit /b 2
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set rc=%ERRORLEVEL%

if %rc% EQU 0 (
    echo Combined report created.
    exit /b 0
) else (
    echo Failed to create combined report (exit %rc%).
    exit /b %rc%
)