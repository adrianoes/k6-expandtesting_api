import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js'
import { randomItem } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'

export function handleSummary(data) {
        jiraSummary(data);
        return {
            // "reports/report.html": htmlReport(data),
            "../reports/TC180_get_all_notes.html": htmlReport(data)
        };
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
    // console.log(user_id)    

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
    // console.log(user_token)

    const credentialsCN = {
        title: randomString(5) + randomString(4),
        description: randomString(5) + randomString(4) + randomString(5) + randomString(4),
        category: randomItem(['Home', 'Work', 'Personal'])
    }
    res = http.post(
        'https://practice.expandtesting.com/notes/api/notes',
        JSON.stringify(credentialsCN),
        {
            headers: {
                'X-Auth-Token': user_token,
                'Content-Type': 'application/json'             
            }
        }
    );
    const note_id = res.json().data.id
    const note_created_at = res.json().data.created_at
    const note_updated_at = res.json().data.updated_at

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
    const note_2_id = res.json().data.id
    const note_2_created_at = res.json().data.created_at
    const note_2_updated_at = res.json().data.updated_at

    res = http.get(
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
        'Note 1 ID is right': (r) => r.data[1].id === note_id,
        'Note 1 title is right': (r) => r.data[1].title === credentialsCN.title,
        'Note 1 description is right': (r) => r.data[1].description === credentialsCN.description,
        'Note 1 category is right': (r) => r.data[1].category === credentialsCN.category,
        'Note 1 completed is right': (r) => r.data[1].completed === false,
        'Note 1 created at is right': (r) => r.data[1].created_at === note_created_at,
        'Note 1 updated at is right': (r) => r.data[1].updated_at === note_updated_at,
        'User ID in Note 1 is right': (r) => r.data[1].user_id === user_id,
        'Note 2 ID is right': (r) => r.data[0].id === note_2_id,
        'Note 2 title is right': (r) => r.data[0].title === credentialsCAN.title,
        'Note 2 description is right': (r) => r.data[0].description === credentialsCAN.description,
        'Note 2 category is right': (r) => r.data[0].category === credentialsCAN.category,
        'Note 2 completed is right': (r) => r.data[0].completed === false,
        'Note 2 created at is right': (r) => r.data[0].created_at === note_2_created_at,
        'Note 2 updated at is right': (r) => r.data[0].updated_at === note_2_updated_at,
        'User ID in Note 2 is right': (r) => r.data[0].user_id === user_id
    });
    sleep(1);

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
