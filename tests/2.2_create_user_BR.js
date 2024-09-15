import http from 'k6/http'
import { check, sleep } from 'k6'
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js"
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js'

export function handleSummary(data) {
    return {
      // "reports/report.html": htmlReport(data),
        "report.html": htmlReport(data)
    };
}

export const options = {
    vus: 1,
    duration: '1s'
}

export default function (){

    const credentials = {
        name: randomString(5, 'abcdefgh'),
        email: randomString(5, 'abcdefgh') + '@@k6.com',        
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
    check(res.json(), { 'success was false': (r) => r.success === false,
        'status was 400': (r) => r.status === 400,
        'Message was "A valid email address is required"': (r) => r.message === "A valid email address is required"
    });
    sleep(1);

}