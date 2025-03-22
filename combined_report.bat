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
