import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { createUserAndLogin, createNote, deleteAccount } from '../support/custom_commands.js'
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'
import { getTestOptions } from '../support/test-options.js'

export function handleSummary(data) {
        jiraSummary(data);
        return {
            // "reports/report.html": htmlReport(data),
            "../reports/TC270_update_completeness_note_BR.html": htmlReport(data)
        };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { negative: 'true' }






export default function (){

    const { token: user_token } = createUserAndLogin()
    const note = createNote(user_token)

    const credentialsUCN = {
        completed: "a"
    }
    let res = http.patch(
        'https://practice.expandtesting.com/notes/api/notes/' + note.note_id,
        JSON.stringify(credentialsUCN),
        {
            headers: {
                'X-Auth-Token': user_token,
                'Content-Type': 'application/json'             
            }
        }
    );  
    // console.log(res)
    check(res.json(), { 'success was false': (r) => r.success === false,
        'status was 400': (r) => r.status === 400,
        'Message was "Note completed status must be boolean"': (r) => r.message === "Note completed status must be boolean"
    });
    sleep(1);

    deleteAccount(user_token)

}
