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
        email: randomString(5, 'abcdefgh') + '@k6.com',        
        password: randomString(10),
    }
    console.log(credentials);
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
    console.log(user_id)
    check(res.json(), { 'success was true': (r) => r.success === true,
        'status was 201': (r) => r.status === 201,
        'Message was "User account created successfully"': (r) => r.message === "User account created successfully",
        'E-mail is right': (r) => r.data.email === credentials.email,
        'Name is right': (r) => r.data.name === credentials.name
    });
    sleep(1);

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
    console.log(user_token)

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