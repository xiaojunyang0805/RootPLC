// Smoke test of `rootplc lsp` through the extension's own client:
//   node editors/vscode/test/lsp-smoke.js [path/to/rootplc]
// Opens a document with an error, expects the diagnostic, fixes it, expects
// the diagnostics to clear, asks for the outline and a definition, shuts down.
'use strict';

const { spawn } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');
const { Client } = require('../client');

const exe = process.argv[2] || 'rootplc';
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rootplc-lsp-'));
const file = path.join(dir, 'main.st');
const bad = 'PROGRAM P\nVAR s : SINT; i : INT; END_VAR\ns := i;\nEND_PROGRAM\n';
const good = 'PROGRAM P\nVAR s : SINT; i : INT; END_VAR\ns := INT_TO_SINT(i);\nEND_PROGRAM\n';
fs.writeFileSync(file, bad);
const uri = 'file://' + (file.startsWith('/') ? '' : '/') + file.replace(/\\/g, '/');

function fail(msg) {
  console.error('lsp-smoke: FAIL: ' + msg);
  process.exit(1);
}

async function main() {
  const proc = spawn(exe, ['lsp']);
  proc.on('error', (e) => fail(`cannot start ${exe}: ${e.message}`));
  const client = new Client(proc);
  const published = [];
  client.onNotification = (m) => {
    if (m.method === 'textDocument/publishDiagnostics') published.push(m.params);
  };
  const waitFor = (pred) => new Promise((resolve, reject) => {
    const t0 = Date.now();
    const tick = () => {
      const hit = published.find(pred);
      if (hit) return resolve(hit);
      if (Date.now() - t0 > 10000) return reject(new Error('timeout'));
      setTimeout(tick, 20);
    };
    tick();
  });

  const init = await client.request('initialize', {
    processId: process.pid,
    rootUri: 'file://' + (dir.startsWith('/') ? '' : '/') + dir.replace(/\\/g, '/'),
    capabilities: {},
  });
  if (!init.capabilities.hoverProvider) fail('no hover capability');
  client.notify('initialized', {});
  client.notify('textDocument/didOpen', { textDocument: { uri, languageId: 'iec-st', version: 1, text: bad } });
  const first = await waitFor((p) => p.diagnostics.length > 0).catch(() => fail('no diagnostics'));
  const d = first.diagnostics[0];
  if (d.code !== 'RP0103' || d.range.start.line !== 2) fail('unexpected diagnostic ' + JSON.stringify(d));

  const hover = await client.request('textDocument/hover', { textDocument: { uri }, position: d.range.start });
  if (!hover || !hover.contents.value.includes('RP0103')) fail('hover without the explanation');

  published.length = 0;
  client.notify('textDocument/didChange', { textDocument: { uri, version: 2 }, contentChanges: [{ text: good }] });
  await waitFor((p) => p.diagnostics.length === 0).catch(() => fail('diagnostics not cleared'));

  const syms = await client.request('textDocument/documentSymbol', { textDocument: { uri } });
  if (!syms.length || syms[0].name !== 'P' || syms[0].children.length !== 2) fail('outline ' + JSON.stringify(syms));

  const def = await client.request('textDocument/definition', { textDocument: { uri }, position: { line: 2, character: 0 } });
  if (!def || def.range.start.line !== 1) fail('definition ' + JSON.stringify(def));

  await client.request('shutdown', null);
  client.notify('exit', null);
  proc.on('exit', (code) => {
    fs.rmSync(dir, { recursive: true, force: true });
    if (code !== 0) fail('exit code ' + code);
    console.log('lsp-smoke: ok (diagnostics, hover, clear, outline, definition, shutdown)');
  });
}

main().catch((e) => fail(e.message || String(e)));
