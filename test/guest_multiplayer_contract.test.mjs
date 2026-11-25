import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, existsSync} from 'node:fs';
import {Script, runInNewContext} from 'node:vm';
import {join} from 'node:path';

const read=path=>readFileSync(join(process.cwd(),path),'utf8');
const games=['duck','hearts','blackjack'];
const shared=read('web/genesis-multiplayer.js');
const invite=read('supabase/functions/game-invite/index.ts');

test('shared multiplayer module parses and exports real QR code renderer',()=>{
 new Script(shared,{filename:'genesis-multiplayer.js'});
 assert.match(shared,/window\.GenesisInvites=Object\.freeze\(/);
 assert.match(shared,/new window\.QRCode\(/);
 assert.match(shared,/create_room/);
 assert.match(shared,/signInAnonymously/);
 assert.match(shared,/guestToken\(/);
 assert.match(shared,/rememberHost/);
 assert.match(shared,/restoreHost/);
 assert.match(shared,/addShareButton/);
});

test('all multiplayer games use one QR encoder and guest-host flow',()=>{
 assert.ok(existsSync('web/vendor/qrcode.min.js'));
 assert.ok(existsSync('web/vendor/qrcode.LICENSE'));
 new Script(read('web/vendor/qrcode.min.js'),{filename:'qrcode.min.js'});
 for(const name of games){
  const html=read('web/genesis-'+name+'.html');
  assert.match(html,/src="genesis-multiplayer\.js/);
  assert.match(html,/src="vendor\/qrcode\.min\.js"/);
  assert.match(html,/GenesisInvites\.mountGuestUI\(/);
  assert.match(html,/GenesisInvites\.gameRequest\(/);
  assert.match(html,/GenesisInvites\.restoreHost\(/);
  const blocks=[...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)];
  assert.ok(blocks.length>0,'no inline script for '+name);
  for(const [i,m] of blocks.entries())new Script(m[1],{filename:name+'-inline-'+i+'.js'});
 }
});

test('game-invite implements permissioned anonymous host and expiry controls',()=>{
 assert.match(invite,/if\(a==='create_room'\)/);
 assert.match(invite,/user\?\.is_anonymous/);
 assert.match(invite,/r\.host_id!==user\.id/);
 assert.match(invite,/Boolean\(r\.guest_host\)!==Boolean\(user\.is_anonymous\)/);
 assert.match(invite,/1800000/);
 assert.match(invite,/throttle\(/);
 assert.match(invite,/agc_join_duck_guest/);
 assert.match(invite,/agc_join_hearts_guest/);
 assert.match(invite,/agc_join_blackjack_guest/);
});

test('invitation scan works without login and persists guest room session',()=>{
 const html=read('web/join.html');
 assert.match(html,/GenesisInvites\.inspect\(/);
 assert.match(html,/GenesisInvites\.call\('join'/);
 assert.match(html,/sessionStorage\.setItem\('genesis-'/);
 assert.match(html,/location\.replace\('\/genesis-'/);
});

test('registered-score triggers explicitly skip anonymous identities',()=>{
 const schema=read('supabase/migrations/20261125190000_guest_multiplayer_security.sql');
 const signup=read('supabase/migrations/20261125193000_skip_guest_signup_membership.sql');
 const scores=read('supabase/migrations/20261125200000_skip_anonymous_game_score_checkpoints.sql');
 const cleanup=read('supabase/migrations/20261125203000_expire_guest_rooms_cron.sql');
 assert.match(schema,/agc_no_guest_ranked_assets/);
 assert.match(schema,/agc_multiplayer_allow_action/);
 assert.match(schema,/one_active_guest_room/);
 assert.match(signup,/if new\.is_anonymous then/);
 for(const name of ['duck','hearts','blackjack'])assert.match(scores,new RegExp('agc_'+name));
 assert.ok((scores.match(/not is_anonymous/g)||[]).length>=3);
 assert.match(cleanup,/cron\.schedule/);
});

test('shared QR invitation URL points to join page and never exposes room secrets in query',()=>{
 const context={
  window:{}, location:{origin:'https://thegenesisera.com'},
  localStorage:{getItem:()=>null,setItem:()=>{},removeItem:()=>{}},
  URL,URLSearchParams,crypto:globalThis.crypto,
 };
 runInNewContext(shared,context,{filename:'genesis-multiplayer.js'});
 const token='a'.repeat(64);
 assert.equal(context.window.GenesisInvites.link(token),'https://thegenesisera.com/join.html#invite='+token);
});
