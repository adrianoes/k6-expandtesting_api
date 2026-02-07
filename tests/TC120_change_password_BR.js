import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { getReportPath } from '../support/report-utils.js'
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js'
import { createUser, loginUser, deleteAccount } from '../support/custom_commands.js'
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'
import { getTestOptions } from '../support/test-options.js'

export function handleSummary(data) {
        jiraSummary(data);
        return {
            // "reports/report.html": htmlReport(data),
            [getReportPath('TC120_change_password_BR')]: htmlReport(data)
        };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { negative: 'true' }






export default function (){

    const { credentials } = createUser()
    const user_token = loginUser(credentials.email, credentials.password)
    // console.log(user_token)

    const credentialsCP = {
        currentPassword: credentials.password,
        newPassword: "123"
    }
    let res = http.post(
        'https://practice.expandtesting.com/notes/api/users/change-password',
        JSON.stringify(credentialsCP),
        {
            headers: {
                'X-Auth-Token': user_token,
                'Content-Type': 'application/json'             
            }
        }
    );  
    check(res.json(), { 'success was false': (r) => r.success === false,
        'status was 400': (r) => r.status === 400,
        'Message was "New password must be between 6 and 30 characters"': (r) => r.message === "New password must be between 6 and 30 characters"
    });
    sleep(1);

    deleteAccount(user_token)

}


