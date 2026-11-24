import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.49.4';
const cors={'Access-Control-Allow-Origin':'https://thegenesisera.com','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS','Content-Type':'application/json','Cache-Control':'no-store'};
const out=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:cors});
const token=()=>Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('');
const hash=async(s:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s))),b=>b.toString(16).padStart(2,'0')).join('');
const valid=(s:unknown):s is string=>typeof s==='string'&&/^[a-f0-9]{64}$/.test(s);
const tables:Record<string,string>={blackjack:'agc_blackjack_rooms',hearts:'agc_hearts_rooms',duck:'agc_duck_rooms'};
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{headers:cors});
 if(req.method!=='POST')return out({error:'POST required'},405);
 try{
 const b=await req.json(),a=b.action,url=Deno.env.get('SUPABASE_URL')!;
 const db=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
 const auth=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{auth:{persistSession:false}});
 const jwt=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');
 const user=jwt?(await auth.auth.getUser(jwt)).data.user:null;
 if(a==='renew'||a==='revoke'){
 if(!user||user.is_anonymous)return out({error:'Zaloguj się'},401);
 const table=tables[b.game];if(!table||typeof b.room!=='string')return out({error:'Nieprawidłowa gra'},400);
 const {data:r}=await db.from(table).select('id,host_id,status').eq('id',b.room).maybeSingle();
 if(!r||r.host_id!==user.id||r.status!=='lobby')return out({error:'Brak dostępu do lobby'},403);
 if(a==='revoke'){const {error}=await db.from('agc_game_invite_links').update({revoked:true}).eq('game',b.game).eq('room_id',r.id);if(error)throw error;return out({ok:true})}
 const key=token(),expires=new Date(Date.now()+1800000).toISOString();
 const {error}=await db.from('agc_game_invite_links').upsert({game:b.game,room_id:r.id,host_id:user.id,token_hash:await hash(key),expires_at:expires,revoked:false},{onConflict:'game,room_id'});if(error)throw error;
 return out({invite:key,expires});
 }
 if(a==='inspect'){
 if(!valid(b.invite))return out({error:'Nieprawidłowe zaproszenie'},400);
 const {data:i}=await db.from('agc_game_invite_links').select('game,room_id,expires_at').eq('token_hash',await hash(b.invite)).eq('revoked',false).gt('expires_at',new Date().toISOString()).maybeSingle();
 if(!i)return out({error:'Zaproszenie wygasło lub zostało unieważnione'},404);
 const {data:r}=await db.from(tables[i.game]).select('status').eq('id',i.room_id).maybeSingle();
 if(r?.status!=='lobby')return out({error:'Pokój nie przyjmuje graczy'},409);
 return out({game:i.game,room:i.room_id,expires:i.expires_at});
 }
 return out({error:'Nieznana operacja'},400);
 }catch{return out({error:'Błąd operacji'},500)}
});