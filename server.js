const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8000;

// Supported MIME types for web files, especially Godot Web exports (.wasm, .pck)
const MIME_TYPES = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.wasm': 'application/wasm',
    '.pck': 'application/octet-stream',
    '.mp3': 'audio/mpeg',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
};

const server = http.createServer((req, res) => {
    // Decode URI to handle folders/files with spaces in their names
    let filePath = decodeURIComponent(req.url);
    if (filePath === '/') {
        filePath = '/index.html';
    }

    // Resolve path and ensure directory-traversal protection
    const absolutePath = path.resolve(path.join(__dirname, filePath));
    if (!absolutePath.startsWith(__dirname)) {
        res.statusCode = 403;
        res.setHeader('Content-Type', 'text/plain');
        res.end('Access Denied');
        return;
    }

    fs.stat(absolutePath, (err, stats) => {
        if (err || !stats.isFile()) {
            res.statusCode = 404;
            res.setHeader('Content-Type', 'text/plain');
            res.end('404 Not Found');
            return;
        }

        const ext = path.extname(absolutePath).toLowerCase();
        const contentType = MIME_TYPES[ext] || 'application/octet-stream';

        res.statusCode = 200;
        res.setHeader('Content-Type', contentType);
        
        // Critical headers for modern browser security policies (COOP and COEP)
        // These are required by Godot web exports to load SharedArrayBuffer and WASM properly
        res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
        res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
        res.setHeader('Access-Control-Allow-Origin', '*');

        const stream = fs.createReadStream(absolutePath);
        stream.on('error', (streamErr) => {
            res.statusCode = 500;
            res.setHeader('Content-Type', 'text/plain');
            res.end('Internal Server Error');
        });
        stream.pipe(res);
    });
});

server.listen(PORT, () => {
    console.log(`\n==================================================`);
    console.log(`🚀 Game Hub Local Server is up and running!`);
    console.log(`👉 Open your browser at: http://localhost:${PORT}`);
    console.log(`==================================================\n`);
    console.log(`Press Ctrl+C in this command prompt to stop the server.`);
});
