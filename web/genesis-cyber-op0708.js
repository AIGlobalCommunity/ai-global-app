(()=>{'use strict';
const root=document.getElementById('op0708');let session=null;
const el=(t,v,c)=>{const n=document.createElement(t);if(v!==undefined)n.textContent=String(v);if(c)n.className=c;return n};
const rng=()=>crypto.getRandomValues(new Uint32Array(1))[0],rid=()=>rng().toString(16).padStart(8,'0');
const escCsv=s=>'"'+String(s).replaceAll('"','""')+'"';
const flagOf=clue=>String(clue).match(/GENESIS\{[a-z0-9]+\}/i)?.[0]||'';
function build(m,clue){
 if(![7,8].includes(Number(m)))throw Error('Invalid R16 operation');
 const flag=flagOf(clue);if(!flag)throw Error('Training artifact missing: verify server session');
 const s={m:Number(m),caseId:'GCW-'+rid(),flag,view:'all',filter:'',commands:0,history:[]};
 if(s.m===7){
  const flow='F-'+rid(),src='192.0.2.45',dst='198.51.100.77';
  s.flow=flow;s.packets=Array.from({length:84},(_,i)=>({number:i+1,time:'08:'+String(Math.floor(i*2/60)).padStart(2,'0')+':'+String(i*2%60).padStart(2,'0'),source:'192.0.2.'+(10+i%13),destination:'198.51.100.'+(10+i%7),protocol:['TCP','UDP','DNS','TLS','HTTP'][i%5],bytes:64+(rng()%1900),flow:'F-'+(100+i%9),sequence:0,payload:i%7===0?'SAMPLE-KEEPALIVE':'',tag:'baseline'}));
  const parts=flag.match(/.{1,5}/g)||[];
  const order=parts.map((_,i)=>i).reverse();
  for(let k=0;k<order.length;k++){const index=22+k*4,part=order[k];s.packets[index]={...s.packets[index],source:src,destination:dst,protocol:'DNS',bytes:700+(rng()%320),flow,sequence:part+1,payload:parts[part],tag:'burst'};}
  for(const i of [13,45,57,69])s.packets[i]={...s.packets[i],bytes:2500+(rng()%2500),tag:'volume'};
  s.flowCatalog=[flow,...new Set(s.packets.filter(p=>p.tag==='volume').map(p=>p.flow))];
 }else{
  const checks=[
   ['ssh','/etc/ssh/sshd_config','PermitRootLogin','yes','no','2035-04-21T08:31:00Z'],
   ['ssh','/etc/ssh/sshd_config','PasswordAuthentication','no','no','2035-04-21T08:31:00Z'],
   ['access','/etc/sudoers.d/maintenance','NOPASSWD','ALL','none','2035-04-21T08:34:00Z'],
   ['access','/etc/sudoers.d/maintenance','owner','root','root','2035-04-21T08:34:00Z'],
   ['files','/srv/genesis/keys.env','mode','0644','0600','2035-04-21T08:39:00Z'],
   ['files','/srv/genesis/keys.env','owner','root','root','2035-04-21T08:39:00Z'],
   ['network','/etc/sysctl.d/99-security.conf','rp_filter','1','1','2035-04-21T08:41:00Z'],
   ['network','/etc/sysctl.d/99-security.conf','accept_redirects','0','0','2035-04-21T08:41:00Z'],
   ['service','/etc/genesis/agent.ini','debug','true','false','2035-04-21T08:43:00Z'],
   ['service','/etc/genesis/agent.ini','transport','tls','tls','2035-04-21T08:43:00Z'],
   ['service','/etc/genesis/agent.ini','log_level','info','info','2035-04-21T08:43:00Z'],
   ['audit','/etc/audit/rules.d/genesis.rules','enabled','yes','yes','2035-04-21T08:45:00Z'],
   ['audit','/etc/audit/rules.d/genesis.rules','retention_days','90','90','2035-04-21T08:45:00Z'],
   ['network','/etc/hosts.allow','policy','deny-default','deny-default','2035-04-21T08:47:00Z'],
   ['service','/etc/genesis/agent.ini','restart','on-failure','on-failure','2035-04-21T08:43:00Z']
  ];
  s.checks=checks.map(([domain,path,key,observed,expected,time],i)=>({id:'CHK-'+String(i+1).padStart(3,'0'),domain,path,key,observed,expected,time,deviation:observed!==expected}));
  s.parts=(flag.match(/.{1,5}/g)||[]).map((payload,i)=>({id:'SEG-'+rid(),sequence:i+1,payload,ticket:s.caseId}));
  s.parts.reverse();
 }
 return s;
}
function files(h){
 if(!session)return{};const s=session,f={};
 if(s.m===7){
  if(h==='gateway')f['/captures/packets.csv']='time,flow,src,dst,protocol,bytes,sequence,payload\n'+s.packets.map(p=>[p.time,p.flow,p.source,p.destination,p.protocol,p.bytes,p.sequence,escCsv(p.payload)].join(',')).join('\n');
  if(h==='soc'){
   f['/evidence/flow-index.csv']='flow,count,bytes\n'+s.flowCatalog.map(flow=>[flow,s.packets.filter(p=>p.flow===flow).length,s.packets.filter(p=>p.flow===flow).reduce((a,p)=>a+p.bytes,0)].join(',')).join('\n');
   f['/logs/network.log']='Multiple synthetic volume spikes. Correlate time, flow and packet sequence; one alert is not decisive.';
  }
  if(h==='archive')f['/evidence/guide.txt']='Training packet data uses TEST-NET addresses. Inspect the capture, isolate a repeated flow, order fragments by sequence.';
 }else{
  if(h==='gateway')f['/etc/host.info']='GENESIS-LINUX-35 | isolated synthetic audit host | '+s.caseId;
  if(h==='soc')f['/policy/baseline.csv']='domain,path,key,expected\n'+s.checks.map(c=>[c.domain,c.path,c.key,c.expected].join(',')).join('\n');
  if(h==='workstation'){
   f['/logs/change.log']='08:31 ssh policy changed\n08:34 maintenance privilege updated\n08:39 key file permissions changed\n08:43 telemetry debug enabled\n08:47 network policy verified';
   f['/evidence/recovery.csv']='ticket,segment,sequence,payload\n'+s.parts.map(p=>[p.ticket,p.id,p.sequence,escCsv(p.payload)].join(',')).join('\n');
  }
  if(h==='vault')f['/evidence/case.txt']='Case '+s.caseId+'\nFind deviations, correlate timestamps in /logs/change.log on workstation, then examine /evidence/recovery.csv.';
  for(const c of s.checks){if(h==='gateway')f[c.path]=(f[c.path]||'')+c.key+'='+c.observed+'\n';}
 }
 return f;
}
function chart(title,values){
 const group=el('div',undefined,'op78-bars');group.append(el('small',title));const max=Math.max(1,...values.map(x=>x[1]));
 for(const [label,value] of values){const row=el('div',undefined,'op78-chartrow'),track=el('div',undefined,'op78-track'),fill=el('div',undefined,'op78-fill');fill.style.width=(value/max*100)+'%';track.append(fill);row.append(el('span',label),track,el('strong',value));group.append(row)}
 return group;
}
function details(row){
 if(!session)return;const s=session;const box=document.getElementById('op78-detail');if(!box)return;
 box.textContent=s.m===7?['PACKET '+row.number+' / '+row.time,'Flow: '+row.flow,'Source: '+row.source,'Destination: '+row.destination,'Protocol: '+row.protocol,'Bytes: '+row.bytes,'Segment: '+(row.sequence||'-'),'Payload: '+(row.payload||'[synthetic baseline]')].join('\n'):
 ['CONTROL '+row.id,'Subsystem: '+row.domain,'Path: '+row.path,'Parameter: '+row.key,'Observed: '+row.observed,'Expected: '+row.expected,'Policy: '+(row.deviation?'DEVIATION':'COMPLIANT'),'Change: '+row.time].join('\n');
}
function exec(cmd){
 if(!session)return'No active operation';
 const s=session,[op,...parts]=cmd.trim().split(/\s+/),arg=parts.join(' ');s.commands++;
 if(op==='help')return s.m===7?'flows | trace FLOW_ID | protocol DNS | timeline | help':'policy | check PATH | deviations | timeline | help';
 if(s.m===7){
  if(op==='flows')return [...new Set(s.packets.map(x=>x.flow))].map(f=>f+'  count='+s.packets.filter(x=>x.flow===f).length).join('\n');
  if(op==='trace')return s.packets.filter(x=>x.flow===arg).map(x=>x.time+' #'+x.number+' seq='+x.sequence+' '+(x.payload||'-')).join('\n')||'Unknown flow';
  if(op==='protocol')return s.packets.filter(x=>x.protocol===arg.toUpperCase()).map(x=>x.time+' '+x.flow+' '+x.source+' > '+x.destination).join('\n')||'No packets';
  if(op==='timeline')return s.packets.filter(x=>x.bytes>1800).map(x=>x.time+' '+x.flow+' '+x.bytes+' B').join('\n');
 }else{
  if(op==='policy')return s.checks.map(x=>x.path+' '+x.key+'='+x.expected).join('\n');
  if(op==='deviations')return s.checks.filter(x=>x.deviation).map(x=>x.path+' '+x.key+' '+x.observed+' != '+x.expected).join('\n');
  if(op==='check')return s.checks.filter(x=>x.path.includes(arg)).map(x=>x.key+' observed='+x.observed+' expected='+x.expected).join('\n')||'Unknown path';
  if(op==='timeline')return s.checks.map(x=>x.time+' '+x.path).join('\n');
 }
 return 'Unknown command. Type help.';
}
function render(){
 if(!root||!session)return;const s=session;root.replaceChildren();root.dataset.operation=s.m;
 root.append(el('small',s.m===7?'NETWORK SECURITY // PACKET INVESTIGATOR':'LINUX SECURITY // POLICY AUDITOR'));
 const head=el('div',undefined,'op78-heading');head.append(el('strong',s.m===7?'Network Anomaly':'Configuration Audit'),el('span',s.caseId+' · SYNTHETIC / ISOLATED'));root.append(head);
 if(s.m===7)root.append(chart('PROTOCOL DISTRIBUTION',['TCP','UDP','DNS','TLS','HTTP'].map(t=>[t,s.packets.filter(x=>x.protocol===t).length])),chart('TRAFFIC BY TIME BUCKET',Array.from({length:7},(_,i)=>[String(i*12).padStart(2,'0')+'–'+String((i+1)*12).padStart(2,'0'),s.packets.slice(i*12,(i+1)*12).reduce((a,p)=>a+p.bytes,0)])));
 else root.append(chart('COMPLIANCE BY SUBSYSTEM',[...new Set(s.checks.map(x=>x.domain))].map(d=>[d,s.checks.filter(x=>x.domain===d&&!x.deviation).length])));
 const ctr=el('div',undefined,'op78-controls'),input=el('input'),selection=el('select');
 input.type='search';input.placeholder=s.m===7?'Filtruj flow, adres lub numer pakietu':'Filtruj ścieżkę, usługę lub parametr';input.setAttribute('aria-label','Filtr danych operacji');
 for(const [val,label] of (s.m===7?[['all','Wszystkie protokoły'],...['TCP','UDP','DNS','TLS','HTTP'].map(x=>[x,x])]:[['all','Wszystkie kontrole'],['deviation','Niezgodne'],['compliant','Zgodne']])){const opt=el('option',label);opt.value=val;selection.append(opt)}
 ctr.append(input,selection);root.append(ctr);
 const area=el('div',undefined,'wb-scroll'),table=el('table');area.append(table);root.append(area);
 const info=el('pre','Wybierz rekord, aby otworzyć analizę.','op78-detail');info.id='op78-detail';root.append(info);
 function update(){
  table.replaceChildren();const hdr=el('tr');for(const x of(s.m===7?['#','Czas','Przepływ','Protokół','Bajty','Sekwencja']:['ID','Domena','Ścieżka','Parametr','Stan']))hdr.append(el('th',x));table.append(hdr);
  const records=s.m===7?s.packets:s.checks;
  const filtered=records.filter(x=>(selection.value==='all'||(s.m===7?x.protocol===selection.value:(selection.value==='deviation'?x.deviation:!x.deviation)))&&Object.values(x).join(' ').toLowerCase().includes(input.value.toLowerCase()));
  for(const r of filtered){const tr=el('tr');tr.tabIndex=0;for(const x of(s.m===7?[r.number,r.time,r.flow,r.protocol,r.bytes,r.sequence||'—']:[r.id,r.domain,r.path,r.key,r.deviation?'REVIEW':'OK']))tr.append(el('td',x));tr.onclick=()=>details(r);tr.onkeydown=ev=>{if(ev.key==='Enter')details(r)};table.append(tr)}
 }
 input.oninput=update;selection.onchange=update;update();
 const consoleBox=el('div',undefined,'op78-console'),label=el('small','DEDICATED ANALYST CONSOLE'),form=el('form'),cmd=el('input'),submit=el('button','RUN'),output=el('pre','Type help to inspect available commands.','op78-output');
 cmd.placeholder=s.m===7?'trace FLOW-ID':'check /etc/ssh';cmd.setAttribute('aria-label','Polecenie konsoli analitycznej');submit.type='submit';form.append(cmd,submit);
 form.onsubmit=event=>{event.preventDefault();output.textContent=exec(cmd.value);cmd.value=''};consoleBox.append(label,form,output);root.append(consoleBox);
 root.append(el('small','Wynik operacji i flaga są weryfikowane w istniejącej funkcji serwerowej.'));
}
const api={build,active:()=>!!session,start(m,clue){session=build(m,clue);if(root)root.hidden=false;render()},stop(){session=null;if(root)root.hidden=true},getFiles:files,
 hint(){return session?.m===7?'Wyizoluj powtarzający się przepływ, zestaw protokoły i czas zdarzeń. Dopiero potem ułóż segmenty po sequence.':'Porównaj ustawienia z polityką, sprawdź chronologię zmian i powiąż materiał w /evidence z kartą sprawy.'},
 review(){return session?.m===7?'W analizatorze porównaj skoki transmisji z rekordami DNS. Użyj flows, następnie trace dla właściwego identyfikatora. Odtwórz fragmenty według sequence, nie kolejności przechwycenia.':'Przeprowadź policy, deviations oraz timeline. Zweryfikuj różnice SSH, sudo, uprawnień do kluczy i diagnostyki. Na workstation odczytaj recovery.csv i połącz segmenty rosnąco według sequence.'}};
globalThis.GenesisAdvanced=api;
})();