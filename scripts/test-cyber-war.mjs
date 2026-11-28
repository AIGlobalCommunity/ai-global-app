import { readFileSync } from 'node:fs';
import { Script, runInNewContext } from 'node:vm';
import { webcrypto } from 'node:crypto';
import assert from 'node:assert/strict';

const file = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const html = file('web/genesis-cyber-war.html');
const js = ['web/genesis-cyber-op0506.js','web/genesis-cyber-op0304.js','web/genesis-cyber-campaign.js','web/genesis-cyber-workbench.js'];
for (const path of js) new Script(file(path), { filename: path });
for (const [, content] of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) {
  if (content.trim()) new Script(content, { filename: 'web/genesis-cyber-war.html:inline' });
}
assert.match(html, /id="op0506"/);
assert.match(html, /genesis-cyber-op0506\.js/);
assert.match(html, /GenesisEvidence\.start\(/);
assert.match(html, /GenesisEvidence\.getFiles\(/);
assert.match(html, /GenesisEvidence\?\.stop\(/);
assert.match(html, /testerMode=!!d\.tester/);
assert.doesNotMatch(html, /mpiw123@gmail\.com/i);
const root = { hidden: true, dataset: {}, replaceChildren() {}, append() {} };
const globals = { document: { getElementById: id => id==='op0506' ? root : null }, crypto: webcrypto, TextEncoder, TextDecoder };
globals.globalThis=globals;
runInNewContext(file('web/genesis-cyber-op0506.js'),globals);
const api=globals.GenesisEvidence;
assert.ok(api && typeof api.start==='function' && typeof api.getFiles==='function');
for (const m of [5,6]) {
  const artifact=api.build(m,'SYNTHETIC_TEST_SAMPLE');
  assert.equal(artifact.m,m);
  assert.equal(artifact.rows.length,16);
  assert.equal(artifact.items.length,10);
  assert.ok(artifact.rows.filter(row=>row.correlation===artifact.corr).length>=3);
  assert.ok(!artifact.rows.some(row=>row.status==='CONFIRMED'));
  assert.ok(artifact.items.some(row=>row.ticket===artifact.ref));
}
console.log('PASS: inline JS syntax, R15 wiring, tester UI, synthetic SIEM & forensic data.');
