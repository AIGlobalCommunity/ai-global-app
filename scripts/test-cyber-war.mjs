import { readFileSync } from 'node:fs';
import { Script, runInNewContext } from 'node:vm';
import { webcrypto } from 'node:crypto';
import assert from 'node:assert/strict';

const file = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const html = file('web/genesis-cyber-war.html');
const js = ['web/genesis-cyber-op0506.js','web/genesis-cyber-op0708.js','web/genesis-cyber-op0304.js','web/genesis-cyber-campaign.js','web/genesis-cyber-workbench.js'];
for (const path of js) new Script(file(path), { filename: path });
for (const [, content] of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) {
  if (content.trim()) new Script(content, { filename: 'web/genesis-cyber-war.html:inline' });
}
assert.match(html, /id="op0506"/);
assert.match(html, /id="op0708"/);
assert.match(html, /genesis-cyber-op0506\.js/);
assert.match(html, /GenesisEvidence\.start\(/);
assert.match(html, /GenesisAdvanced\.start\(/);
assert.match(html, /GenesisEvidence\.getFiles\(/);
assert.match(html, /GenesisEvidence\?\.stop\(/);
assert.match(html, /testerMode=!!d\.tester/);
assert.doesNotMatch(html, /mpiw123@gmail\.com/i);
class MockElement {
  constructor(tag){this.tag=tag;this.hidden=true;this.dataset={};this.style={};this.children=[];this.value='';}
  append(...nodes){this.children.push(...nodes)}
  replaceChildren(...nodes){this.children=[...nodes]}
  setAttribute(key,value){this[key]=value}
}
const root=new MockElement('div');
const advancedRoot=new MockElement('div');
const documentMock={getElementById:id=>id==='op0506'?root:id==='op0708'?advancedRoot:null,createElement:tag=>new MockElement(tag)};
const globals = { document:documentMock, crypto: webcrypto, TextEncoder, TextDecoder };
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
const advancedGlobals = { document:documentMock, crypto: webcrypto, TextEncoder, TextDecoder };
advancedGlobals.globalThis=advancedGlobals;
runInNewContext(file('web/genesis-cyber-op0708.js'),advancedGlobals);
const advance=advancedGlobals.GenesisAdvanced;
assert.ok(advance && typeof advance.start==='function');
const n=advance.build(7,'src,dst,action,payload\\n192.0.2.1,192.0.2.20,allow,heartbeat\\n192.0.2.30,192.0.2.40,deny,GENESIS{abc12345}');
assert.equal(n.packets.length,84);
assert.ok(n.packets.filter(x=>x.flow===n.flow).length>=3);
assert.ok(n.packets.some(x=>x.protocol==='DNS'));
const l=advance.build(8,'[public]\\ndebug=false\\n[incident]\\nartifact=GENESIS{abc12345}');
assert.equal(l.checks.length,15);
assert.ok(l.checks.some(x=>x.deviation));
assert.ok(l.parts.length>=3);

api.start(5,'2026 WARN incident=confirmed evidence=GENESIS{abc12345}');
assert.equal(root.hidden,false);
assert.ok(api.getFiles('soc')['/evidence/case.txt']);
assert.ok(Object.keys(api.getFiles('soc')).some(x=>x.startsWith('/evidence/REQ-')));
api.stop(); assert.equal(root.hidden,true);
api.start(6,'{"status":"quarantined","evidence":"GENESIS{abc12345}"}');
assert.ok(api.getFiles('vault')['/evidence/manifest.csv']);
assert.equal(api.getFiles('vault')['/evidence/manifest.csv'].split('\\n').length,11);
api.stop();
advance.start(7,'src,dst,action,payload\\n192.0.2.30,192.0.2.40,deny,GENESIS{abc12345}');
assert.equal(advancedRoot.hidden,false);
assert.ok(advance.getFiles('gateway')['/captures/packets.csv'].split('\\n').length>80);
advance.stop(); assert.equal(advancedRoot.hidden,true);
advance.start(8,'[incident]\\nartifact=GENESIS{abc12345}');
assert.ok(advance.getFiles('soc')['/policy/baseline.csv']);
assert.ok(advance.getFiles('workstation')['/evidence/recovery.csv']);
advance.stop();
console.log('PASS: R16 JS syntax, wiring, tester UI, OP005/006 SIEM/forensics and OP007/008 network/Linux data.');
