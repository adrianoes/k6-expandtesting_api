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
            "../reports/TC340_login_user_after_logout.html": htmlReport(data)
        };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { basic: 'true' }






export default function (){

    const { credentials } = createUser()
    const user_token = loginUser(credentials.email, credentials.password)

    let res = http.del(
        'https://practice.expandtesting.com/notes/api/users/logout',
        null,
        {
            headers: {
                'X-Auth-Token': user_token,
                'Content-Type': 'application/json'                
            }
        }
    ); 

    res = http.post(
        'https://practice.expandtesting.com/notes/api/users/login',
        JSON.stringify({ email: credentials.email, password: credentials.password }),
        {
            headers: {
                'Content-Type': 'application/json'
            }
        }
    );  
    sleep(1);
    check(res.json(), { 'success was true': (r) => r.success === true,
        'status was 200': (r) => r.status === 200,
        'Message was "Login successful"': (r) => r.message === "Login successful"
    });
    sleep(1);
    const user_token2 = res.json().data.token

    deleteAccount(user_token2)

}
