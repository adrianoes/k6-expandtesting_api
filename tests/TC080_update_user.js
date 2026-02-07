import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js'
import { createUserAndLogin, deleteAccount } from '../support/custom_commands.js'
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'
import { getTestOptions } from '../support/test-options.js'

export function handleSummary(data) {
        jiraSummary(data);
        return {
            // "reports/report.html": htmlReport(data),
            "../reports/TC080_update_user.html": htmlReport(data)
        };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { basic: 'true' }


export default function (){

    const { credentials, user_id, token: user_token } = createUserAndLogin()

    const credentialsUU = {
        name: randomString(5, 'abcdefgh'),
        phone: randomString(12, '0123456789'),        
        company: randomString(10),
    }
    let res = http.patch(
        'https://practice.expandtesting.com/notes/api/users/profile',
        JSON.stringify(credentialsUU),
        {
            headers: {
                'X-Auth-Token': user_token,
                'Content-Type': 'application/json'             
            }
        }
    );  
    check(res.json(), { 'success was true': (r) => r.success === true,
        'status was 200': (r) => r.status === 200,
        'Message was "Profile updated successful"': (r) => r.message === "Profile updated successful",
        'E-mail is right': (r) => r.data.email === credentials.email,
        'Name is right': (r) => r.data.name === credentialsUU.name,
        'User ID is right': (r) => r.data.id === user_id,
        'Phone is right': (r) => r.data.phone === credentialsUU.phone,
        'Company is right': (r) => r.data.company === credentialsUU.company
    });
    sleep(1);

    deleteAccount(user_token)

}
