# k6-expandtesting_api

API testing in [expandtesting](https://practice.expandtesting.com/notes/api/api-docs/). This project contains basic examples on how to use K6 to test performance API tests. 

# Pre-requirements:

| Requirement                     | Version        | Note                 |
| :------------------------------ |:---------------| :------------------- |
| Visual Studio Code              | 1.107.1        | -                    |
| K6                              | 1.4.0          | -                    | 
| GitHub Copilot Chat             | 0.35.2         | -                    | 

# Installation:

- See [Visual Studio Code page](https://code.visualstudio.com/) and install the latest VSC stable version. Keep all the prefereced options as they are until you reach the possibility to check the checkboxes below: 
  - :white_check_mark: Add "Open with code" action to Windows Explorer file context menu. 
  - :white_check_mark: Add "Open with code" action to Windows Explorer directory context menu.
Check then both to add both options in context menu.
- See [K6 page](https://grafana.com/docs/k6/latest/set-up/install-k6/) and install it by downloading and executing the latest installer. Perform the installation by letting all the preferenced configurations unchanged. 

# Tests

- First, set Jira variables (once per session): from the tests directory run ```. ..\set_jira_env.ps1```
- Run all tests (default smoke):
    - From tests: ```..\run_all_tests.bat```
    - With profile (from tests): ```..\run_all_tests.bat load``` (profiles: smoke, load, stress, spike, breakpoint, soak)
- Run specific tests (without Jira):
    - Single (from tests): ```..\run_tc.bat 001 smoke```
    - Multiple (from tests): ```..\run_tc.bat 001 020 140 load```
 Run specific tests with Jira issue + HTML report attached (automatic):
     - Prerequisite: variables set with ```. ..\set_jira_env.ps1```
     - From tests: ```. ..\run_test.ps1 -TestIds 001,020 -Profile smoke```
     - Outcome: creates Jira issues for failures and attaches the matching HTML in reports/.
 Run all tests with Jira issue + HTML report attached (automatic):
     - Prerequisite: variables set with ```. ..\set_jira_env.ps1```
     - From tests (default smoke): ```. ..\run_test.ps1 -AllTests```
     - From tests with profile: ```. ..\run_test.ps1 -AllTests -Profile load```
 Default profile note: if -Profile is omitted, tests run as smoke.
- Default profile note: if -Profile is omitted, tests run as smoke.
- Filter by tag (e.g., basic): from tests run ```Get-ChildItem *.js | ForEach-Object { if (Select-String -Path $_.Name -Pattern "basic" -Quiet) { k6 run $_.Name } }```
- Consolidate HTMLs (optional, CMD): from tests run ```..\combined_report.bat```
- Reports: generated in ```reports/```; filenames follow the pattern TCxxx_*.html.

# Support:

- [expandtesting API documentation page](https://practice.expandtesting.com/notes/api/api-docs/)
- [expandtesting API demonstration page](https://www.youtube.com/watch?v=bQYvS6EEBZc)
- [Running k6](https://grafana.com/docs/k6/latest/get-started/running-k6/)
- [Add multiple checks](https://grafana.com/docs/k6/latest/using-k6/checks/)
- [k6-reporter](https://github.com/benc-uk/k6-reporter)
- [Run Grafana k6 tests](https://github.com/marketplace/actions/run-grafana-k6-tests)
- [Grafana k6 REST and WS Play](https://test-api.k6.io/)
- [HTTP request testing with k6](https://circleci.com/blog/http-request-testing-with-k6/#k6-test-structure)
- [Performance testing with Grafana k6 and GitHub Actions](https://grafana.com/blog/2024/07/15/performance-testing-with-grafana-k6-and-github-actions/)
- [utils](https://grafana.com/docs/k6/latest/javascript-api/jslib/utils/)
- [JSON formatter](https://jsonformatter.org/)
- [GitHub Copilot in VS Code](https://code.visualstudio.com/docs/copilot/overview)
- [Tags and Groups](https://grafana.com/docs/k6/latest/using-k6/tags-and-groups/)

# Tips:

- **Important:** Before using the Jira reporter, you must source the ```..\ set_jira_env.ps1``` script from the C:\k6-expandtesting_api\tests directory using dot-sourcing: ```. ..\ set_jira_env.ps1```. This sets the required Jira environment variables (JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN, JIRA_PROJECT_KEY) for the current PowerShell session. Run this once per session before executing tests. Copy `set_jira_env.example.ps1` to `set_jira_env.ps1`, fill in your Jira credentials, and keep `set_jira_env.ps1` private (it's ignored by git).
- If the automatic Jira issue creation during test execution fails or doesn't trigger, use the backup script create_jira_issues_from_reports.ps1. This script scans the reports/ folder, parses HTML test reports, and creates Jira issues for any failed checks. Navigate to C:\k6-expandtesting_api\tests and execute ```..\create_jira_issues_from_reports.ps1``` after running tests. This is useful for retrying failed issue creations.
- UI and API tests to send password reset link to user's email and API tests to verify a password reset token and reset a user's password must be tested manually as they rely on e-mail verification. 
- K6 documentation is pleasant to the readers eyes. Have a look calmly.
- Use support .bat files for a better experience. 
