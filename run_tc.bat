@echo off
REM run_tc.bat
REM Usage: run_tc.bat TC001 [TC020 ...] [smoke|load|stress|spike|breakpoint|soak]
REM        run_tc.bat 001 020 [smoke|load|stress|spike|breakpoint|soak]
REM Default test type: smoke

if "%~1"=="" (
  echo Usage: %~nx0 TC001 [TC020 ...] [smoke^|load^|stress^|spike^|breakpoint^|soak]
  echo        %~nx0 001 020 [smoke^|load^|stress^|spike^|breakpoint^|soak]
  exit /b 1
)

rem Change directory to the repository's tests folder (script-location-relative)
pushd "%~dp0tests" || (echo Failed to change directory to %~dp0tests && exit /b 2)
if not exist "..\reports" mkdir "..\reports"

setlocal enabledelayedexpansion

REM Default profile
set "K6_TEST_TYPE=smoke"

REM First pass: detect profile token(s)
for %%a in (%*) do (
    set "tok=%%~a"
    for %%p in (smoke load stress spike breakpoint soak) do (
        if /I "!tok!"=="%%p" (
            set "K6_TEST_TYPE=%%p"
        )
    )
)

REM Second pass: run tests for non-profile tokens
for %%a in (%*) do (
    set "tok=%%~a"
    set "IS_TYPE="
    for %%p in (smoke load stress spike breakpoint soak) do (
        if /I "!tok!"=="%%p" set "IS_TYPE=1"
    )
    if not defined IS_TYPE (
        set "first=!tok:~0,2!"
        if /I "!first!"=="TC" (
            set "pat=!tok!*.js"
        ) else (
            set "pat=TC!tok!*.js"
        )

        set "found=0"
        for %%f in (!pat!) do (
            set "found=1"
            set "TESTNAME=%%~nf"
            echo Running %%f with profile: !K6_TEST_TYPE!
            k6 run --env K6_TEST_NAME=!TESTNAME! --env K6_TEST_TYPE=!K6_TEST_TYPE! "%%f"
        )
        if "!found!"=="0" echo No test files found for pattern: !pat!
    )
)
endlocal
popd
exit /b 0
