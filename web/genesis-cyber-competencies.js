(()=>{'use strict';
const roles={DF:['PD-WRL-002','Digital Forensics'],DE:['IN-WRL-002','Digital Evidence Analysis'],DC:['PD-WRL-001','Defensive Cybersecurity'],IR:['PD-WRL-003','Incident Response'],TA:['PD-WRL-006','Threat Analysis'],SS:['IO-WRL-006','Systems Security Analysis'],NO:['IO-WRL-004','Network Operations']};
const profiles={DF:'Digital Forensics Investigator',IR:'Cyber Incident Responder',CTI:'Cyber Threat Intelligence Specialist',CI:'Cybersecurity Implementer'};
const catalog={
1:['Fractured Signal',['DF'],['DF'],['DE.AE'],['Interpretacja zapisu HEX','Analiza przechwyconego materiału']],
2:['Ghost Transmission',['DF'],['DF'],['DE.AE'],['Dekodowanie Base64','Weryfikacja integralności SHA-256']],
3:['Reverse Signal',['DF'],['DF'],['DE.AE'],['Ustalanie kolejności fragmentów','Rekonstrukcja tekstu']],
4:['Cipher Labyrinth',['DF'],['DF'],['DE.AE'],['Wielostopniowe transformacje danych','Weryfikacja rekonstruowanego materiału']],
5:['Silent Intruder',['DC','IR'],['IR'],['DE.AE','RS.AN'],['Filtrowanie alertów SOC','Korelacja zdarzeń','Rozpoznawanie incydentów']],
6:['Digital Evidence',['DF','DE'],['DF'],['RS.AN'],['Analiza metadanych','Weryfikacja sum kontrolnych','Ocena pochodzenia dowodów']],
7:['Network Anomaly',['DC','NO'],['IR'],['DE.CM','DE.AE'],['Analiza protokołów','Filtrowanie pakietów','Korelacja przepływów']],
8:['Configuration Audit',['SS'],['CI'],['PR.PS','PR.AA'],['Audyt konfiguracji Linux','Ocena uprawnień','Porównanie z polityką bezpieczeństwa']],
9:['Classified Report',['TA'],['CTI'],['DE.AE','RS.AN'],['Ocena wiarygodności źródeł','Analiza metadanych dokumentów','Rekonstrukcja chronologii']],
10:['Fragmented Signal',['DF','DE'],['DF'],['RS.AN'],['Analiza HEX i offsetów','Weryfikacja integralności','Rekonstrukcja bloków']]
};
const $=id=>document.getElementById(id);
function el(tag,value,cls){const x=document.createElement(tag);if(value!==undefined)x.textContent=value;if(cls)x.className=cls;return x}
let snapshot=null,view=false;
const tab=$('competencies-tab'),panel=$('competencies-panel'),detail=$('mission-competencies');
function source(parent,label,url){const a=el('a',label);a.href=url;a.target='_blank';a.rel='noopener noreferrer';parent.append(a)}
function render(){panel.replaceChildren();panel.append(el('h2','PROFIL KOMPETENCJI / SKILLS MATRIX'),el('p','Mapowanie edukacyjne GENESIS: NICE Components 2.2.0, ENISA ECSF i NIST CSF 2.0. Nie jest certyfikacją ani oceną pełnej roli zawodowej.'));if(!snapshot){panel.append(el('p','Zaloguj się i odśwież postęp kampanii.'));return}
const total=Number(snapshot.total)||0;const available=Object.keys(catalog).map(Number).filter(n=>n<=total);const solved=new Set((snapshot.missions||[]).filter(x=>x.solved===true).map(x=>Number(x.mission)));const done=available.filter(n=>solved.has(n));panel.append(el('h3',done.length+' / '+available.length+' zmapowanych operacji ukończonych'));
function group(title,index,dict){const box=el('section');box.append(el('h3',title));const keys=[...new Set(available.flatMap(n=>catalog[n][index]))];for(const key of keys){const expected=available.filter(n=>catalog[n][index].includes(key));const earned=expected.filter(n=>solved.has(n));const label=Array.isArray(dict[key])?dict[key].join(' · '):dict[key]||key;box.append(el('p',label+' — '+earned.length+' / '+expected.length+' operacji'));const bar=el('progress');bar.max=expected.length;bar.value=earned.length;bar.setAttribute('aria-label',label);bar.style.width='100%';box.append(bar,el('small','Dowody: '+(earned.map(n=>'OP '+String(n).padStart(3,'0')).join(', ')||'brak')))}panel.append(box)}
group('NIST NICE — powiązane role',1,roles);group('ENISA ECSF — powiązane profile',2,profiles);group('NIST CSF 2.0 — powiązane kategorie',3,{});
const skills=el('section');skills.append(el('h3','Umiejętności ćwiczone w ukończonych operacjach'));for(const s of new Set(done.flatMap(n=>catalog[n][4])))skills.append(el('p','✓ '+s));panel.append(skills,el('p','Każda ukończona operacja jest liczona tylko raz. Wynik oznacza pokrycie ćwiczeń dostępnych w GENESIS, nie procent opanowania całego standardu.'));const links=el('p');source(links,'NIST NICE','https://www.nist.gov/itl/applied-cybersecurity/nice/nice-framework-resource-center/nice-framework-current-versions');links.append(document.createTextNode(' | '));source(links,'ENISA ECSF','https://www.enisa.europa.eu/topics/skills-and-competences/skills-development/european-cybersecurity-skills-framework-ecsf');links.append(document.createTextNode(' | '));source(links,'NIST CSF','https://www.nist.gov/cyberframework');panel.append(links)}
function show(on){view=on;panel.hidden=!on;tab.classList.toggle('active',on);tab.setAttribute('aria-pressed',String(on));for(const id of ['campaign-map','missions','progress-dashboard','categories','specialist-workbench','lab']){const x=$(id);if(!x)continue;if(on){x.dataset.competencyDisplay=x.style.display;x.style.display='none'}else if('competencyDisplay'in x.dataset){x.style.display=x.dataset.competencyDisplay;delete x.dataset.competencyDisplay}}if(on)render()}
tab.addEventListener('click',()=>show(!view));for(const id of ['campaign','arena'])$(id).addEventListener('click',()=>{if(view)show(false)});
function receive(s){if(s&&!s.arena)snapshot=s.loaded?s:null;if(view)render()}
document.addEventListener('genesis:progress',e=>receive(e.detail));receive(window.genesisProgressSnapshot);
document.addEventListener('genesis:mission',e=>{const c=!e.detail.arena&&catalog[Number(e.detail.mission)];detail.hidden=!c;detail.replaceChildren();if(!c)return;if(view)show(false);detail.append(el('h3','Sprawdzane kompetencje / NIST & ENISA'),el('p',c[4].join(' • ')),el('p','NICE: '+c[1].map(k=>roles[k].join(' · ')).join('; ')),el('p','ECSF: '+c[2].map(k=>profiles[k]).join('; ')),el('p','CSF 2.0: '+c[3].join(', ')),el('small','Powiązanie częściowe; ukończenie zadania nie potwierdza całej roli zawodowej.'))});
})();