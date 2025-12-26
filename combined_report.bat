@echo off
REM combined_report.bat
REM Invokes the PowerShell combiner to build a timestamped general report

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\combine_reports.ps1"

if %ERRORLEVEL% EQU 0 (
  echo Combined report created.
) else (
  echo Failed to create combined report (exit %ERRORLEVEL%).
)

pause
@echo off
REM combined_report.bat
REM Combines all HTML reports in the reports\ folder into a single
REM reports\general_report.html by invoking a PowerShell helper script.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\combine_reports.ps1"

if %ERRORLEVEL% EQU 0 (
  echo general_report.html created in reports\
) else (
  echo Failed to create general_report.html (exit %ERRORLEVEL%)
)

pause
@echo off
setlocal enabledelayedexpansion



:: Define the path for the combined report
set COMBINED_REPORT=.\reports\combined_report.html

:: Delete the previous combined report if it exists
if exist "!COMBINED_REPORT!" del "!COMBINED_REPORT!"

:: Create the initial HTML structure
echo ^<html^>^<head^>^<title^>Combined Report^</title^>^</head^>^<body^> > "!COMBINED_REPORT!"

:: Loop through all HTML files in the reports folder (excluding the combined report itself)
for %%f in (.\reports\*.html) do (
    if /I not "%%f"=="!COMBINED_REPORT!" (
        type "%%f" >> "!COMBINED_REPORT!"
    )
)

:: Close the HTML structure
echo ^</body^>^</html^> >> "!COMBINED_REPORT!"

echo Combined report successfully generated: !COMBINED_REPORT!