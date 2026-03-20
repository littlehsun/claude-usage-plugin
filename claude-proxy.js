const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.argv[2]) || 19999;
const OUTPUT_FILE = path.join(__dirname, 'claude_rate_limit.json');

http.createServer((clientReq, clientRes) => {
    const options = {
        hostname: 'api.anthropic.com',
        port: 443,
        path: clientReq.url,
        method: clientReq.method,
        headers: { ...clientReq.headers, host: 'api.anthropic.com' }
    };

    const proxyReq = https.request(options, (proxyRes) => {
        const rateLimits = {
            utilization_5h: proxyRes.headers['anthropic-ratelimit-unified-5h-utilization'],
            reset_5h: proxyRes.headers['anthropic-ratelimit-unified-5h-reset'],
            utilization_7d: proxyRes.headers['anthropic-ratelimit-unified-7d-utilization'],
            reset_7d: proxyRes.headers['anthropic-ratelimit-unified-7d-reset']
        };

        if (rateLimits.utilization_5h) {
            fs.writeFileSync(OUTPUT_FILE, JSON.stringify(rateLimits, null, 2));
        }

        clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(clientRes);
    });

    clientReq.pipe(proxyReq);

    clientReq.on('error', () => proxyReq.destroy());

    proxyReq.on('error', () => {
        if (!clientRes.headersSent) {
            clientRes.writeHead(500);
        }
        clientRes.end();
    });
}).listen(PORT, () => {
    // ready
}).on('error', (e) => {
    if (e.code === 'EADDRINUSE') {
        console.error(`[錯誤] Port ${PORT} 已被占用，請先關閉占用的程序。`);
    } else {
        console.error(`[錯誤] 伺服器啟動失敗：${e.message}`);
    }
    process.exit(1);
});
