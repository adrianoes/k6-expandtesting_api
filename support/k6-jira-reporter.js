// k6-jira-reporter.js
// Cria UM bug no Jira automaticamente se qualquer check falhar durante a execução de um teste k6
// Agrega todos os checks que falharam e indica quantas vezes cada um falhou
// Use como handleSummary em seus scripts k6

import http from 'k6/http';
import encoding from 'k6/encoding';
import { htmlReport } from 'https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js';

function requiredEnv(name) {
    const v = __ENV[name];
    if (!v) throw new Error(`[k6-jira-reporter] Missing required env var: ${name}`);
    return v;
}

function getJiraEnv() {
    return {
        baseUrl: requiredEnv('JIRA_BASE_URL').replace(/\/+$/, ''),
        email: requiredEnv('JIRA_EMAIL'),
        apiToken: requiredEnv('JIRA_API_TOKEN'),
        projectKey: requiredEnv('JIRA_PROJECT_KEY'),
        issueType: __ENV.JIRA_ISSUE_TYPE || 'Bug',
    };
}

function basicAuthHeader(email, token) {
    const raw = `${email}:${token}`;
    return 'Basic ' + encoding.b64encode(raw);
}

function formatFailedChecksDetails(checks) {
    const failedChecks = (Array.isArray(checks) ? checks : Object.values(checks || {}))
        .filter((checkItem) => checkItem.fails && checkItem.fails > 0)
        .map((checkItem) => {
            const name = checkItem.name || 'unknown';
            const passes = checkItem.passes || 0;
            const failures = checkItem.fails || 0;
            const totalCount = passes + failures;
            const passPercentage = totalCount > 0 ? ((passes / totalCount) * 100).toFixed(2) : '0.00';
            return `${name} | Passes: ${passes} | Failures: ${failures} | % Pass: ${passPercentage}%`;
        })
        .join('\n');
    return failedChecks || '(no failed checks)';
}

function toPlainTextDescription({ testName, checksFailed, checksTotal, failedChecksDetails }) {
    return [
        'Automated bug created by k6.',
        '',
        '== Test Information ==',
        `Test: ${testName}`,
        `Total Failed Checks: ${checksFailed} / ${checksTotal}`,
        '',
        '== Failed Checks Details ==',
        'CHECK NAME | PASSES | FAILURES | % PASS',
        '-------------------------------------------',
        failedChecksDetails,
    ].join('\n');
}

function createJiraIssue(env, summary, description) {
    const url = `${env.baseUrl}/rest/api/2/issue`;
    console.log(`[k6-jira-reporter] Creating issue at ${url}`);
    console.log(`[k6-jira-reporter] Summary: ${summary}`);
    const payload = JSON.stringify({
        fields: {
            project: { key: env.projectKey },
            issuetype: { name: env.issueType },
            summary,
            description,
            labels: [
                'api-test',
                'api-performance-test',
                'automated-test',
                'k6',
            ],
        },
    });
    console.log('[k6-jira-reporter] Payload prepared');
    const res = http.post(url, payload, {
        headers: {
            Authorization: basicAuthHeader(env.email, env.apiToken),
            Accept: 'application/json',
            'Content-Type': 'application/json',
        },
        timeout: '30s',
    });
    if (res.status !== 201) {
        console.error(`[k6-jira-reporter] Failed to create Jira issue: status=${res.status}`);
        console.error(`[k6-jira-reporter] Response body: ${res.body}`);
        return null;
    }
    const json = res.json();
    if (!json.key) {
        console.error('[k6-jira-reporter] Jira create issue returned no key');
        return null;
    }
    console.log(`[k6-jira-reporter] Created Jira issue ${json.key}`);
    return json.key;
}

function attachReportToIssue(env, issueKey, fileName, htmlContent) {
    try {
        const url = `${env.baseUrl}/rest/api/2/issue/${issueKey}/attachments`;
        const boundary = '----K6FormBoundary' + Date.now();

        let body = '';
        body += `--${boundary}\r\n`;
        body += `Content-Disposition: form-data; name="file"; filename="${fileName}"\r\n`;
        body += `Content-Type: text/html\r\n\r\n`;
        body += htmlContent;
        body += `\r\n--${boundary}--\r\n`;

        const res = http.post(url, body, {
            headers: {
                Authorization: basicAuthHeader(env.email, env.apiToken),
                'Content-Type': `multipart/form-data; boundary=${boundary}`,
                'X-Atlassian-Token': 'no-check',
            },
            timeout: '30s',
        });
        if (res.status === 200) {
            console.log(`[k6-jira-reporter] HTML report attached to ${issueKey}`);
        } else {
            console.warn(`[k6-jira-reporter] Failed to attach report: status=${res.status}`);
        }
    } catch (e) {
        console.warn(`[k6-jira-reporter] Error attaching report: ${String(e)}`);
    }
}

export function handleSummary(data) {
    try {
        // Extrai checks da estrutura correta do k6 summary (é um ARRAY)
        const checks = Array.isArray(data.root_group.checks) ? data.root_group.checks : Object.values(data.root_group.checks || {});
        
        // Conta total de falhas somando os valores de 'fails' de cada check
        let checksFailed = 0;
        let checksTotal = 0;
        
        for (const checkItem of checks) {
            checksFailed += (checkItem.fails || 0);
            checksTotal += (checkItem.passes || 0) + (checkItem.fails || 0);
        }

        console.log(`[k6-jira-reporter] handleSummary: checksFailed=${checksFailed}, checksTotal=${checksTotal}`);
        console.log(`[k6-jira-reporter] Checks found: ${checks.length}`);

        // Loga variáveis obrigatórias para diagnóstico (sem imprimir token)
        const hasEnv = !!(__ENV.JIRA_BASE_URL && __ENV.JIRA_EMAIL && __ENV.JIRA_API_TOKEN && __ENV.JIRA_PROJECT_KEY);
        if (!hasEnv) {
            console.warn('[k6-jira-reporter] Jira env vars missing; skipping issue creation');
        }

        // Se houver checks que falharam, cria uma única issue
        if (checksFailed > 0) {
            // Extrai o nome do arquivo de teste (pode ser customizado conforme necessário)
            const testName = __ENV.K6_TEST_NAME || 'k6 test';

            const failedChecksDetails = formatFailedChecksDetails(checks);
            if (!hasEnv) {
                console.warn('[k6-jira-reporter] Jira env vars missing; skipping issue creation');
                return {};
            }

            const env = getJiraEnv();
            const summary = `k6 failure: ${testName} - ${checksFailed} checks failed`;
            const description = toPlainTextDescription({
                testName,
                checksFailed,
                checksTotal,
                failedChecksDetails,
            });

            // Gera o HTML do report no próprio handleSummary para anexar
            let html = '';
            try {
                html = htmlReport(data) || '';
            } catch (e) {
                console.warn('[k6-jira-reporter] Failed to generate HTML report for attachment');
            }

            const key = createJiraIssue(env, summary, description);
            if (key && html) {
                const fileName = `${testName}.html`;
                attachReportToIssue(env, key, fileName, html);
            }
        } else {
            console.log('[k6-jira-reporter] No failed checks detected; skipping issue creation');
        }
    } catch (e) {
        console.error(`[k6-jira-reporter] Jira integration failed: ${String(e)}`);
        console.error(`[k6-jira-reporter] Error stack: ${e.stack || 'no stack'}`);
    }
    return {};
}
