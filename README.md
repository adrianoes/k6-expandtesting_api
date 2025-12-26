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

# Tests:

- Using CMD, navigate to C:\k6-expandtesting_api\tests and execute ```k6 run TC001_health.js``` to run health test and have the report generated in reports folder.
- Using CMD, navigate to C:\k6-expandtesting_api\tests and execute ```..\run_all_tests.bat``` to run all tests at once. Check reports folder after test execution. Using CMD, navigate to C:\k6-expandtesting_api\tests and execute ```..\combined_report.bat``` to generate a single consolidated HTML report.
- All tests are tagged. Tags are full, basic and negative. Using CMD, navigate to C:\k6-expandtesting_api\tests and execute ```for %f in (*.js) do @findstr /I "basic" "%f" >nul && k6 run "%f"``` command to run all the tests tagged as basic.
- Using CMD, navigate to C:\k6-expandtesting_api\tests and execute ```..\run_tc.bat TC001``` or ```..\run_tc.bat 001``` to run TC001_health.js test and have the report generated in reports folder. 
- Using CMD, navigate to C:\k6-expandtesting_api\tests and execute ```..\run_tc.bat 001 020 140``` to run TC001_health.js, TC020_create_user_BR.js, TC140_create_note.js tests and have the reports generated in reports folder. 

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

- UI and API tests to send password reset link to user's email and API tests to verify a password reset token and reset a user's password must be tested manually as they rely on e-mail verification. 
- K6 documentation is pleasant to the readers eyes. Have a look calmly.
- Use support .bat files for a better experience. 
