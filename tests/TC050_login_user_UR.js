import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { createUser, loginUser, deleteAccount } from '../support/custom_commands.js'
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'
import { getTestOptions } from '../support/test-options.js'

export function handleSummary(data) {
    jiraSummary(data);
    return {
        // "reports/report.html": htmlReport(data),
        "../reports/TC050_login_user_UR.html": htmlReport(data)
    };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { negative: 'true' }


export default function (){

    const { credentials } = createUser()

    const credentialsLUUR = {
        email: credentials.email,        
        password: '@'+credentials.password
    }
    let res = http.post(
        'https://practice.expandtesting.com/notes/api/users/login',
        JSON.stringify(credentialsLUUR),
        {
            headers: {
                'Content-Type': 'application/json'
            }
        }
    );  
    sleep(1);
    check(res.json(), { 'success was false': (r) => r.success === false,
        'status was 401': (r) => r.status === 401,
        'Message was "Incorrect email address or password"': (r) => r.message === "Incorrect email address or password"
    });
    sleep(1);

    const user_token = loginUser(credentials.email, credentials.password)
    deleteAccount(user_token)

}
