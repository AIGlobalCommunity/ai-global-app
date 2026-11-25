import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.49.4';
const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Content-Type':'application/json'};
const out=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers});
const token=()=>Array.from(crypto.getRandomValues(new Uint8Array(32)),x=>x.toString(16).padStart(2,'0')).join('');
const hash=async(s:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s))),x=>x.toString(16).padStart(2,'0')).join('');
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers});
 if(req.method!=='POST')return out({error:'POST required'},405);
 try{
 const b=await req.json(),a=b.action;
 const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
 const auth=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{auth:{persistSession:false}});
 const jwt=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');
 const user=jwt?(await auth.auth.getUser(jwt)).data.user:null;
 const uid=user&&!user.is_anonymous?user.id:null;
 const now=Date.now();
 const clean=(r:any,p:any)=>({id:r.id,status:r.status,start:r.started_at,serverTime:now,players:r.players.map((x:any)=>({id:x.id,name:x.name,score:x.score,guest:!x.uid})),me:p?.id,host:p?.id===r.players[0].id,targets:r.targets});
 if(a==='create'){
 if(!uid)return out({error:'Zaloguj się'},401);
 const key=token(),p={id:crypto.randomUUID(),uid,name:String(user?.user_metadata?.handle||'Gospodarz').slice(0,32),score:0};
 const {data:r,error}=await db.from('agc_duck_rooms').insert({host_id:uid,players:[p],invite_hash:await hash(key),expires_at:new Date(now+1800000).toISOString()}).select().single();
 if(error)throw error;return out({room:clean(r,p)});
 }
 if(a==='inbox'){
 if(!uid)return out({error:'Zaloguj się'},401);
 const {data,error}=await db.from('agc_duck_invites').select('room_id,created_at').eq('recipient_id',uid).limit(30);if(error)throw error;return out({invites:data});
 }
 const {data:r,error}=await db.from('agc_duck_rooms').select('*').eq('id',b.room).maybeSingle();if(error||!r)return out({error:'Pokój niedostępny'},404);
 let p=r.players.find((x:any)=>uid&&x.uid===uid);
 if(!p&&typeof b.session==='string'&&/^[a-f0-9]{64}$/.test(b.session)){const {data:s}=await db.from('agc_game_guest_sessions').select('id,invite_id').eq('session_hash',await hash(b.session)).eq('revoked',false).gt('expires_at',new Date().toISOString()).maybeSingle();if(s){const {data:i}=await db.from('agc_game_invite_links').select('game,room_id').eq('id',s.invite_id).maybeSingle();if(i?.game==='duck'&&i.room_id===r.id)p=r.players.find((x:any)=>x.guest_id===s.id)}}
 const save=async(patch:any)=>{const {data,error}=await db.from('agc_duck_rooms').update({...patch,version:r.version+1}).eq('id',r.id).eq('version',r.version).select().maybeSingle();if(error||!data)throw Error('Stan zmieniony, ponów próbę');return data};
 if(a==='join'){
 if(p)return out({room:clean(r,p)});
 if(r.status!=='lobby'||r.players.length>=4)return out({error:'Pokój pełny lub gra rozpoczęta'},409);
 if(!uid)return out({error:'Użyj ogólnego zaproszenia QR'},403);let allowed=false;
 if(!allowed&&uid){const {data}=await db.from('agc_duck_invites').select('room_id').eq('room_id',r.id).eq('recipient_id',uid).maybeSingle();allowed=!!data}
 if(!allowed)return out({error:'Zaproszenie nieważne'},403);
 const name=String(b.nick||'').trim();if(name.length<2||name.length>32||!b.rules||r.players.some((x:any)=>x.name.toLowerCase()===name.toLowerCase()))return out({error:'Podaj unikalny nick i zaakceptuj zasady'});
 const session=token();p={id:crypto.randomUUID(),uid,name,score:0,session_hash:await hash(session)};
 const changed=await save({players:[...r.players,p]});return out({room:clean(changed,p),session});
 }
 if(!p)return out({error:'Brak dostępu'},403);
 if(a==='state'&&r.status==='playing'&&now-r.started_at>92000){const changed=await save({status:'finished'});return out({room:clean(changed,p)})}if(a==='state')return out({room:clean(r,p)});
 const host=uid===r.host_id;if(a==='close'&&host){await save({status:'finished'});return out({ok:true})}
 if(a==='invite'){
 if(!host||r.status!=='lobby')return out({error:'Tylko gospodarz'},403);
 if(a==='invite'){const {data:id,error}=await db.rpc('agc_hearts_resolve_invitee',{p_identity:String(b.identity||'').trim()});if(error||!id||id===uid)return out({error:'Nie znaleziono gracza'});const {error:e}=await db.from('agc_duck_invites').upsert({room_id:r.id,recipient_id:id});if(e)throw e;return out({ok:true})}
 const key=token();await save({invite_hash:a==='renew'?await hash(key):null,expires_at:new Date(now+1800000).toISOString()});return out({invite:a==='renew'?key:null});
 }
 if(a==='start'){
 if(!host||r.status!=='lobby'||r.players.length<2)return out({error:'Potrzeba 2–4 graczy'},409);
 const targets=Array.from({length:60},(_,i)=>({id:i,at:i*1500,duration:2400,dir:Math.random()<.5?1:-1,y:.2+Math.random()*.5,hit:null}));
 const changed=await save({status:'playing',started_at:now+3000,targets,invite_hash:null});return out({room:clean(changed,p)});
 }
 if(a==='hit'){
 if(r.status!=='playing')return out({error:'Gra nieaktywna'},409);
 const t=r.targets.find((x:any)=>x.id===b.target),elapsed=now-r.started_at;
 if(!t||t.hit||elapsed<t.at||elapsed>t.at+t.duration||now-(p.last_shot||0)<180)return out({error:'Trafienie nieaktualne'},409);
 const x=t.dir===1?(elapsed-t.at)/t.duration:1-(elapsed-t.at)/t.duration;
 if(!Number.isFinite(b.x)||!Number.isFinite(b.y)||Math.abs(b.x-x)>.12||Math.abs(b.y-t.y)>.09)return out({error:'Pudło'},409);
 t.hit=p.id;p.score+=100;p.last_shot=now;const changed=await save({players:r.players,targets:r.targets});return out({room:clean(changed,p)});
 }
 return out({error:'Nieznana operacja'},400);
 }catch{return out({error:'Operacja nie powiodła się, spróbuj ponownie'},409)}
});
