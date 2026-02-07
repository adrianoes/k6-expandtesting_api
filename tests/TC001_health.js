import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { handleSummary as jiraSummary } from '../support/k6-jira-reporter.js'
import { getTestOptions } from '../support/test-options.js'

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

// Get test options from environment or default to 'smoke'
const testType = __ENV.K6_TEST_TYPE || 'smoke';
export const options = getTestOptions(testType);

export const tags = { basic: 'true' }

export default function (){
    let res = http.get('https://practice.expandtesting.com/notes/api/health-check')
    check(res.json(), { 'success was true': (r) => r.success === true,
                'status was 200': (r) => r.status === 200,
                'Message was "Notes API is Running"': (r) => r.message === "Notes API is Running"
    })
    sleep(1)    
    // console.log(res)
}
