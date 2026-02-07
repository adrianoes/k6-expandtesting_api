# k6-expandtesting_api

API testing in [expandtesting](https://practice.expandtesting.com/notes/api/api-docs/). This project contains basic examples on how to use K6 to test performance API tests. 

# Pre-requirements:

| Requirement                     | Version        | Note                 |
| :------------------------------ |:---------------| :------------------- |
| Visual Studio Code              | 1.107.1        | -                    |
| K6                              | 1.5.0          | -                    | 
| GitHub Copilot Chat             | 0.35.2         | -                    | 

# Installation:

- See [Visual Studio Code page](https://code.visualstudio.com/) and install the latest VSC stable version. Keep all the prefereced options as they are until you reach the possibility to check the checkboxes below: 
  - :white_check_mark: Add "Open with code" action to Windows Explorer file context menu. 
  - :white_check_mark: Add "Open with code" action to Windows Explorer directory context menu.
Check then both to add both options in context menu.
- See [K6 page](https://grafana.com/docs/k6/latest/set-up/install-k6/) and install it by downloading and executing the latest installer. Perform the installation by letting all the preferenced configurations unchanged. 

# Tests

- Run commands from the tests directory using the unified runner: ```. ..\runner.ps1```

Execution options (exclusive; choose exactly one):
- ```-all``` (run all tests; default profile is smoke)
- ```-i 001``` (run a single test case)
- ```-m-001-010-050``` (run multiple test cases by number)
- ```-c-basic``` / ```-c-full``` / ```-c-negative``` (run by category tag)

Support options (combinable; any order):
- ```-bt``` enable Jira bug ticket creation (loads Jira env automatically)
- ```-cr``` generate a consolidated HTML report after execution
- ```-g``` open the web dashboard (usually http://localhost:5665)
- ```-tp-smoke``` / ```-tp-load``` / ```-tp-stress``` / ```-tp-spike``` / ```-tp-breakpoint``` / ```-tp-soak```

Examples:
- ```. ..\runner.ps1 -all```
- ```. ..\runner.ps1 -i 001 -tp-smoke -g -bt -cr```
- ```. ..\runner.ps1 -m-001-010-050 -tp-load -cr```
- ```. ..\runner.ps1 -c-basic -tp-smoke```

Reports: generated in ```reports/```; filenames follow the pattern TCxxx_*.html.

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

- **Important:** When using ```-bt```, the runner automatically loads Jira credentials from `set_jira_env.ps1` (local) or `JIRA_API_SECRETS` (CI). Make sure those values are configured before running tests with Jira integration.
- **Manual combined report:** if you did not run with ```-cr```, run ```. ..\combine_reports.ps1``` from the tests directory to generate ```general_report_*.html``` in ```reports/```.
- K6 documentation is pleasant to the readers eyes. Have a look calmly.
