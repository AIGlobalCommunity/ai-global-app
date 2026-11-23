import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, x-client-info, content-type'};
const fail=(s:string,n=400)=>new Response(JSON.stringify({error:s}),{status:n,headers:{...cors,'Content-Type':'application/json'}});
const ok=(v:unknown)=>new Response(JSON.stringify(v),{headers:{...cors,'Content-Type':'application/json'}});
type Card={s:number,n:number,up?:boolean};
const copy=<T>(x:T):T=>JSON.parse(JSON.stringify(x));
const isRed=(s:number)=>s===1||s===2;
function initial(game:string,mode:number,deck:Card[]){
 if(game==='freecell'){const p=Array.from({length:8},()=>[] as Card[]);deck.forEach((c,i)=>p[i%8].push(c));return {p,cells:[null,null,null,null] as (Card|null)[],homes:Array.from({length:4},()=>[] as Card[])}}
 if(game==='solitaire'){const p=Array.from({length:7},()=>[] as Card[]);let k=0;for(let i=0;i<7;i++)for(let j=0;j<=i;j++){const c={...deck[k++],up:j===i};p[i].push(c)}return {p,stock:deck.slice(k).map(c=>({...c,up:false})),waste:[] as Card[],homes:Array.from({length:4},()=>[] as Card[])}}
 const p=Array.from({length:10},()=>[] as Card[]);let k=0;for(let i=0;i<10;i++)for(let j=0;j<(i<4?6:5);j++)p[i].push({...deck[k++],up:j===(i<4?5:4)});return {p,stock:deck.slice(k).map(c=>({...c,up:false})),done:[] as number[]};
}
function replay(game:string,mode:number,deck:Card[],actions:any[]){
 let st:any=initial(game,mode,deck), history:any[]=[], moves=0;
 if(!Array.isArray(actions)||actions.length>12000||actions.length<1)throw Error('Invalid action log');
 const zone=(z:string,i:number)=>z==='t'?st.p[i]:z==='c'?[st.cells[i]].filter(Boolean):z==='f'?st.homes[i]:z==='w'?st.waste:null;
 for(const a of actions){
  if(!a||typeof a!=='object'||!['m','d','u'].includes(a.t))throw Error('Bad action');
  if(a.t==='u'){if(!history.length)throw Error('Undo without history');st=history.pop();moves++;continue}
  if(a.t==='d'){
   if(game==='freecell')throw Error('FreeCell cannot deal');
   if(game==='spider'){if(st.stock.length<10||st.p.some((p:Card[])=>p.length===0))throw Error('Illegal Spider deal');history.push(copy(st));for(let i=0;i<10;i++)st.p[i].push({...st.stock.pop(),up:true})}
   else {if(!st.stock.length&&!st.waste.length)throw Error('Empty stock');history.push(copy(st));if(st.stock.length){for(let k=0;k<mode&&st.stock.length;k++)st.waste.push({...st.stock.pop(),up:true})}else{st.stock=st.waste.reverse().map((c:Card)=>({...c,up:false}));st.waste=[]}}
  }else{
   const z=a.z,q=a.q,si=a.i,di=a.k,j=a.j;
   if(!['t','c','f','w'].includes(z)||!['t','c','f'].includes(q)||![si,di,j].every(v=>Number.isInteger(v)&&v>=0&&v<200))throw Error('Invalid move coordinates');
   if((z==='t'&&si>=st.p.length)||(q==='t'&&di>=st.p.length)||(z==='c'&&si>=4)||(q==='c'&&di>=4)||(z==='f'&&si>=4)||(q==='f'&&di>=4))throw Error('Invalid column');
   if(game==='solitaire'&&(z==='c'||q==='c'))throw Error('Invalid solitaire zone');
   if(game==='freecell'&&z==='w')throw Error('Invalid freecell zone');
   if(game==='spider'&&(z!=='t'||q!=='t'))throw Error('Invalid spider zone');
   if(z===q&&si===di)throw Error('Self move');
   const from=zone(z,si),to=zone(q,di);
   if(!from||!to||!from.length||j>=from.length)throw Error('Empty source');
   const batch=z==='t'?from.slice(j):from.slice(-1);
   if(z!=='t'&&j!==from.length-1)throw Error('Invalid source offset');
   if(game==='spider'||game==='solitaire'){
    if(batch.some((c:Card)=>!c.up))throw Error('Face-down move');
    for(let i=1;i<batch.length;i++)if(batch[i-1].n!==batch[i].n+1||(game==='spider'?batch[i-1].s!==batch[i].s:isRed(batch[i-1].s)===isRed(batch[i].s)))throw Error('Invalid sequence');
   }else{for(let i=1;i<batch.length;i++)if(batch[i-1].n!==batch[i].n+1||isRed(batch[i-1].s)===isRed(batch[i].s))throw Error('Invalid sequence')}
   const first=batch[0];
   if(q==='f'){if(batch.length!==1||first.s!==di||first.n!==to.length+1)throw Error('Invalid foundation')}
   else if(q==='c'){if(batch.length!==1||st.cells[di])throw Error('Occupied cell')}
   else {
    if(game==='solitaire'){if(to.length?to.at(-1).n!==first.n+1||isRed(to.at(-1).s)===isRed(first.s):first.n!==13)throw Error('Invalid Klondike placement')}
    else if(to.length&&to.at(-1).n!==first.n+1)throw Error('Invalid placement');
    if(game==='freecell'){
      if(to.length&&isRed(to.at(-1).s)===isRed(first.s))throw Error('Same color');
      let empty=st.p.filter((p:Card[])=>p.length===0).length-(to.length===0?1:0);
      let free=st.cells.filter((c:Card|null)=>!c).length;
      if(batch.length>(free+1)*Math.pow(2,Math.max(0,empty)))throw Error('Too many cards');
    }
   }
   history.push(copy(st));
   if(z==='t'){from.splice(j);if(game!=='freecell'&&from.length&&!from.at(-1).up)from.at(-1).up=true}
   else if(z==='c')st.cells[si]=null;
   else from.pop();
   if(q==='c')st.cells[di]=batch[0];else to.push(...batch);
  }
  moves++;
  if(game==='spider'){
   let again=true;while(again){again=false;for(const p of st.p){if(p.length<13)continue;const seq=p.slice(-13);if(seq.every((c:Card,i:number)=>c.up&&c.s===seq[0].s&&c.n===13-i)){p.splice(-13);st.done.push(seq[0].s);if(p.length&&!p.at(-1).up)p.at(-1).up=true;again=true}}}
  }
 }
 const win=game==='spider'?st.done.length===8:st.homes.every((p:Card[])=>p.length===13);
 if(!win)throw Error('Game not completed');
 return moves;
}
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return fail('POST required',405);
 try{
 const token=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');
 if(!token)return fail('Sign in required',401);
 const url=Deno.env.get('SUPABASE_URL')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!;
 const admin=createClient(url,service,{auth:{persistSession:false}});
 const authClient=createClient(url,anon,{auth:{persistSession:false}});
 const {data:{user},error:authError}=await authClient.auth.getUser(token);
 if(authError||!user||user.is_anonymous)return fail('Verified account required',401);
 const body=await req.json(),game=body.game,action=body.action;
 if(!['solitaire','freecell','spider'].includes(game))return fail('Unsupported game');
 if(action==='begin'){
  const mode=Number(body.mode);
  if(!Number.isInteger(mode)||(game==='solitaire'?![1,3].includes(mode):game==='freecell'?mode!==1:![1,2,4].includes(mode)))return fail('Invalid mode');
  const {count}=await admin.from('agc_card_runs').select('id',{count:'exact',head:true}).eq('member_id',user.id).eq('status','active').gte('started_at',new Date(Date.now()-60000).toISOString());
  if((count||0)>=8)return fail('Too many new games',429);
  let deck:Card[]=[];if(game==='spider'){const suits=mode===1?[0]:mode===2?[0,1]:[0,1,2,3];for(let i=0;i<104;i++)deck.push({n:i%13+1,s:suits[Math.floor(i/13)%suits.length]})}else for(let s=0;s<4;s++)for(let n=1;n<=13;n++)deck.push({s,n});
  for(let i=deck.length-1;i>0;i--){const rnd=new Uint32Array(1);crypto.getRandomValues(rnd);const j=rnd[0]%(i+1);[deck[i],deck[j]]=[deck[j],deck[i]]}
  const {data,error}=await admin.from('agc_card_runs').insert({member_id:user.id,game_key:game,mode,deck}).select('id').single();if(error)throw error;
  return ok({run:data.id,deck,mode});
 }
 if(action==='finish'){
  const run=body.run,actions=body.actions;
  if(typeof run!=='string'||run.length!==36||!Array.isArray(actions))return fail('Invalid run');
  const {data,error}=await admin.from('agc_card_runs').select('*').eq('id',run).eq('member_id',user.id).eq('game_key',game).eq('status','active').single();
  if(error||!data)return fail('Run missing or already submitted');
  const elapsed=Math.floor((Date.now()-new Date(data.started_at).getTime())/1000);
  if(elapsed<20||elapsed>14400)return fail('Invalid session duration');
  let moves:number;try{moves=replay(game,data.mode,data.deck,actions)}catch(e){await admin.from('agc_card_runs').update({status:'rejected',finished_at:new Date().toISOString()}).eq('id',run);return fail('Replay rejected: '+String(e)) }
  const score=Math.max(10,10000+(game==='spider'?data.mode*2000:0)-moves*3-elapsed);
  const {error:updateError}=await admin.from('agc_card_runs').update({status:'verified',verified_score:score,finished_at:new Date().toISOString()}).eq('id',run).eq('status','active');if(updateError)throw updateError;
  const {data:existing}=await admin.from('agc_game_scores').select('best_score').eq('member_id',user.id).eq('game_key',game).maybeSingle();
  if(!existing||existing.best_score<score)await admin.from('agc_game_scores').upsert({member_id:user.id,game_key:game,best_score:score,best_level:data.mode,updated_at:new Date().toISOString()},{onConflict:'member_id,game_key'});
  const day=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Warsaw',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const {data:daily}=await admin.from('agc_daily_scores').select('best_score').eq('member_id',user.id).eq('game_key',game).eq('score_day',day).maybeSingle();
  if(!daily||daily.best_score<score)await admin.from('agc_daily_scores').upsert({member_id:user.id,game_key:game,score_day:day,best_score:score},{onConflict:'member_id,game_key,score_day'});
  await admin.from('agc_card_score_verification').insert({member_id:user.id,game_key:game,claimed_score:score,claimed_level:data.mode,verification_status:'verified',verified_at:new Date().toISOString(),verifier_note:'Server deck and complete move replay '+run});
  const {data:verified}=await admin.from('agc_verified_daily_scores').select('best_score').eq('member_id',user.id).eq('game_key',game).eq('score_day',day).maybeSingle();
  if(!verified||verified.best_score<score)await admin.from('agc_verified_daily_scores').upsert({member_id:user.id,game_key:game,score_day:day,best_score:score,verified_at:new Date().toISOString(),evidence_ref:'card-run:'+run},{onConflict:'member_id,game_key,score_day'});
  return ok({verified:true,score,moves,seconds:elapsed,run});
 }
 return fail('Invalid action');
 }catch(e){return fail('Verification unavailable: '+String(e),500)}
});
