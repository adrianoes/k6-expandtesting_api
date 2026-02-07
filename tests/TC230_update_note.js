import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { getReportPath } from '../support/report-utils.js'
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js'
import { randomItem } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { createUserAndLogin, createNote, deleteAccount } from '../support/custom_commands.js'
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'
import { getTestOptions } from '../support/test-options.js'

export function handleSummary(data) {
        jiraSummary(data);
        return {
              // "reports/report.html": htmlReport(data),
              [getReportPath('TC230_update_note')]: htmlReport(data)
        };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { basic: 'true' }






export default function (){

    const { credentials, user_id, token: user_token } = createUserAndLogin()
    const { note, note_id, created_at: note_created_at } = createNote(user_token)

    const credentialsUN = {
        title: randomString(5) + randomString(4),
        description: randomString(5) + randomString(4) + randomString(5) + randomString(4),
        category: randomItem(['Home', 'Work', 'Personal']),
        completed: true
    }
    let res = http.put(
        'https://practice.expandtesting.com/notes/api/notes/' + note_id,
        JSON.stringify(credentialsUN),
        {
            headers: {
                'X-Auth-Token': user_token,
                'Content-Type': 'application/json'             
            }
        }
    );  
    console.log(res)
    check(res.json(), { 'success was true': (r) => r.success === true,
        'status was 200': (r) => r.status === 200,
        'Message was "Note successfully Updated"': (r) => r.message === "Note successfully Updated",
        'Note ID is right': (r) => r.data.id === note_id,
        'Note title is right': (r) => r.data.title === credentialsUN.title,
        'Note description is right': (r) => r.data.description === credentialsUN.description,
        'Note category is right': (r) => r.data.category === credentialsUN.category,
        'Note completed is right': (r) => r.data.completed === true,
        'Note created at is right': (r) => r.data.created_at === note_created_at,
        'User ID in Note 1 is right': (r) => r.data.user_id === user_id
    });
    sleep(1);

    deleteAccount(user_token)

}


