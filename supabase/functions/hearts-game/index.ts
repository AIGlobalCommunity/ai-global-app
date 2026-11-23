import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.49.4';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, x-client-info, content-type','Content-Type':'application/json'};
const out=(x:unknown,status=200)=>new Response(JSON.stringify(x),{status,headers:cors});
const bad=(s:string,status=400)=>out({error:s},status);
type C={s:number,n:number};type S={hands:C[][],trick:{seat:number,card:C}[],turn:number,lead:number,broken:boolean,round:number,points:number[],total:number[],history:any[],first:boolean,finished:boolean,winner:number|null};
const rank=(c:C)=>c.n===1?14:c.n;
const id=(c:C)=>c.s*13+c.n;
const hearts=(c:C)=>c.s===1;
const penalty=(c:C)=>hearts(c)?1:c.s===0&&c.n===12?13:0;
const deck=()=>{const a:C[]=[];for(let s=0;s<4;s++)for(let n=1;n<=13;n++)a.push({s,n});for(let i=51;i>0;i--){const v=new Uint32Array(1);crypto.getRandomValues(v);const j=v[0]%(i+1);[a[i],a[j]]=[a[j],a[i]]}return a};
const sort=(h:C[])=>h.sort((a,b)=>a.s-b.s||rank(a)-rank(b));
function deal(total=[0,0,0,0],round=1):S{
 const d=deck(),hands=[[],[],[],[]] as C[][];
 d.forEach((c,i)=>hands[i%4].push(c));hands.forEach(sort);
 const first=hands.findIndex(h=>h.some(c=>c.s===3&&c.n===2));
 return {hands,trick:[],turn:first,lead:first,broken:false,round,points:[0,0,0,0],total,history:[],first:true,finished:false,winner:null};
}
function legal(s:S,seat:number):C[]{
 if(seat!==s.turn||s.finished)return [];
 const hand=s.hands[seat];if(!hand.length)return [];
 if(s.first&&s.trick.length===0)return hand.filter(c=>c.s===3&&c.n===2);
 if(s.trick.length){
  const suit=s.trick[0].card.s,follow=hand.filter(c=>c.s===suit);
  if(follow.length)return follow;
  if(s.first){const clean=hand.filter(c=>!hearts(c)&&penalty(c)===0);if(clean.length)return clean}
  return hand;
 }
 if(!s.broken){const clean=hand.filter(c=>!hearts(c));if(clean.length)return clean}
 return hand;
}
function play(s:S,seat:number,card:C){
 if(!legal(s,seat).some(c=>id(c)===id(card)))throw Error('Niedozwolona karta');
 const hand=s.hands[seat],index=hand.findIndex(c=>id(c)===id(card));hand.splice(index,1);
 if(hearts(card))s.broken=true;
 s.trick.push({seat,card});
 if(s.trick.length<4){s.turn=(seat+1)%4;return}
 const suit=s.trick[0].card.s;
 const win=s.trick.filter(x=>x.card.s===suit).reduce((a,b)=>rank(b.card)>rank(a.card)?b:a);
 const points=s.trick.reduce((n,x)=>n+penalty(x.card),0);
 s.points[win.seat]+=points;
 s.history.push({cards:s.trick,winner:win.seat,points});
 s.trick=[];s.turn=win.seat;s.lead=win.seat;s.first=false;
 if(s.hands.every(h=>h.length===0)){
  const shooter=s.points.findIndex(p=>p===26);
  if(shooter>=0)s.points=s.points.map((_,i)=>i===shooter?0:26);
  s.total=s.total.map((t,i)=>t+s.points[i]);
  if(s.total.some(t=>t>=100)){
   s.finished=true;const best=Math.min(...s.total);s.winner=s.total.indexOf(best);
  }else{const next=deal(s.total,s.round+1);Object.assign(s,next)}
 }
}
function aiCard(s:S,seat:number):C{
 const opts=legal(s,seat);if(opts.length===1)return opts[0];
 if(s.trick.length){
  const suit=s.trick[0].card.s,follow=opts.filter(c=>c.s===suit);
  if(follow.length){
   const high=Math.max(...s.trick.filter(x=>x.card.s===suit).map(x=>rank(x.card)));
   const safe=follow.filter(c=>rank(c)<high);
   return sort(safe.length?safe:follow)[safe.length?safe.length-1:0];
  }
  return [...opts].sort((a,b)=>penalty(b)-penalty(a)||rank(b)-rank(a))[0];
 }
 return [...opts].sort((a,b)=>penalty(a)-penalty(b)||rank(a)-rank(b))[0];
}
function advance(s:S,seats:any[]){
 let n=0;while(!s.finished&&seats[s.turn].type==='ai'&&n<400){
  const c=aiCard(s,s.turn);play(s,s.turn,c);n++;
 }
 if(n>=400)throw Error('AI turn limit');
}
function view(room:any,user:string){
 const seats=room.seats as any[],seat=seats.findIndex(x=>x.id===user);
 if(seat<0)throw Error('Not a player');
 const s=room.state as S|null;
 return {id:room.id,mode:room.mode,status:room.status,version:room.version,seats:seats.map((x,i)=>({seat:i,name:x.name,type:x.type,ready:x.ready})),seat,
 state:s?{hand:s.hands[seat],counts:s.hands.map(x=>x.length),trick:s.trick,turn:s.turn,lead:s.lead,broken:s.broken,round:s.round,points:s.points,total:s.total,lastTrick:s.history.at(-1)||null,tricks:s.history.length,legal:legal(s,seat),finished:s.finished,winner:s.winner}:null};
}
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return bad('POST required',405);
 try{
  const token=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');
  if(!token)return bad('Zaloguj się',401);
  const url=Deno.env.get('SUPABASE_URL')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!;
  const admin=createClient(url,service,{auth:{persistSession:false}}),auth=createClient(url,anon,{auth:{persistSession:false}});
  const {data:{user},error:ae}=await auth.auth.getUser(token);
  if(ae||!user||user.is_anonymous)return bad('Zaloguj się na konto portalu',401);
  const body=await req.json(),action=body.action;
  if(!['create','invite','inbox','accept','decline','start','state','play'].includes(action))return bad('Invalid action');
  const name=(user.user_metadata?.handle||user.email?.split('@')[0]||'Gracz').toString().slice(0,32);
  if(action==='create'){
   const mode=body.mode;if(!['ai','multiplayer'].includes(mode))return bad('Invalid mode');
   const {count:recent}=await admin.from('agc_hearts_rooms').select('id',{count:'exact',head:true}).eq('host_id',user.id).gte('created_at',new Date(Date.now()-600000).toISOString());
   if((recent||0)>=8)return bad('Zbyt wiele nowych pokoi. Spróbuj później.',429);
   const seats=[{id:user.id,name,type:'human',ready:true},...Array.from({length:3},(_,i)=>({id:null,name:'AI '+(i+1),type:'ai',ready:true}))];
   const state=mode==='ai'?deal():null;if(state)advance(state,seats);
   const {data,error}=await admin.from('agc_hearts_rooms').insert({host_id:user.id,mode,seats,state,status:mode==='ai'?'playing':'lobby'}).select().single();if(error)throw error;
   return out({room:view(data,user.id)});
  }
  if(action==='inbox'){
   const {data,error}=await admin.from('agc_hearts_invites').select('id,room_id,sender_id,status,created_at').eq('recipient_id',user.id).eq('status','pending').order('created_at',{ascending:false}).limit(20);
   if(error)throw error;return out({invites:data});
  }
  const roomId=body.room;if(typeof roomId!=='string'||!/^[0-9a-f-]{36}$/i.test(roomId))return bad('Invalid room');
  const {data:room,error:re}=await admin.from('agc_hearts_rooms').select('*').eq('id',roomId).single();
  if(re||!room)return bad('Room unavailable',404);
  const seats=room.seats as any[];
  const seat=seats.findIndex(x=>x.id===user.id);
  if(action==='accept'||action==='decline'){
   const {data:inv}=await admin.from('agc_hearts_invites').select('*').eq('room_id',roomId).eq('recipient_id',user.id).eq('status','pending').maybeSingle();
   if(!inv||room.status!=='lobby')return bad('Invitation unavailable');
   if(action==='decline'){await admin.from('agc_hearts_invites').update({status:'declined'}).eq('id',inv.id).eq('status','pending');return out({declined:true})}
   if(seats[inv.seat]?.id&&seats[inv.seat].id!==user.id)return bad('Seat occupied');
   seats[inv.seat]={id:user.id,name,type:'human',ready:true};
   const {data:changed,error:ce}=await admin.from('agc_hearts_rooms').update({seats,version:room.version+1,updated_at:new Date().toISOString()}).eq('id',roomId).eq('version',room.version).select().maybeSingle();
   if(ce||!changed)return bad('Lobby changed; retry',409);
   await admin.from('agc_hearts_invites').update({status:'accepted'}).eq('id',inv.id).eq('status','pending');
   return out({room:view(changed,user.id)});
  }
  if(seat<0)return bad('Not a player',403);
  if(action==='state')return out({room:view(room,user.id)});
  if(action==='invite'){
   if(room.host_id!==user.id||room.mode!=='multiplayer'||room.status!=='lobby')return bad('Only lobby host can invite');
   const identity=String(body.identity||'').trim();if(identity.length<3||identity.length>254)return bad('Podaj nick lub e-mail');
   const {data:recipient,error:ie}=await admin.rpc('agc_hearts_resolve_invitee',{p_identity:identity});if(ie)throw ie;
   if(!recipient||recipient===user.id)return bad('Nie można zaprosić wskazanego gracza');
   if(seats.some(x=>x.id===recipient))return bad('Gracz jest już w pokoju');
   const {data:existing}=await admin.from('agc_hearts_invites').select('id,seat,status').eq('room_id',roomId).eq('recipient_id',recipient).maybeSingle();
   if(existing)return bad('Zaproszenie już wysłane');
   const {data:all}=await admin.from('agc_hearts_invites').select('seat').eq('room_id',roomId).in('status',['pending','accepted']);
   const taken=new Set((all||[]).map(x=>x.seat));
   const target=[1,2,3].find(i=>seats[i].type==='ai'&&!taken.has(i));
   if(target===undefined)return bad('Brak wolnych miejsc');
   const {error:inviteError}=await admin.from('agc_hearts_invites').insert({room_id:roomId,sender_id:user.id,recipient_id:recipient,seat:target});
   if(inviteError)throw inviteError;
   return out({invited:true,seat:target});
  }
  if(action==='start'){
   if(room.host_id!==user.id||room.status!=='lobby')return bad('Only host can start');
   const state=deal();advance(state,seats);
   const {data:changed,error:ce}=await admin.from('agc_hearts_rooms').update({state,status:'playing',version:room.version+1,updated_at:new Date().toISOString()}).eq('id',roomId).eq('version',room.version).select().maybeSingle();
   if(ce||!changed)return bad('Room changed; retry',409);
   await admin.from('agc_hearts_invites').update({status:'declined'}).eq('room_id',roomId).eq('status','pending');
   return out({room:view(changed,user.id)});
  }
  if(action==='play'){
   if(room.status!=='playing'||!room.state)return bad('Game not started');
   if(room.version!==body.version)return bad('Stale move, refresh',409);
   const card=body.card;
   if(!card||!Number.isInteger(card.s)||!Number.isInteger(card.n)||card.s<0||card.s>3||card.n<1||card.n>13)return bad('Invalid card');
   const state=room.state as S;
   if(state.turn!==seat)return bad('Nie Twoja kolej',409);
   play(state,seat,card);advance(state,seats);
   const status=state.finished?'finished':'playing';
   const {data:changed,error:ce}=await admin.from('agc_hearts_rooms').update({state,status,version:room.version+1,updated_at:new Date().toISOString()}).eq('id',roomId).eq('version',room.version).select().maybeSingle();
   if(ce||!changed)return bad('Ruch równoległy, odśwież',409);
   return out({room:view(changed,user.id)});
  }
  return bad('Unknown action');
 }catch(e){return bad('Błąd serwera: '+String(e),500)}
});
