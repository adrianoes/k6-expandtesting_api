function pad2(value) {
    return String(value).padStart(2, '0');
}

export function getReportPath(defaultName) {
    const now = new Date();
    const timestamp = `${now.getFullYear()}${pad2(now.getMonth() + 1)}${pad2(now.getDate())}_${pad2(now.getHours())}${pad2(now.getMinutes())}${pad2(now.getSeconds())}`;
    const testName = __ENV.K6_TEST_NAME || defaultName || 'report';
    return `../reports/${testName}_${timestamp}.html`;
}
