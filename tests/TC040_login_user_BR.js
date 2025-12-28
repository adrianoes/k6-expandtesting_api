import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js'
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'
import { getTestOptions } from '../support/test-options.js'

export function handleSummary(data) {
    jiraSummary(data);
    return {
        // "reports/report.html": htmlReport(data),
        "../reports/TC040_login_user_BR.html": htmlReport(data)
    };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { full: 'true', negative: 'true' }


export default function (){

    const credentials = {
        name: randomString(5, 'abcdefgh'),
        email: randomString(5, 'abcdefgh') + '@k6.com',        
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

    const credentialsLUBR = {
        email: '@'+credentials.email,        
        password: credentials.password
    }
    res = http.post(
        'https://practice.expandtesting.com/notes/api/users/login',
        JSON.stringify(credentialsLUBR),
        {
            headers: {
                'Content-Type': 'application/json'
            }
        }
    );  
    sleep(1);
    check(res.json(), { 'success was false': (r) => r.success === false,
        'status was 400': (r) => r.status === 400,
        'Message was "A valid email address is required"': (r) => r.message === "A valid email address is required"
    });
    sleep(1);

    const credentialsLU = {
        email: credentials.email,        
        password: credentials.password
    }
    res = http.post(
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

    res = http.del(
        'https://practice.expandtesting.com/notes/api/users/delete-account',
        null,
        {
            headers: {
                'X-Auth-Token': user_token,
                'Content-Type': 'application/json'                
            }
        }
    ); 

}
