/* Shared multiplayer invites and unregistered guest identity; used by every game adapter. */
(()=>{'use strict';
const project='gjnddmurmegbklvedhnp';
const origin='https://'+project+'.supabase.co';
const inviteEndpoint=origin+'/functions/v1/game-invite';
const publishable='sb_publishable_Ty3Beae5ztODv0MM3Z_HDA_WEGwOyLP';
const games=new Set(['hearts','blackjack','duck']);
let anonymousClientPromise;
function assertGame(game){if(!games.has(game))throw Error('Nieobsługiwana gra')}
function accountToken(){
 for(const k of ['sb-'+project+'-auth-token','supabase.auth.token']){
  try{const s=JSON.parse(localStorage.getItem(k)||'null');const t=s?.access_token||s?.currentSession?.access_token;
   if(typeof t==='string'&&t.split('.').length===3)return t}catch{}
 }
 return null;
}
async function anonymousClient(){
 if(!anonymousClientPromise) anonymousClientPromise=import('https://esm.sh/@supabase/supabase-js@2.49.4')
  .then(({createClient})=>createClient(origin,publishable,{
   auth:{storageKey:'agc-multiplayer-guest-auth',persistSession:true,autoRefreshToken:true,detectSessionInUrl:false}
  })).catch(e=>{anonymousClientPromise=null;throw e});
 return anonymousClientPromise;
}
async function guestToken(nickname){
 const c=await anonymousClient();
 const {data:stored,error:storageError}=await c.auth.getSession();
 if(storageError)throw Error(storageError.message);
 if(stored.session?.user?.is_anonymous)return stored.session.access_token;
 if(!nickname)throw Error('Najpierw wpisz nick gościa.');
 const {data,error}=await c.auth.signInAnonymously({options:{data:{nickname}}});
 if(error||!data.session?.access_token)throw Error('Logowanie gościa jest niedostępne. Sprawdź, czy w Supabase Auth włączono Anonymous Sign-Ins. '+(error?.message||''));
 return data.session.access_token;
}
async function post(endpoint,body,bearer){
 const response=await fetch(endpoint,{method:'POST',headers:{
  'Content-Type':'application/json',...(bearer?{Authorization:'Bearer '+bearer}:{})
 },body:JSON.stringify(body),cache:'no-store'});
 let result;try{result=await response.json()}catch{throw Error('Nieprawidłowa odpowiedź serwera ('+response.status+').')}
 if(!response.ok||result?.error)throw Error(result?.error||'Błąd połączenia ('+response.status+').');
 return result;
}
const call=(action,data={},accessToken)=>post(inviteEndpoint,{action,...data},accessToken);
async function gameRequest(game,action,data={},credentials={}){
 assertGame(game);
 const accessToken=credentials.host?await guestToken():credentials.account?accountToken():null;
 if(credentials.host&&!accessToken)throw Error('Sesja gospodarza wygasła.');
 if(action==='qr_renew'||action==='qr_revoke')
  return call(action==='qr_renew'?'renew':'revoke',{game,room:data.room},accessToken);
 return post(origin+'/functions/v1/'+game+'-game',
   {action,...data,...(credentials.session?{session:credentials.session}:{})},accessToken);
}
function key(game){assertGame(game);return 'genesis-'+game+'-guest-host'}
function rememberHost(game,room,nickname){
 localStorage.setItem(key(game),JSON.stringify({host:true,room,nickname,savedAt:Date.now()}));
 localStorage.setItem('agc-multiplayer-nickname',nickname);
}
function restoreHost(game){
 try{const x=JSON.parse(localStorage.getItem(key(game))||'null');
  if(x?.host&&typeof x.room==='string'&&/^[0-9a-f-]{36}$/i.test(x.room))return x;
 }catch{}
 return null;
}
function forgetHost(game){localStorage.removeItem(key(game))}
const link=token=>location.origin+'/join.html#invite='+encodeURIComponent(token);
function qr(element,url){
 element.replaceChildren();
 if(!window.QRCode)throw Error('Generator QR niedostępny');
 new window.QRCode(element,{text:url,width:220,height:220,correctLevel:window.QRCode.CorrectLevel.M});
}
function inviteFromInput(value){
 const s=String(value||'').trim();
 let invite=s;
 if(!/^[a-f0-9]{64}$/.test(s)){
  const u=new URL(s,location.origin);
  if(u.origin!==location.origin)throw Error('Użyj linku zaproszenia z The Genesis Era.');
  invite=new URLSearchParams(u.hash.slice(1)).get('invite')||'';
 }
 if(!/^[a-f0-9]{64}$/.test(invite))throw Error('Wklej pełny link zaproszenia lub kod.');
 return invite;
}
function mountGuestUI(game,container,{createData=()=>({}),onCreated}={}){
 assertGame(game);
 const section=document.createElement('div');
 section.className='agc-guest-multiplayer';
 section.style.cssText='margin:14px auto;padding:16px;max-width:520px;border:1px solid #c1a76e;border-radius:16px;background:#08242dcc;color:#fff;text-align:left;';
 section.innerHTML='<strong style="font-size:18px;color:#f6d68c">🎮 Graj ze znajomymi bez rejestracji</strong>'+
  '<label style="display:block;margin-top:12px">Twój nick<input data-guest-nick maxlength="32" minlength="2" autocomplete="nickname" placeholder="Twój nick" style="display:block;margin-top:5px;width:100%;max-width:100%;padding:10px;background:#102d36;color:white;border:1px solid #86aaa8;border-radius:9px"></label>'+
  '<div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:12px"><button type="button" data-guest-create>Utwórz pokój</button><button type="button" data-guest-join>Dołącz do gry</button></div>'+
  '<input data-guest-link placeholder="Wklej link zaproszenia" aria-label="Link zaproszenia" style="display:none;width:100%;margin-top:10px;padding:10px;background:#102d36;color:white;border:1px solid #86aaa8;border-radius:9px">'+
  '<p data-guest-status role="status" style="min-height:20px;font-size:13px;overflow-wrap:anywhere"></p>';
 container.prepend(section);
 const nick=section.querySelector('[data-guest-nick]');
 const joinInput=section.querySelector('[data-guest-link]');
 const status=section.querySelector('[data-guest-status]');
 const create=section.querySelector('[data-guest-create]');
 nick.value=localStorage.getItem('agc-multiplayer-nickname')||'';
 create.onclick=async()=>{
  const nickname=nick.value.trim();
  if(nickname.length<2||nickname.length>32||/[\u0000-\u001f\u007f]/.test(nickname)){status.textContent='Nick musi mieć od 2 do 32 znaków.';return}
  create.disabled=true;status.textContent='Tworzenie pokoju…';
  try{
   await guestToken(nickname);
   const data=typeof createData==='function'?createData():createData;
   const result=await gameRequest(game,'create',{...data,nickname},{host:true});
   if(!result.room?.id)throw Error('Serwer nie zwrócił pokoju');
   rememberHost(game,result.room.id,nickname);
   onCreated?.(result,nickname);
   status.textContent='Pokój gotowy. Udostępnij kod QR znajomym!';
  }catch(e){status.textContent=String(e.message||e)}finally{create.disabled=false}
 };
 section.querySelector('[data-guest-join]').onclick=()=>{
  if(joinInput.style.display==='none'){joinInput.style.display='block';joinInput.focus();return}
  try{location.assign(link(inviteFromInput(joinInput.value)))}catch(e){status.textContent=e.message}
 };
 joinInput.addEventListener('keydown',e=>{if(e.key==='Enter')section.querySelector('[data-guest-join]').click()});
 return section;
}
function addShareButton(container,input){
 if(container.querySelector('[data-agc-share]'))return;
 const b=document.createElement('button');b.type='button';b.textContent='📤 Udostępnij link';b.dataset.agcShare='true';
 b.onclick=async()=>{
  const url=input.value;
  if(!url)return;
  try{
   if(navigator.share)await navigator.share({title:'The Genesis Era – zaproszenie do gry',url});
   else{await navigator.clipboard.writeText(url);b.textContent='✓ Link skopiowany'}
  }catch(e){if(e.name!=='AbortError')b.textContent='Skopiuj link obok'}
 };
 container.append(b);
}
window.GenesisInvites=Object.freeze({call,accountToken,guestToken,gameRequest,link,inspect:invite=>call('inspect',{invite}),
 renew:(game,room,accessToken)=>call('renew',{game,room},accessToken),
 revoke:(game,room,accessToken)=>call('revoke',{game,room},accessToken),
 qr,rememberHost,restoreHost,forgetHost,mountGuestUI,addShareButton});
})();