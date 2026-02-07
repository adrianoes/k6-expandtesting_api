import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { getReportPath } from '../support/report-utils.js'
import { createUserAndLogin, createNote, deleteAccount } from '../support/custom_commands.js'
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'
import { getTestOptions } from '../support/test-options.js'

export function handleSummary(data) {
        jiraSummary(data);
        return {
            // "reports/report.html": htmlReport(data),
            [getReportPath('TC180_get_all_notes')]: htmlReport(data)
        };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { basic: 'true' }






export default function (){

    const { user_id, token: user_token } = createUserAndLogin()
    const note1 = createNote(user_token)
    const note2 = createNote(user_token)

    let res = http.get(
        'https://practice.expandtesting.com/notes/api/notes',
        {
            headers: {
                'X-Auth-Token': user_token              
            }
        }
    );  
    // console.log(res)
    check(res.json(), { 'success was true': (r) => r.success === true,
        'status was 200': (r) => r.status === 200,
        'Message was "Notes successfully retrieved"': (r) => r.message === "Notes successfully retrieved",
        'Note 1 ID is right': (r) => r.data[1].id === note1.note_id,
        'Note 1 title is right': (r) => r.data[1].title === note1.note.title,
        'Note 1 description is right': (r) => r.data[1].description === note1.note.description,
        'Note 1 category is right': (r) => r.data[1].category === note1.note.category,
        'Note 1 completed is right': (r) => r.data[1].completed === false,
        'Note 1 created at is right': (r) => r.data[1].created_at === note1.created_at,
        'Note 1 updated at is right': (r) => r.data[1].updated_at === note1.updated_at,
        'User ID in Note 1 is right': (r) => r.data[1].user_id === user_id,
        'Note 2 ID is right': (r) => r.data[0].id === note2.note_id,
        'Note 2 title is right': (r) => r.data[0].title === note2.note.title,
        'Note 2 description is right': (r) => r.data[0].description === note2.note.description,
        'Note 2 category is right': (r) => r.data[0].category === note2.note.category,
        'Note 2 completed is right': (r) => r.data[0].completed === false,
        'Note 2 created at is right': (r) => r.data[0].created_at === note2.created_at,
        'Note 2 updated at is right': (r) => r.data[0].updated_at === note2.updated_at,
        'User ID in Note 2 is right': (r) => r.data[0].user_id === user_id
    });
    sleep(1);

    deleteAccount(user_token)

}


