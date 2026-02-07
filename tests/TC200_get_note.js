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
            "../reports/TC200_get_note.html": htmlReport(data)
        };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { basic: 'true' }






export default function (){

    const { user_id, token: user_token } = createUserAndLogin()
    const note = createNote(user_token)

    let res = http.get(
        'https://practice.expandtesting.com/notes/api/notes/' + note.note_id,
        {
            headers: {
                'X-Auth-Token': user_token              
            }
        }
    );  
    // console.log(res)
    check(res.json(), { 'success was true': (r) => r.success === true,
        'status was 200': (r) => r.status === 200,
        'Message was "Note successfully retrieved"': (r) => r.message === "Note successfully retrieved",
        'Note ID is right': (r) => r.data.id === note.note_id,
        'Note title is right': (r) => r.data.title === note.note.title,
        'Note description is right': (r) => r.data.description === note.note.description,
        'Note category is right': (r) => r.data.category === note.note.category,
        'Note completed is right': (r) => r.data.completed === false,
        'Note created at is right': (r) => r.data.created_at === note.created_at,
        'Note updated at is right': (r) => r.data.updated_at === note.updated_at,
        'User ID in Note 1 is right': (r) => r.data.user_id === user_id
    });
    sleep(1);

    deleteAccount(user_token)

}
