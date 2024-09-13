import http from 'k6/http';
import { check, sleep } from 'k6';
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";

export function handleSummary(data) {
    return {
      // "reports/report.html": htmlReport(data),
      // Still have to make it work for git hub actions with report outside tests folder. For now lets use below option
      "report.html": htmlReport(data),
    };
}

export const options = {
  stages: [
    { duration: '10s', target: 20 },
    { duration: '10s', target: 10 },
    { duration: '5s', target: 0 },
  ],
};

export default function () {
  const res = http.get('https://practice.expandtesting.com/notes/api/health-check');
  // console.log(res.json());
  check(res.json(), { 'success was true': (r) => r.success === true,
               'status was 200': (r) => r.status === 200,
               'Message was "Notes API is Running"': (r) => r.message === "Notes API is Running"
  });
  sleep(1);
}


// I think I'll be required to use node.js to manippulate files in the directory
// https://nodejs.org/api/fs.html
// fix other assertions