import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { getReportPath } from '../support/report-utils.js'
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js'
import { randomItem } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { createUserAndLogin, deleteAccount } from '../support/custom_commands.js'
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'
import { getTestOptions } from '../support/test-options.js'

export function handleSummary(data) {
        jiraSummary(data);
        return {
            // "reports/report.html": htmlReport(data),
            [getReportPath('TC170_create_another_note')]: htmlReport(data)
        };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { basic: 'true' }






export default function (){

    const { user_id, token: user_token } = createUserAndLogin()

    const credentialsCN = {
        title: randomString(5) + randomString(4),
        description: randomString(5) + randomString(4) + randomString(5) + randomString(4),
        category: randomItem(['Home', 'Work', 'Personal'])
    }
    let res = http.post(
        'https://practice.expandtesting.com/notes/api/notes',
        JSON.stringify(credentialsCN),
        {
            headers: {
                'X-Auth-Token': user_token,
                'Content-Type': 'application/json'             
            }
        }
    );

    const credentialsCAN = {
        title: randomString(5) + randomString(4),
        description: randomString(5) + randomString(4) + randomString(5) + randomString(4),
        category: randomItem(['Home', 'Work', 'Personal'])
    }
    res = http.post(
        'https://practice.expandtesting.com/notes/api/notes',
        JSON.stringify(credentialsCAN),
        {
            headers: {
                'X-Auth-Token': user_token,
                'Content-Type': 'application/json'             
            }
        }
    );  
    check(res.json(), { 'success was true': (r) => r.success === true,
        'status was 200': (r) => r.status === 200,
        'Message was "Note successfully created"': (r) => r.message === "Note successfully created",
        'Title is right': (r) => r.data.title === credentialsCAN.title,
        'Description is right': (r) => r.data.description === credentialsCAN.description,
        'Category is right': (r) => r.data.category === credentialsCAN.category,
        'Completed is right': (r) => r.data.completed === false,
        'User ID is right': (r) => r.data.user_id === user_id
    });
    sleep(1);

    deleteAccount(user_token)

}


