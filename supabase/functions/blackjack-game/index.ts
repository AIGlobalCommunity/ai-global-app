import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.49.4';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,x-client-info,content-type','Content-Type':'application/json'};
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:cors});
const fail=(message:string,status=400)=>reply({error:message},status);
type Card={s:number,n:number};
type Player={departed?:boolean,guest_id?:string,id:string|null,name:string,type:'human'|'ai'};
type Round={phase?:'bet'|'play',deadline?:number,bets?:number[],misses?:number[],hands:Card[][],dealer:Card[],shoe:Card[],turn:number,done:boolean[],round:number,scores:number[],chips:number[],stake:number,last:any,finished:boolean,history:any[]};
const total=(cards:Card[])=>{let sum=0,aces=0;for(const c of cards){sum+=c.n===1?11:Math.min(10,c.n);if(c.n===1)aces++}while(sum>21&&aces){sum-=10;aces--}return sum};
const natural=(cards:Card[])=>cards.length===2&&total(cards)===21;
const shuffle=()=>{const cards:Card[]=[];for(let d=0;d<6;d++)for(let s=0;s<4;s++)for(let n=1;n<=13;n++)cards.push({s,n});for(let i=cards.length-1;i>0;i--){const b=new Uint32Array(1);crypto.getRandomValues(b);const j=b[0]%(i+1);[cards[i],cards[j]]=[cards[j],cards[i]]}return cards};
const take=(state:Round)=>{const c=state.shoe.pop();if(!c)throw Error('Brak kart w talii');return c};
function newRound(seats:Player[],scores?:number[],number=1,history:any[]=[],chips?:number[],stake=10):Round{
 const state:Round={hands:seats.map(()=>[]),dealer:[],shoe:shuffle(),turn:0,done:seats.map(()=>false),round:number,scores:scores??seats.map(()=>0),chips:chips??seats.map(()=>500),stake,last:null,finished:false,history};
 for(let j=0;j<2;j++){for(const hand of state.hands)hand.push(take(state));state.dealer.push(take(state))}
 state.done=state.hands.map((h,i)=>!!seats[i].departed||natural(h)||state.chips[i]<state.stake);
 return state;
}
function settle(s:Round,seats:Player[]){
 while(total(s.dealer)<17)s.dealer.push(take(s));
 const dealer=total(s.dealer),dNatural=natural(s.dealer);
 s.chips??=seats.map(()=>500);s.stake??=10;
 const results=s.hands.map((hand,i)=>{
  const value=total(hand),pNatural=natural(hand);
  let outcome='loss',award=0;
  const wager=s.bets?.[i]??s.stake;
  if(seats[i].departed||!wager||s.chips[i]<wager)return {seat:i,value,outcome:'skip',award:0,stake:0,delta:0};
  if(value>21)outcome='bust';
  else if(pNatural&&!dNatural){outcome='blackjack';award=300}
  else if(dNatural&&!pNatural)outcome='loss';
  else if(dealer>21||value>dealer){outcome='win';award=200}
  else if(value===dealer){outcome='push';award=100}
  s.scores[i]+=award;
  const stake=wager;
  const delta=outcome==='blackjack'?Math.floor(stake*1.5):outcome==='win'?stake:outcome==='push'?0:-stake;
  s.chips[i]+=delta;
  return {seat:i,value,outcome,award,stake,delta};
 });
 s.last={round:s.round,dealer:s.dealer,hands:s.hands,results};
 s.history.push(s.last);
 s.history=s.history.slice(-20);s.turn=-1;if(s.chips[0]<10)s.finished=true;
}
function advance(s:Round,seats:Player[]){
 let count=0;
 while(!s.finished&&count++<250){
  while(s.turn<seats.length&&s.done[s.turn])s.turn++;
  if(s.turn>=seats.length){settle(s,seats);return}
  const seat=s.turn;if(seats[seat].type==='human')return;
  const hand=s.hands[seat],value=total(hand),dealerUp=Math.min(10,s.dealer[0].n);
  const shouldHit=value<12||(value<17&&dealerUp>=7)||(value<17&&value<dealerUp+10);
  if(shouldHit){hand.push(take(s));if(total(hand)>=21)s.done[seat]=true}
  else s.done[seat]=true;
 }
 if(count>=250)throw Error('AI turn limit');
}
function betting(seats:Player[],previous?:Round):Round{
 const s=newRound(seats,previous?.scores,(previous?.round??0)+1,previous?.history,previous?.chips,10);
 s.phase='bet';s.deadline=Date.now()+20000;s.bets=seats.map((p,i)=>p.departed||s.chips[i]<10?0:-1);s.misses=previous?.misses??seats.map(()=>0);return s;
}
function tick(s:Round,seats:Player[],now:number){
 if(s.finished)return false;
 if(s.phase==='bet'&&(s.bets!.every(b=>b>=0)||now>=s.deadline!)){
  s.bets=s.bets!.map((b,i)=>{if(b<0){s.misses![i]++;return 0}return b});
  s.done=s.hands.map((h,i)=>!s.bets![i]||!!seats[i].departed||natural(h));s.phase='play';s.turn=0;advance(s,seats);s.deadline=now+30000;return true;
 }
 if(s.phase==='play'&&s.turn>=0&&now>=s.deadline!){s.misses![s.turn]++;s.done[s.turn]=true;advance(s,seats);s.deadline=now+30000;return true}
 return false;
}
function view(room:any,user:string){
 const seats=room.seats as Player[],seat=seats.findIndex(p=>p.id===user||p.guest_id===user);
 if(seat<0)throw Error('Brak dostępu do pokoju');
 const s=room.state as Round|null;
 return {id:room.id,mode:room.mode,status:room.status,version:room.version,seat,
 seats:seats.map((p,i)=>({seat:i,name:p.name,type:p.type,departed:!!p.departed,ready:!!(p.id||p.guest_id||p.type==='ai')})),
 state:s?{phase:s.phase,deadline:s.deadline,serverNow:Date.now(),bets:s.bets,round:s.round,turn:s.turn,hand:s.phase==='bet'?[]:s.hands[seat],myTotal:s.phase==='bet'?0:total(s.hands[seat]),dealerUp:s.phase==='bet'?null:s.dealer[0],dealerCards:s.finished||s.turn===-1?s.dealer:null,counts:s.hands.map(h=>h.length),values:s.hands.map((h,i)=>i===seat||s.done[i]||s.finished?total(h):null),done:s.done,scores:s.scores,chips:s.chips,stake:s.stake,last:s.last,finished:s.finished,canAct:s.phase!=='bet'&&!s.finished&&s.turn===seat&&!s.done[seat],canNext:!s.finished&&s.turn===-1&&seat===0,history:s.finished?s.history:undefined}:null};
}
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return fail('POST required',405);
 try{
  const jwt=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');

  const url=Deno.env.get('SUPABASE_URL')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!;
  const admin=createClient(url,service,{auth:{persistSession:false}}),auth=createClient(url,anon,{auth:{persistSession:false}});
  const body=await req.json(),action=body.action;
  let user:any=jwt?(await auth.auth.getUser(jwt)).data.user:null;
  if(!user){
   if(!['state','hit','stand','leave','bet'].includes(action)||typeof body.session!=='string'||!/^[a-f0-9]{64}$/.test(body.session))return fail('Wymagane konto lub sesja gościa',401);
   const h=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(body.session))),x=>x.toString(16).padStart(2,'0')).join('');
   const {data:g}=await admin.from('agc_game_guest_sessions').select('id,nickname,invite_id').eq('session_hash',h).eq('revoked',false).gt('expires_at',new Date().toISOString()).maybeSingle();
   if(!g)return fail('Sesja wygasła',401);
   const {data:i}=await admin.from('agc_game_invite_links').select('game,room_id').eq('id',g.invite_id).single();
   if(i?.game!=='blackjack'||i.room_id!==body.room)return fail('Brak dostępu',403);
   user={id:g.id,user_metadata:{handle:g.nickname}};
  }
  if(!['create','inbox','invite','accept','decline','start','state','hit','stand','next','finish','leave','close','bet'].includes(action))return fail('Nieznana operacja');
  const displayName=String(user.user_metadata?.handle||user.email?.split('@')[0]||'Gracz').slice(0,32);
  if(action==='create'){
   if(user.is_anonymous)return fail('Użyj wspólnego tworzenia pokoju gościa',401);
   if(!['ai','multiplayer'].includes(body.mode))return fail('Nieprawidłowy tryb');
   const {count:recentRooms}=await admin.from('agc_blackjack_rooms').select('id',{count:'exact',head:true}).eq('host_id',user.id).gte('created_at',new Date(Date.now()-600000).toISOString());
   if((recentRooms||0)>=8)return fail('Zbyt wiele pokoi. Spróbuj później.',429);
   const count=Number(body.players);
   const stake=Number(body.stake);
   if(![10,25,50,100].includes(stake))return fail('Wybierz stawkę punktową: 10, 25, 50 lub 100');
   if(!Number.isInteger(count)||count<1||count>10)return fail('Wybierz od 1 do 10 uczestników');
   const seats:Player[]=[{id:user.id,name:displayName,type:'human'},...Array.from({length:count},(_,i)=>body.mode==='ai'?({id:null,name:'AI '+(i+1),type:'ai' as const}):({id:null,name:'Oczekiwanie '+(i+1),type:'human' as const}))];
   const state=body.mode==='ai'?newRound(seats,undefined,1,[],undefined,stake):null;if(state)advance(state,seats);
   const {data,error}=await admin.from('agc_blackjack_rooms').insert({host_id:user.id,mode:body.mode,seats,state,status:state?'playing':'lobby',stake}).select().single();
   if(error)throw error;return reply({room:view(data,user.id)});
  }
  if(action==='inbox'){
   const {data,error}=await admin.from('agc_blackjack_invites').select('id,room_id,created_at').eq('recipient_id',user.id).eq('status','pending').order('created_at',{ascending:false}).limit(30);
   if(error)throw error;return reply({invites:data});
  }
  const roomId=body.room;if(typeof roomId!=='string'||!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(roomId))return fail('Nieprawidłowy identyfikator pokoju');
  const {data:room,error:roomError}=await admin.from('agc_blackjack_rooms').select('*').eq('id',roomId).single();
  if(roomError||!room)return fail('Pokój niedostępny',404);
  if(room.guest_host&&room.host_id===user.id&&!user.is_anonymous)return fail('Sesja gospodarza nie jest anonimowa',403);
  if(!room.guest_host&&user.is_anonymous)return fail('Sesja gościa nie jest gospodarzem',403);
  const seats=room.seats as Player[],seat=seats.findIndex(p=>p.id===user.id||p.guest_id===user.id);
  if(action==='accept'||action==='decline'){
   const {data:inv}=await admin.from('agc_blackjack_invites').select('*').eq('room_id',roomId).eq('recipient_id',user.id).eq('status','pending').maybeSingle();
   if(!inv||room.status!=='lobby')return fail('Zaproszenie jest już nieaktualne');
   if(action==='decline'){await admin.from('agc_blackjack_invites').update({status:'declined'}).eq('id',inv.id).eq('status','pending');return reply({declined:true})}
   if(seats[inv.seat]?.departed||seats[inv.seat]?.guest_id)return fail('Miejsce zajęte');
   if(seats[inv.seat]?.id&&seats[inv.seat].id!==user.id)return fail('Miejsce zajęte');
   seats[inv.seat]={id:user.id,name:displayName,type:'human'};
   const {data:changed,error:ce}=await admin.from('agc_blackjack_rooms').update({seats,version:room.version+1,updated_at:new Date().toISOString()}).eq('id',roomId).eq('version',room.version).select().maybeSingle();
   if(ce||!changed)return fail('Pokój zmieniony, spróbuj ponownie',409);
   await admin.from('agc_blackjack_invites').update({status:'accepted'}).eq('id',inv.id).eq('status','pending');
   return reply({room:view(changed,user.id)});
  }
  if(seat<0)return fail('Nie jesteś uczestnikiem tego pokoju',403);
  if(room.guest_host&&room.status!=='finished'&&Date.now()-Date.parse(room.updated_at||room.created_at)>60000){
   await admin.from('agc_blackjack_rooms').update({updated_at:new Date().toISOString()}).eq('id',room.id);
  }
  if(room.status==='playing'&&room.state?.phase&&['state','bet','hit','stand'].includes(action)){
   const s=room.state as Round;
   let changed=tick(s,seats,Date.now());
   if(!changed&&action==='bet'){
    const b=Number(body.stake);if(s.phase!=='bet'||s.bets![seat]!==-1||![10,25,50,100].includes(b)||b>s.chips[seat])return fail('Stawka niedostępna');
    s.bets![seat]=b;s.misses![seat]=0;changed=true;tick(s,seats,Date.now());
   }
   if(changed){const {data:x,error}=await admin.from('agc_blackjack_rooms').update({state:s,status:s.finished?'finished':'playing',version:room.version+1,updated_at:new Date().toISOString()}).eq('id',roomId).eq('version',room.version).select().maybeSingle();if(error||!x)return fail('Pokój zmieniony, odśwież',409);return reply({room:view(x,user.id)});}
  }
  if(action==='state')return reply({room:view(room,user.id)});
  if(action==='close'){
   if(room.host_id!==user.id)return fail('Tylko gospodarz może zamknąć pokój',403);
   const {data:removed,error}=await admin.from('agc_blackjack_rooms').delete().eq('id',roomId).eq('version',room.version).select('id').maybeSingle();
   if(error||!removed)return fail('Pokój zmieniony, spróbuj ponownie',409);
   await admin.from('agc_game_invite_links').update({revoked:true}).eq('game','blackjack').eq('room_id',roomId);
   return reply({closed:true});
  }
  if(action==='leave'){
   if(seat===0)return fail('Gospodarz musi zamknąć pokój',403);
   const departed=seats[seat];const guestId=departed.guest_id;
   seats[seat]={id:null,name:departed.name,type:'human',departed:true};
   const state=room.state as Round|null;
   if(state&&room.status==='playing'){state.done[seat]=true;if(state.phase==='bet'){state.bets![seat]=0;tick(state,seats,Date.now())}else if(state.turn===seat){advance(state,seats);state.deadline=Date.now()+30000;}}
   const {data:changed,error}=await admin.from('agc_blackjack_rooms').update({seats,state,status:state?.finished?'finished':room.status,version:room.version+1,updated_at:new Date().toISOString()}).eq('id',roomId).eq('version',room.version).select('id').maybeSingle();
   if(error||!changed)return fail('Pokój zmieniony, spróbuj ponownie',409);
   if(guestId)await admin.from('agc_game_guest_sessions').update({revoked:true}).eq('id',guestId);
   return reply({left:true});
  }
  if(action==='invite'){
   if(room.host_id!==user.id||room.mode!=='multiplayer'||room.status!=='lobby')return fail('Tylko gospodarz może zapraszać przed rozpoczęciem');
   if(user.is_anonymous)return fail('Do zapraszania po nicku lub e-mailu wymagane jest konto. Użyj QR.',403);
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
   const target=Array.from({length:seats.length-1},(_,i)=>i+1).find(i=>!seats[i].departed&&!seats[i].id&&!seats[i].guest_id&&!taken.has(i));
   if(target===undefined)return fail('Wszystkie wybrane miejsca są zajęte lub zaproszone');
   const {error:insertError}=await admin.from('agc_blackjack_invites').insert({room_id:roomId,sender_id:user.id,recipient_id:recipient,seat:target});
   if(insertError)throw insertError;
   return reply({invited:true,seat:target});
  }
  if(action==='start'){
   if(room.host_id!==user.id||room.status!=='lobby')return fail('Tylko gospodarz może rozpocząć grę');
   const activeSeats=seats.filter(p=>p.id||p.guest_id||p.type==='ai');
   if(activeSeats.length<2)return fail('Poczekaj na przynajmniej jednego gracza.');
   const state=betting(activeSeats);
   const {data:changed,error:ce}=await admin.from('agc_blackjack_rooms').update({seats:activeSeats,state,status:'playing',version:room.version+1,updated_at:new Date().toISOString()}).eq('id',roomId).eq('version',room.version).select().maybeSingle();
   if(ce||!changed)return fail('Pokój został zmieniony, odśwież',409);
   await admin.from('agc_blackjack_invites').update({status:'declined'}).eq('room_id',roomId).eq('status','pending');
   return reply({room:view(changed,user.id)});
  }
  if(action==='hit'||action==='stand'||action==='next'||action==='finish'){
   if(room.status!=='playing'||!room.state)return fail('Gra nie jest aktywna');
   if(body.version!==room.version)return fail('Stan gry jest nieaktualny, odśwież',409);
   let state=room.state as Round;
   if(action==='next'||action==='finish'){
    if(seat!==0||state.turn!==-1||state.finished)return fail('Najpierw zakończ rozdanie',409);
    if(action==='finish'){state.finished=true;}else{const stake=Number(body.stake);if(![10,25,50,100].includes(stake)||stake>(state.chips?.[0]??500))return fail('Wybierz stawkę dostępną w saldzie');if(room.mode==='multiplayer'){state=betting(seats,state)}else{state=newRound(seats,state.scores,state.round+1,state.history,state.chips,stake);advance(state,seats);}}
   }else{
   if(state.phase==='bet'||state.turn!==seat||state.done[seat])return fail('Nie Twoja kolej',409);
   if(action==='hit'){
    state.hands[seat].push(take(state));
    if(total(state.hands[seat])>=21)state.done[seat]=true;
   }else state.done[seat]=true;
   advance(state,seats);if(state.phase==='play'){state.deadline=Date.now()+30000;state.misses![seat]=0;}
   }
   const status=state.finished?'finished':'playing';
   const {data:changed,error:ce}=await admin.from('agc_blackjack_rooms').update({state,status,version:room.version+1,updated_at:new Date().toISOString()}).eq('id',roomId).eq('version',room.version).select().maybeSingle();
   if(ce||!changed)return fail('Równoczesny ruch. Odśwież i spróbuj ponownie',409);
   return reply({room:view(changed,user.id)});
  }
  return fail('Nieznana operacja');
 }catch(e){return fail('Błąd serwera: '+String(e),500)}
});
