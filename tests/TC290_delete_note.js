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
              [getReportPath('TC290_delete_note')]: htmlReport(data)
        };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);






export default function (){

    const { token: user_token } = createUserAndLogin()
    const note = createNote(user_token)

    let res = http.del(
        'https://practice.expandtesting.com/notes/api/notes/' + note.note_id,
        null,
        {
            headers: {
                'X-Auth-Token': user_token              
            }
        }
    );  
    // console.log(res)
    check(res.json(), { 'success was true': (r) => r.success === true,
        'status was 200': (r) => r.status === 200,
        'Message was "Note successfully deleted"': (r) => r.message === "Note successfully deleted"
    });
    sleep(1);

    deleteAccount(user_token)

}


