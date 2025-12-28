@echo off
REM run_tc.bat
REM Usage: run_tc.bat TC001 TC020 140  etc. You can pass IDs with or without the TC prefix.

if "%~1"=="" (
  echo Usage: %~nx0 TC001 [TC020 ...]  or  %~nx0 001 020
  exit /b 1
)

rem Change directory to the repository's tests folder (script-location-relative)
pushd "%~dp0tests" || (echo Failed to change directory to %~dp0tests && exit /b 2)
if not exist "..\reports" mkdir "..\reports"

setlocal enabledelayedexpansion
for %%a in (%*) do (
    set "a=%%~a"
    set "first=!a:~0,2!"
    if /I "!first!"=="TC" (
        set "pat=!a!*.js"
    ) else (
        set "pat=TC!a!*.js"
    )

    set "found=0"
    for %%f in (!pat!) do (
        set "found=1"
        set "TESTNAME=%%~nf"
        echo Running %%f
        k6 run --env K6_TEST_NAME=!TESTNAME! "%%f"
    )
    if "!found!"=="0" echo No test files found for pattern: !pat!
)
endlocal
popd
exit /b 0
