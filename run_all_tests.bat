@echo off
REM run_all_tests.bat
REM Usage: run_all_tests.bat [smoke|load|stress|spike|breakpoint|soak]
REM Default: smoke

setlocal enabledelayedexpansion

REM Get test type from argument or default to 'smoke'
set "K6_TEST_TYPE=%1"
if not defined K6_TEST_TYPE set "K6_TEST_TYPE=smoke"

echo Test type: !K6_TEST_TYPE!

REM Load Jira environment variables from GitHub secret or local file
if defined JIRA_API_SECRETS (
    REM GitHub Actions: parse the secret and set env vars
    echo Loading Jira configuration from GitHub secret...
    for /f "tokens=*" %%a in ('echo %JIRA_API_SECRETS%') do (
        if "%%a" neq "" (
            setlocal enabledelayedexpansion
            set "line=%%a"
            REM Parse key=value format
            for /f "tokens=1,2 delims==" %%b in ("!line!") do (
                set "%%b=%%c"
            )
        )
    )
) else if exist "..\set_jira_env.bat" (
    REM Local development: load from set_jira_env.bat
    echo Loading Jira configuration from set_jira_env.bat...
    call ..\set_jira_env.bat
) else (
    echo Warning: No Jira configuration found. Tests will run but Jira issues won't be created.
)

pushd tests
if not exist "..\reports" mkdir "..\reports"

for %%f in (*.js) do (
    set "TESTNAME=%%~nf"
    echo Running the test: %%f with profile: !K6_TEST_TYPE!
    k6 run --env K6_TEST_NAME=!TESTNAME! --env K6_TEST_TYPE=!K6_TEST_TYPE! "%%f"
)

popd
endlocal
