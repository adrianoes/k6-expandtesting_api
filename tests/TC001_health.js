import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'

export function handleSummary(data) {
    // Gera o report HTML normalmente
    const reports = {
        '../reports/TC001_health.html': htmlReport(data),
    };
    // Chama o handler do Jira (cria bug se houver falha)
    jiraSummary(data);
    // Retorna os reports normalmente
    return reports;
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
    let res = http.get('https://practice.expandtesting.com/notes/api/health-check')
    check(res.json(), { 'success was true': (r) => r.success === true,
                'status was 200': (r) => r.status === 200,
                'Message was "Notes API is Running"': (r) => r.message === "Notes API is Running"
    })
    sleep(1)    
    // console.log(res)
}
