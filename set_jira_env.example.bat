@echo off
REM set_jira_env.example.bat
REM Copy this file to set_jira_env.bat, fill in your Jira credentials,
REM and keep set_jira_env.bat private (it's ignored by git).

REM Jira Cloud / Server
set "JIRA_BASE_URL=https://your-domain.atlassian.net"
set "JIRA_EMAIL=you@example.com"
set "JIRA_API_TOKEN=your_api_token_here"
set "JIRA_PROJECT_KEY=DEV"

echo [set_jira_env] Jira environment variables set for this session.