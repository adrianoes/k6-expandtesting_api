# set_jira_env.example.ps1
# Copy this file to set_jira_env.ps1, fill in your Jira credentials,
# and keep set_jira_env.ps1 private (it's ignored by git).
#
# Usage from tests directory:
#   . ..\set_jira_env.ps1
#   ..\run_tc.bat 001 smoke

$env:JIRA_BASE_URL = "https://your_project_url.atlassian.net"
$env:JIRA_EMAIL = "your_email@xyz.com"
$env:JIRA_API_TOKEN = "xxxxxx_your_api_token_xxxxxxxxxxxxx"
$env:JIRA_PROJECT_KEY = "DEV"
$env:JIRA_ISSUE_TYPE = "Bug"

Write-Host "[set_jira_env] Jira environment variables set for this session."
