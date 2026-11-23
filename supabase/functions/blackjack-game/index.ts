import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.49.4';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,x-client-info,content-type','Content-Type':'application/json'};
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:cors});
const fail=(message:string,status=400)=>reply({error:message},status);
type Card={s:number,n:number};
type Player={id:string|null,name:string,type:'human'|'ai'};
type Round={hands:Card[][],dealer:Card[],shoe:Card[],turn:number,done:boolean[],round:number,scores:number[],last:any,finished:boolean,history:any[]};
const total=(cards:Card[])=>{let sum=0,aces=0;for(const c of cards){sum+=c.n===1?11:Math.min(10,c.n);if(c.n===1)aces++}while(sum>21&&aces){sum-=10;aces--}return sum};
const natural=(cards:Card[])=>cards.length===2&&total(cards)===21;
const shuffle=()=>{const cards:Card[]=[];for(let d=0;d<6;d++)for(let s=0;s<4;s++)for(let n=1;n<=13;n++)cards.push({s,n});for(let i=cards.length-1;i>0;i--){const b=new Uint32Array(1);crypto.getRandomValues(b);const j=b[0]%(i+1);[cards[i],cards[j]]=[cards[j],cards[i]]}return cards};
const take=(state:Round)=>{const c=state.shoe.pop();if(!c)throw Error('Brak kart w talii');return c};
function newRound(seats:Player[],scores?:number[],number=1,history:any[]=[]):Round{
 const state:Round={hands:seats.map(()=>[]),dealer:[],shoe:shuffle(),turn:0,done:seats.map(()=>false),round:number,scores:scores??seats.map(()=>0),last:null,finished:false,history};
 for(let j=0;j<2;j++){for(const hand of state.hands)hand.push(take(state));state.dealer.push(take(state))}
 state.done=state.hands.map(natural);
 return state;
}
function settle(s:Round,seats:Player[]){
 while(total(s.dealer)<17)s.dealer.push(take(s));
 const dealer=total(s.dealer),dNatural=natural(s.dealer);
 const results=s.hands.map((hand,i)=>{
  const value=total(hand),pNatural=natural(hand);
  let outcome='loss',award=0;
  if(value>21)outcome='bust';
  else if(pNatural&&!dNatural){outcome='blackjack';award=300}
  else if(dNatural&&!pNatural)outcome='loss';
  else if(dealer>21||value>dealer){outcome='win';award=200}
  else if(value===dealer){outcome='push';award=100}
  s.scores[i]+=award;
  return {seat:i,value,outcome,award};
 });
 s.last={round:s.round,dealer:s.dealer,results};
 s.history.push(s.last);
 if(s.round>=5){s.finished=true;s.turn=-1;return}
 const next=newRound(seats,s.scores,s.round+1,s.history);Object.assign(s,next);
}
function advance(s:Round,seats:Player[]){
 let count=0;
 while(!s.finished&&count++<250){
  while(s.turn<seats.length&&s.done[s.turn])s.turn++;
  if(s.turn>=seats.length){settle(s,seats);continue}
  const seat=s.turn;if(seats[seat].type==='human')return;
  const hand=s.hands[seat],value=total(hand),dealerUp=Math.min(10,s.dealer[0].n);
  const shouldHit=value<12||(value<17&&dealerUp>=7)||(value<17&&value<dealerUp+10);
  if(shouldHit){hand.push(take(s));if(total(hand)>=21)s.done[seat]=true}
  else s.done[seat]=true;
 }
 if(count>=250)throw Error('AI turn limit');
}
function view(room:any,user:string){
 const seats=room.seats as Player[],seat=seats.findIndex(p=>p.id===user);
 if(seat<0)throw Error('Brak dostępu do pokoju');
 const s=room.state as Round|null;
 return {id:room.id,mode:room.mode,status:room.status,version:room.version,seat,
 seats:seats.map((p,i)=>({seat:i,name:p.name,type:p.type,ready:true})),
 state:s?{round:s.round,turn:s.turn,hand:s.hands[seat],myTotal:total(s.hands[seat]),dealerUp:s.dealer[0],dealerCards:s.finished?s.dealer:null,counts:s.hands.map(h=>h.length),values:s.hands.map((h,i)=>i===seat||s.done[i]||s.finished?total(h):null),done:s.done,scores:s.scores,last:s.last,finished:s.finished,canAct:!s.finished&&s.turn===seat&&!s.done[seat],history:s.finished?s.history:undefined}:null};
}
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return fail('POST required',405);
 try{
  const jwt=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');
  if(!jwt)return fail('Zaloguj się na portalu',401);
  const url=Deno.env.get('SUPABASE_URL')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!;
  const admin=createClient(url,service,{auth:{persistSession:false}}),auth=createClient(url,anon,{auth:{persistSession:false}});
  const {data:{user},error:authError}=await auth.auth.getUser(jwt);
  if(authError||!user||user.is_anonymous)return fail('Wymagane zalogowane konto portalu',401);
  const body=await req.json(),action=body.action;
  if(!['create','inbox','invite','accept','decline','start','state','hit','stand'].includes(action))return fail('Nieznana operacja');
  const displayName=String(user.user_metadata?.handle||user.email?.split('@')[0]||'Gracz').slice(0,32);
  if(action==='create'){
   if(!['ai','multiplayer'].includes(body.mode))return fail('Nieprawidłowy tryb');
   const {count}=await admin.from('agc_blackjack_rooms').select('id',{count:'exact',head:true}).eq('host_id',user.id).gte('created_at',new Date(Date.now()-600000).toISOString());
   if((count||0)>=8)return fail('Zbyt wiele pokoi. Spróbuj później.',429);
   const count=Number(body.players);
   if(!Number.isInteger(count)||count<1||count>10)return fail('Wybierz od 1 do 10 uczestników');
   const seats:Player[]=[{id:user.id,name:displayName,type:'human'},...Array.from({length:count},(_,i)=>body.mode==='ai'?({id:null,name:'AI '+(i+1),type:'ai' as const}):({id:null,name:'Oczekiwanie '+(i+1),type:'human' as const}))];
   const state=body.mode==='ai'?newRound(seats):null;if(state)advance(state,seats);
   const {data,error}=await admin.from('agc_blackjack_rooms').insert({host_id:user.id,mode:body.mode,seats,state,status:state?'playing':'lobby'}).select().single();
   if(error)throw error;return reply({room:view(data,user.id)});
  }
  if(action==='inbox'){
   const {data,error}=await admin.from('agc_blackjack_invites').select('id,room_id,created_at').eq('recipient_id',user.id).eq('status','pending').order('created_at',{ascending:false}).limit(30);
   if(error)throw error;return reply({invites:data});
  }
  const roomId=body.room;if(typeof roomId!=='string'||!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(roomId))return fail('Nieprawidłowy identyfikator pokoju');
  const {data:room,error:roomError}=await admin.from('agc_blackjack_rooms').select('*').eq('id',roomId).single();
  if(roomError||!room)return fail('Pokój niedostępny',404);
  const seats=room.seats as Player[],seat=seats.findIndex(p=>p.id===user.id);
  if(action==='accept'||action==='decline'){
   const {data:inv}=await admin.from('agc_blackjack_invites').select('*').eq('room_id',roomId).eq('recipient_id',user.id).eq('status','pending').maybeSingle();
   if(!inv||room.status!=='lobby')return fail('Zaproszenie jest już nieaktualne');
   if(action==='decline'){await admin.from('agc_blackjack_invites').update({status:'declined'}).eq('id',inv.id).eq('status','pending');return reply({declined:true})}
   if(seats[inv.seat]?.id&&seats[inv.seat].id!==user.id)return fail('Miejsce zajęte');
   seats[inv.seat]={id:user.id,name:displayName,type:'human'};
   const {data:changed,error:ce}=await admin.from('agc_blackjack_rooms').update({seats,version:room.version+1,updated_at:new Date().toISOString()}).eq('id',roomId).eq('version',room.version).select().maybeSingle();
   if(ce||!changed)return fail('Pokój zmieniony, spróbuj ponownie',409);
   await admin.from('agc_blackjack_invites').update({status:'accepted'}).eq('id',inv.id).eq('status','pending');
   return reply({room:view(changed,user.id)});
  }
  if(seat<0)return fail('Nie jesteś uczestnikiem tego pokoju',403);
  if(action==='state')return reply({room:view(room,user.id)});
  if(action==='invite'){
   if(room.host_id!==user.id||room.mode!=='multiplayer'||room.status!=='lobby')return fail('Tylko gospodarz może zapraszać przed rozpoczęciem');
   const identity=String(body.identity||'').trim();
   if(identity.length<3||identity.length>254)return fail('Podaj nick lub e-mail');
   const {data:recipient,error:ie}=await admin.rpc('agc_hearts_resolve_invitee',{p_identity:identity});
   if(ie)throw ie;
   if(!recipient||recipient===user.id)return fail('Nie znaleziono gracza lub nie można zaprosić samego siebie');
   if(seats.some(p=>p.id===recipient))return fail('Gracz jest już w pokoju');
   const {data:existing}=await admin.from('agc_blackjack_invites').select('id').eq('room_id',roomId).eq('recipient_id',recipient).maybeSingle();
   if(existing)return fail('Zaproszenie zostało już wysłane');
   const {data:pending}=await admin.from('agc_blackjack_invites').select('seat').eq('room_id',roomId).in('status',['pending','accepted']);
   const taken=new Set((pending||[]).map(p=>p.seat));
   const target=Array.from({length:seats.length-1},(_,i)=>i+1).find(i=>!seats[i].id&&!taken.has(i));
   if(target===undefined)return fail('Wszystkie wybrane miejsca są zajęte lub zaproszone');
   const {error:insertError}=await admin.from('agc_blackjack_invites').insert({room_id:roomId,sender_id:user.id,recipient_id:recipient,seat:target});
   if(insertError)throw insertError;
   return reply({invited:true,seat:target});
  }
  if(action==='start'){
   if(room.host_id!==user.id||room.status!=='lobby')return fail('Tylko gospodarz może rozpocząć grę');
   if(seats.slice(1).some(p=>!p.id))return fail('Poczekaj, aż wszyscy zaproszeni gracze dołączą.');
   const state=newRound(seats);advance(state,seats);
   const {data:changed,error:ce}=await admin.from('agc_blackjack_rooms').update({state,status:'playing',version:room.version+1,updated_at:new Date().toISOString()}).eq('id',roomId).eq('version',room.version).select().maybeSingle();
   if(ce||!changed)return fail('Pokój został zmieniony, odśwież',409);
   await admin.from('agc_blackjack_invites').update({status:'declined'}).eq('room_id',roomId).eq('status','pending');
   return reply({room:view(changed,user.id)});
  }
  if(action==='hit'||action==='stand'){
   if(room.status!=='playing'||!room.state)return fail('Gra nie jest aktywna');
   if(body.version!==room.version)return fail('Stan gry jest nieaktualny, odśwież',409);
   const state=room.state as Round;
   if(state.turn!==seat||state.done[seat])return fail('Nie Twoja kolej',409);
   if(action==='hit'){
    state.hands[seat].push(take(state));
    if(total(state.hands[seat])>=21)state.done[seat]=true;
   }else state.done[seat]=true;
   advance(state,seats);
   const status=state.finished?'finished':'playing';
   const {data:changed,error:ce}=await admin.from('agc_blackjack_rooms').update({state,status,version:room.version+1,updated_at:new Date().toISOString()}).eq('id',roomId).eq('version',room.version).select().maybeSingle();
   if(ce||!changed)return fail('Równoczesny ruch. Odśwież i spróbuj ponownie',409);
   return reply({room:view(changed,user.id)});
  }
  return fail('Nieznana operacja');
 }catch(e){return fail('Błąd serwera: '+String(e),500)}
});
