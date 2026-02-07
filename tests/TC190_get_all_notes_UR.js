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
            [getReportPath('TC190_get_all_notes_UR')]: htmlReport(data)
        };
}

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { negative: 'true' }






export default function (){

    const { token: user_token } = createUserAndLogin()
    createNote(user_token)
    createNote(user_token)

    let res = http.get(
        'https://practice.expandtesting.com/notes/api/notes',
        {
            headers: {
                'X-Auth-Token': "@"+user_token              
            }
        }
    );  
    // console.log(res)
    check(res.json(), { 'success was false': (r) => r.success === false,
        'status was 401': (r) => r.status === 401,
        'Message was "Access token is not valid or has expired, you will need to login"': (r) => r.message === "Access token is not valid or has expired, you will need to login"
    });
    sleep(1);

    deleteAccount(user_token)

}


