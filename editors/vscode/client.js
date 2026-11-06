// JSON-RPC over stdio with Content-Length framing (the LSP transport).
// Used by extension.js and by test/lsp-smoke.js; needs only Node.
'use strict';

class Client {
  constructor(proc) {
    this.proc = proc;
    this.buf = Buffer.alloc(0);
    this.nextId = 1;
    this.pending = new Map();
    this.onNotification = () => {};
    proc.stdout.on('data', (d) => this.feed(d));
  }

  feed(data) {
    this.buf = Buffer.concat([this.buf, data]);
    for (;;) {
      const head = this.buf.indexOf('\r\n\r\n');
      if (head < 0) return;
      const m = /Content-Length:\s*(\d+)/i.exec(this.buf.slice(0, head).toString('ascii'));
      const len = m ? Number(m[1]) : 0;
      if (this.buf.length < head + 4 + len) return;
      const body = this.buf.slice(head + 4, head + 4 + len).toString('utf8');
      this.buf = this.buf.slice(head + 4 + len);
      let msg;
      try { msg = JSON.parse(body); } catch (e) { continue; }
      if (msg.id !== undefined && msg.method === undefined) {
        const p = this.pending.get(msg.id);
        if (p) {
          this.pending.delete(msg.id);
          if (msg.error) p.reject(msg.error); else p.resolve(msg.result);
        }
      } else if (msg.method) {
        this.onNotification(msg);
      }
    }
  }

  send(obj) {
    const s = JSON.stringify(obj);
    this.proc.stdin.write(`Content-Length: ${Buffer.byteLength(s, 'utf8')}\r\n\r\n${s}`);
  }

  request(method, params) {
    const id = this.nextId++;
    this.send({ jsonrpc: '2.0', id, method, params });
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
  }

  notify(method, params) {
    this.send({ jsonrpc: '2.0', method, params });
  }
}

module.exports = { Client };
