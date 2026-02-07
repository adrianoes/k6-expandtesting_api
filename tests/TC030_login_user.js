import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { getReportPath } from '../support/report-utils.js'
import { createUser, deleteAccount } from '../support/custom_commands.js'
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'
import { getTestOptions } from '../support/test-options.js'

export function handleSummary(data) {
    jiraSummary(data);
    return {
        // "reports/report.html": htmlReport(data),
        [getReportPath('TC030_login_user')]: htmlReport(data)
    };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { basic: 'true' }


export default function (){

    const { credentials, user_id } = createUser()

    const credentialsLU = {
        email: credentials.email,        
        password: credentials.password
    }
    let res = http.post(
        'https://practice.expandtesting.com/notes/api/users/login',
        JSON.stringify(credentialsLU),
        {
            headers: {
                'Content-Type': 'application/json'
            }
        }
    );  
    sleep(1);
    const user_token = res.json().data.token
    check(res.json(), { 'success was true': (r) => r.success === true,
        'status was 200': (r) => r.status === 200,
        'Message was "Login successful"': (r) => r.message === "Login successful",
        'E-mail is right': (r) => r.data.email === credentials.email,
        'Name is right': (r) => r.data.name === credentials.name,
        'User ID is right': (r) => r.data.id === user_id
    });
    sleep(1);

    deleteAccount(user_token)

}


