import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.49.4';
const cors={'Access-Control-Allow-Origin':'https://thegenesisera.com','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};
const out=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:cors});
const token=()=>Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('');
const hash=async(s:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s))),b=>b.toString(16).padStart(2,'0')).join('');
const valid=(s:unknown):s is string=>typeof s==='string'&&/^[a-f0-9]{64}$/.test(s);
const tables:Record<string,string>={blackjack:'agc_blackjack_rooms',hearts:'agc_hearts_rooms',duck:'agc_duck_rooms'};
const validNick=(s:unknown)=>typeof s==='string'&&s.trim().length>=2&&s.trim().length<=32&&!/[\u0000-\u001f\u007f]/.test(s);
async function throttle(db:any,req:Request,uid:string|null,action:string,cap:number,ipCap:number){
 const ip=(req.headers.get('cf-connecting-ip')||req.headers.get('x-real-ip')||req.headers.get('x-forwarded-for')||'unknown').split(',')[0].trim().slice(0,128);
 const ipHash=await hash(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!+':'+ip);
 const actor=uid||[ipHash.slice(0,8),ipHash.slice(8,12),ipHash.slice(12,16),ipHash.slice(16,20),ipHash.slice(20,32)].join('-');
 const {data,error}=await db.rpc('agc_multiplayer_allow_action',{p_actor:actor,p_ip_hash:ipHash,p_action:action,p_actor_limit:cap,p_ip_limit:ipCap,p_period:'10 minutes'});
 if(error)throw Error('Rate limit unavailable: '+error.message);
 return data===true;
}
async function liveRoom(db:any,game:string,room:string){
 const {data,error}=await db.from(tables[game]).select('*').eq('id',room).maybeSingle();
 if(error||!data)return null;
 const touched=Date.parse(data.updated_at||data.created_at||'');
 if(data.guest_host&&data.status==='lobby'&&Date.now()-touched>45*60_000){
  await db.from(tables[game]).update({status:'finished'}).eq('id',room).eq('status','lobby');
  await db.from('agc_game_invite_links').update({revoked:true}).eq('game',game).eq('room_id',room);
  return null;
 }
 return data;
}

Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{headers:cors});
 if(req.method!=='POST')return out({error:'POST required'},405);
 try{
 const b=await req.json(),a=b.action,url=Deno.env.get('SUPABASE_URL')!;
 const db=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
 const auth=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{auth:{persistSession:false}});
 const jwt=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');
 const user=jwt?(await auth.auth.getUser(jwt)).data.user:null;
 if(a==='create_room'){
  if(!user?.is_anonymous)return out({error:'Utworzenie pokoju gościa wymaga sesji anonimowej Supabase.'},401);
  if(!Object.hasOwn(tables,b.game)||!validNick(b.nickname))return out({error:'Wybierz grę i podaj nick (2–32 znaki).'},400);
  const game=String(b.game),name=String(b.nickname).trim(),table=tables[game];
  const {data:reserved,error:nickError}=await db.rpc('agc_multiplayer_reserved_nick',{p_nick:name});
  if(nickError)throw nickError;
  if(reserved)return out({error:'Ten nick należy do zarejestrowanego gracza. Wybierz inny nick gościa.'},409);
  if(game==='blackjack'&&(!Number.isInteger(Number(b.players))||Number(b.players)<1||Number(b.players)>10
      ||![10,25,50,100].includes(Number(b.stake))))return out({error:'Wybierz 1–10 przeciwników i stawkę punktową.'},400);
  const {data:current,error:lookupError}=await db.from(table).select('id,status,updated_at,created_at')
   .eq('host_id',user.id).eq('guest_host',true).in('status',['lobby','playing']).limit(1);
  if(lookupError)throw lookupError;
  if(current?.length){
   const x=current[0];
   if(x.status==='lobby'&&Date.now()-Date.parse(x.updated_at||x.created_at)>45*60_000){
     await db.from(table).update({status:'finished'}).eq('id',x.id).eq('status','lobby');
     await db.from('agc_game_invite_links').update({revoked:true}).eq('game',game).eq('room_id',x.id);
   }else return out({error:'Masz już aktywny pokój. Wróć do niego lub zamknij poprzedni.',existing:x.id},409);
  }
  if(!await throttle(db,req,user.id,'create',5,35))return out({error:'Zbyt wiele pokoi. Spróbuj później.'},429);
  const seats=game==='hearts'?[{id:user.id,name,type:'human',ready:true},...Array.from({length:3},(_,i)=>({id:null,name:'AI '+(i+1),type:'ai',ready:true}))]:
    game==='blackjack'?[{id:user.id,name,type:'human'},...Array.from({length:Number(b.players)},(_,i)=>({id:null,name:'Oczekiwanie '+(i+1),type:'human'}))]:null;
  const p={id:crypto.randomUUID(),uid:user.id,name,score:0};
  const record=game==='duck'?{host_id:user.id,guest_host:true,players:[p],expires_at:new Date(Date.now()+45*60_000).toISOString()}:
   game==='hearts'?{host_id:user.id,guest_host:true,mode:'multiplayer',seats,state:null,status:'lobby'}:
   {host_id:user.id,guest_host:true,mode:'multiplayer',seats,state:null,status:'lobby',stake:Number(b.stake)};
  const {data:created,error:ce}=await db.from(table).insert(record).select('id').single();
  if(ce){if(ce.code==='23505')return out({error:'Masz już aktywny pokój w tej grze.'},409);throw ce}
  return out({game,room:created.id});
 }

 if(a==='renew'||a==='revoke'){
 if(!user)return out({error:'Brak sesji gospodarza'},401);
 const table=Object.hasOwn(tables,b.game)?tables[b.game]:null;if(!table||typeof b.room!=='string')return out({error:'Nieprawidłowa gra'},400);
 const r=await liveRoom(db,b.game,b.room);
 if(!r||r.host_id!==user.id||r.status!=='lobby'||Boolean(r.guest_host)!==Boolean(user.is_anonymous))return out({error:'Brak dostępu do lobby'},403);
 if(a==='revoke'){const {error}=await db.from('agc_game_invite_links').update({revoked:true}).eq('game',b.game).eq('room_id',r.id);if(error)throw error;return out({ok:true})}
 if(!await throttle(db,req,user.id,'renew',15,90))return out({error:'Zbyt częste generowanie kodów QR.'},429);
 const key=token(),expires=new Date(Date.now()+1800000).toISOString();
 const {error}=await db.from('agc_game_invite_links').upsert({game:b.game,room_id:r.id,host_id:user.id,token_hash:await hash(key),expires_at:expires,renewed_at:new Date().toISOString(),revoked:false},{onConflict:'game,room_id'});if(error)throw error;
 return out({invite:key,expires});
 }
 if(a==='session'){
 if(!valid(b.session))return out({error:'Nieprawidłowa sesja'},401);
 const {data:s,error}=await db.from('agc_game_guest_sessions').select('id,nickname,expires_at,invite_id').eq('session_hash',await hash(b.session)).eq('revoked',false).gt('expires_at',new Date().toISOString()).maybeSingle();
 if(error||!s)return out({error:'Sesja wygasła'},401);
 const {data:i}=await db.from('agc_game_invite_links').select('game,room_id').eq('id',s.invite_id).single();
 if(!i)return out({error:'Pokój niedostępny'},404);
 const r=await liveRoom(db,i.game,i.room_id);
 if(!r||r.status==='finished')return out({error:'Gra zakończona'},409);
 return out({guest:s.id,nickname:s.nickname,game:i.game,room:i.room_id,expires:s.expires_at});
 }
 if(a==='join_account'){
 if(!user||user.is_anonymous)return out({error:'Zaloguj się'},401);

 if(!valid(b.invite)||b.rules!==true)return out({error:'Nieprawidłowe zaproszenie'},400);
 if(!await throttle(db,req,user.id,'join_account',25,160))return out({error:'Za dużo prób dołączania.'},429);
 const name=String(user.user_metadata?.handle||user.user_metadata?.nickname||'Gracz '+user.id.slice(0,8)).trim().slice(0,32);
 const {data,error}=await db.rpc('agc_join_account_qr',{p_hash:await hash(b.invite),p_uid:user.id,p_nick:name});
 if(error)return out({error:error.message},409);
 return out(data);
 }
 if(a==='join'){
 if(!valid(b.invite)||b.rules!==true||typeof b.nickname!=='string')return out({error:'Podaj nick i zaakceptuj zasady'},400);
 const nickname=b.nickname.trim();if(nickname.length<2||nickname.length>32||/[\u0000-\u001f\u007f]/.test(nickname))return out({error:'Nick musi mieć 2–32 znaki'},400);
 const {data:reserved,error:nickError}=await db.rpc('agc_multiplayer_reserved_nick',{p_nick:nickname});
 if(nickError)throw nickError;
 if(reserved)return out({error:'Nick należy do zarejestrowanego gracza. Wybierz inny.'},409);
 if(!await throttle(db,req,user?.id||null,'join',20,130))return out({error:'Za dużo prób dołączania.'},429);
 const {data:i}=await db.from('agc_game_invite_links').select('id,game,room_id').eq('token_hash',await hash(b.invite)).eq('revoked',false).gt('expires_at',new Date().toISOString()).maybeSingle();
 if(!i)return out({error:'Zaproszenie nieważne'},404);
 const r=await liveRoom(db,i.game,i.room_id);
 if(r?.status!=='lobby')return out({error:'Pokój nie przyjmuje graczy'},409);
 // Until a game adapter reserves a seat atomically, do not issue playable credentials.
 if(!['blackjack','hearts','duck'].includes(i.game))return out({error:'Ta gra nie obsługuje jeszcze gości'},409);
 const session=token();const {data:joined,error}=await db.rpc(i.game==='duck'?'agc_join_duck_guest':i.game==='hearts'?'agc_join_hearts_guest':'agc_join_blackjack_guest',{p_hash:await hash(b.invite),p_nick:nickname,p_session_hash:await hash(session)});
 if(error)return out({error:'Nie można dołączyć: '+error.message},409);
 return out({...joined,session});
 }
 if(a==='inspect'){
 if(!valid(b.invite))return out({error:'Nieprawidłowe zaproszenie'},400);
 const {data:i}=await db.from('agc_game_invite_links').select('game,room_id,expires_at').eq('token_hash',await hash(b.invite)).eq('revoked',false).gt('expires_at',new Date().toISOString()).maybeSingle();
 if(!i)return out({error:'Zaproszenie wygasło lub zostało unieważnione'},404);
 const r=await liveRoom(db,i.game,i.room_id);
 if(r?.status!=='lobby')return out({error:'Pokój nie przyjmuje graczy'},409);
 return out({game:i.game,room:i.room_id,expires:i.expires_at});
 }
 return out({error:'Nieznana operacja'},400);
 }catch{return out({error:'Błąd operacji'},500)}
});