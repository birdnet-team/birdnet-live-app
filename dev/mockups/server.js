#!/usr/bin/env node
/* =============================================================================
   Local preview server for BirdNET Live store mockups
   ============================================================================= */

const fs = require('fs');
const http = require('http');
const path = require('path');
const { spawn } = require('child_process');

const root = __dirname;
const port = Number(process.env.PORT || 4177);
const host = '127.0.0.1';

const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8',
  '.png': 'image/png',
  '.txt': 'text/plain; charset=utf-8',
};

const server = http.createServer((request, response) => {
  const url = new URL(request.url, `http://${host}:${port}`);

  if (url.pathname === '/render') {
    renderMockups(url.searchParams, response);
    return;
  }

  const pathname = url.pathname === '/' ? '/preview.html' : url.pathname;
  const filePath = path.resolve(root, `.${decodeURIComponent(pathname)}`);
  if (!filePath.startsWith(root)) {
    response.writeHead(403);
    response.end('Forbidden');
    return;
  }

  fs.readFile(filePath, (error, data) => {
    if (error) {
      response.writeHead(404);
      response.end('Not found');
      return;
    }
    response.writeHead(200, {
      'Content-Type': contentTypes[path.extname(filePath)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    response.end(data);
  });
});

server.listen(port, host, () => {
  console.log(`Mockup preview server running at http://${host}:${port}/preview.html`);
  console.log('Use Ctrl+C to stop.');
});

function renderMockups(searchParams, response) {
  const args = ['render-mockups.js'];
  if (searchParams.get('all') === '1') {
    args.push('--all-languages');
  } else {
    args.push('--lang', searchParams.get('lang') || 'en');
  }
  if (searchParams.get('devices') === '1') {
    args.push('--device-screenshots');
  }

  const child = spawn(process.execPath, args, {
    cwd: root,
    shell: false,
  });

  let stdout = '';
  let stderr = '';
  child.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
  child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
  child.on('close', (code) => {
    const success = code === 0;
    response.writeHead(success ? 200 : 500, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    response.end(JSON.stringify({ success, code, stdout, stderr }, null, 2));
  });
}
