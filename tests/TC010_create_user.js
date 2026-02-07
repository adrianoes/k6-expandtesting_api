import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js'
import { loginUser, deleteAccount } from '../support/custom_commands.js'
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'
import { getTestOptions } from '../support/test-options.js'

export function handleSummary(data) {
    jiraSummary(data);
    return {
        // "reports/report.html": htmlReport(data),
        "../reports/TC010_create_user.html": htmlReport(data)
    };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { basic: 'true' }


export default function (){

    const credentials = {
        name: randomString(5, 'abcdefgh'),
        email: randomString(10, 'abcdefghijklmnopqrstuvwxyz0123456789') + '@k6.com',        
        password: randomString(10),
    }
    let res = http.post(
        'https://practice.expandtesting.com/notes/api/users/register',
        JSON.stringify(credentials),
        {
            headers: {
                'Content-Type': 'application/json'
            }
        }
    ); 
    sleep(1);
    const user_id = res.json().data.id
    check(res.json(), { 'success was true': (r) => r.success === true,
        'status was 201': (r) => r.status === 201,
        'Message was "User account created successfully': (r) => r.message === "User account created successfully",
        'E-mail is right': (r) => r.data.email === credentials.email,
        'Name is right': (r) => r.data.name === credentials.name
    });
    sleep(1);

    const user_token = loginUser(credentials.email, credentials.password)
    deleteAccount(user_token)

}
