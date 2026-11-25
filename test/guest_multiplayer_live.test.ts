import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4';
import { assert, assertEquals, assertMatch } from 'jsr:@std/assert@1';

const url='https://gjnddmurmegbklvedhnp.supabase.co';
const key='sb_publishable_Ty3Beae5ztODv0MM3Z_HDA_WEGwOyLP';
const endpoint=url+'/functions/v1/';
const nick='CI_Gosc_'+crypto.randomUUID().replaceAll('-','').slice(0,10);

async function api(fn:string,action:string,payload:Record<string,unknown>,jwt?:string){
 const response=await fetch(endpoint+fn,{method:'POST',headers:{
  'Content-Type':'application/json',
  ...(jwt?{Authorization:'Bearer '+jwt}:{})
 },body:JSON.stringify({action,...payload})});
 const value=await response.json();
 return {status:response.status,value};
}
function ok(result:{status:number,value:any},msg:string){
 assert(result.status>=200&&result.status<300, msg+' ('+result.status+'): '+JSON.stringify(result.value));
 assert(!result.value.error,msg+': '+result.value.error);
 return result.value;
}

Deno.test('Live Supabase: guest hosts can create, invite by QR, start and close each multiplayer room', async()=>{
 const client=createClient(url,key,{auth:{autoRefreshToken:false,persistSession:false}});
 const {data,error}=await client.auth.signInAnonymously({options:{data:{nickname:nick}}});
 assert(!error,'Anonymous Sign-Ins must be enabled in Supabase Auth: '+error?.message);
 assert(data.session?.access_token,'No anonymous access token');
 assert(data.user?.is_anonymous,'Account must be anonymous');
 const jwt=data.session.access_token;
 const {error:walletError}=await client.rpc('agc_coin_buy_life',{p_game:'defender',p_request:crypto.randomUUID()});
 assert(walletError,'Guest wallet purchases must be rejected');

 for(const game of ['duck','hearts','blackjack']){
  let room='';
  try{
   const dataConfig=game==='blackjack'?{players:1,stake:10}:{};
   const create=ok(await api('game-invite','create_room',{game,nickname:nick,...dataConfig},jwt),'create '+game);
   room=create.room;
   assertMatch(room,/^[a-f0-9-]{36}$/i,'Room identifier must be UUID');

   const duplicate=await api('game-invite','create_room',{game,nickname:nick,...dataConfig},jwt);
   assertEquals(duplicate.status,409,'Only one active guest-hosted room per game');

   const invitation=ok(await api('game-invite','renew',{game,room},jwt),'renew '+game);
   assertMatch(invitation.invite,/^[a-f0-9]{64}$/);
   const validUntil=Date.parse(invitation.expires);
   assert(Math.abs(validUntil-(Date.now()+30*60_000))<30_000,'QR expiry must be 30 minutes');

   const inspect=ok(await api('game-invite','inspect',{invite:invitation.invite}),'inspect '+game);
   assertEquals(inspect.game,game);
   assertEquals(inspect.room,room);

   const guest=ok(await api('game-invite','join',{invite:invitation.invite,nickname:'Zaproszony_'+game,rules:true}),'join '+game);
   assertEquals(guest.room,room);
   assertMatch(guest.session,/^[a-f0-9]{64}$/);

   const hostState=ok(await api(game+'-game','state',{room},jwt),'host state '+game).room;
   assertEquals(hostState.id,room);
   assert(game==='duck'?hostState.host===true:hostState.seat===0,'Host must be identified server-side');

   const playerState=ok(await api(game+'-game','state',{room,session:guest.session}),'guest state '+game).room;
   assertEquals(playerState.id,room);

   const forbidden=await api(game+'-game','start',{room,session:guest.session});
   assert(forbidden.status>=400,'Non-host must not start game');

   const start=ok(await api(game+'-game','start',{room},jwt),'start '+game).room;
   assertEquals(start.status,'playing');

   const reconnect=ok(await api(game+'-game','state',{room},jwt),'reconnect '+game).room;
   assertEquals(reconnect.status,'playing');
  }finally{
   if(room){
    const closed=await api(game+'-game','close',{room},jwt);
    assert(closed.status>=200&&closed.status<300,'Failed to clean CI room for '+game+': '+JSON.stringify(closed.value));
   }
  }
 }
});
