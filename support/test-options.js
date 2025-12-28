// test-options.js
// Test execution profiles: smoke, load, stress, spike, breakpoint, soak

const testOptions = {
    smoke: {
        vus: 1,
        duration: '30s'
    },
    load: {
        stages: [
            {
                duration: '10s',
                target: 10
            },
            {
                duration: '30s',
                target: 10
            },
            {
                duration: '10s',
                target: 0
            }       
        ]
    },
    stress: {
        stages: [
            {
                duration: '10s',
                target: 1000
            },
            {
                duration: '30s',
                target: 1000
            },
            {
                duration: '10s',
                target: 0
            }       
        ]
    },
    spike: {
        stages: [
            {
                duration: '2m',
                target: 10000
            },
            {
                duration: '1m',
                target: 0
            }    
        ]
    },
    breakpoint: {
        stages: [
            {
                duration: '2h',
                target: 10000
            }  
        ]
    },
    soak: {
        stages: [
            {
                duration: '5m',
                target: 1000
            },
            {
                duration: '24h',
                target: 1000
            },
            {
                duration: '5m',
                target: 0
            }       
        ]
    }
};

export function getTestOptions(testType = 'smoke') {
    const type = (testType || 'smoke').toLowerCase();
    if (!testOptions[type]) {
        console.warn(`Unknown test type: ${type}. Using 'smoke' as default.`);
        return testOptions.smoke;
    }
    return testOptions[type];
}

export default testOptions;
