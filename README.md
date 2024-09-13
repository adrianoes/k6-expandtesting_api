# k6-expandtesting_UI_and_API

API testing in [expandtesting](https://practice.expandtesting.com/notes/api/api-docs/). This project contains basic examples on how to use K6 to test performance API tests. 

# Pre-requirements:

| Requirement                     | Version        | Note                                                            |
| :------------------------------ |:---------------| :-------------------------------------------------------------- |
| Visual Studio Code              | 1.89.1         | -                                                               |
| K6                              | 0.53.0         | -                                                               | 

# Installation:

- See [Visual Studio Code page](https://code.visualstudio.com/) and install the latest VSC stable version. Keep all the prefereced options as they are until you reach the possibility to check the checkboxes below: 
  - :white_check_mark: Add "Open with code" action to Windows Explorer file context menu. 
  - :white_check_mark: Add "Open with code" action to Windows Explorer directory context menu.
Check then both to add both options in context menu.
- See [K6 page](https://grafana.com/docs/k6/latest/set-up/install-k6/) and install it by downloading and executing the latest installer. Perform the installation by letting all the preferenced configurations unchanged. 

# Tests:

- Execute ```k6 run tests/health.js``` to run all tests in health test suite.

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

# Tips:

- UI and API tests to send password reset link to user's email and API tests to verify a password reset token and reset a user's password must be tested manually as they rely on e-mail verification. 
- K6 documentation is pleasant to the readers eyes. Have a look calmly.
