import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js'
import { randomItem } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { createUserAndLogin, createNote, deleteAccount } from '../support/custom_commands.js'
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'

export function handleSummary(data) {
        jiraSummary(data);
        return {
              // "reports/report.html": htmlReport(data),
              "../reports/TC230_update_note.html": htmlReport(data)
        };
    }
}

// for smoke test, reply below script in every test
export const options = {
    vus: 1,
    duration: '30s'
}

export const tags = { full: 'true', basic: 'true' }

// // for load test, reply below script in every test
// export const options = {
//     stages: [
//         {
//             duration: '10s',
//             target: 10
//         },
//         {
//             duration: '30s',
//             target: 10
//         },
//         {
//             duration: '10s',
//             target: 0
//         }       
//     ]
// }

// // for stress test, reply below script in every test
// export const options = {
//     stages: [
//         {
//             duration: '10s',
//             target: 1000
//         },
//         {
//             duration: '30s',
//             target: 1000
//         },
//         {
//             duration: '10s',
//             target: 0
//         }       
//     ]
// }

// // for spike test, reply below script in every test
// export const options = {
//     stages: [
//         {
//             duration: '2m',
//             target: 10000
//         },
//         {
//             duration: '1m',
//             target: 0
//         }    
//     ]
// }

// // for breakpoint test, reply below script in every test
// export const options = {
//     stages: [
//         {
//             duration: '2h',
//             target: 10000
//         }  
//     ]
// }

// // for soak test, reply below script in every test
// export const options = {
//     stages: [
//         {
//             duration: '5m',
//             target: 1000
//         },
//         {
//             duration: '24h',
//             target: 1000
//         },
//         {
//             duration: '5m',
//             target: 0
//         }       
//     ]
// }

export default function (){

    const { credentials, user_id, token: user_token } = createUserAndLogin()
    const { note, note_id, created_at: note_created_at } = createNote(user_token)

    const credentialsUN = {
        title: randomString(5) + randomString(4),
        description: randomString(5) + randomString(4) + randomString(5) + randomString(4),
        category: randomItem(['Home', 'Work', 'Personal']),
        completed: true
    }
    res = http.put(
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
