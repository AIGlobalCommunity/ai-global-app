(function(){
  'use strict';
  let button;
  function show(game, score) {
    if (!button) {
      button=document.createElement('button');
      button.type='button';
      button.id='genesis-share-after-game';
      button.textContent='📲 UDOSTĘPNIJ WYNIK';
      button.style.cssText='position:fixed;bottom:calc(18px + env(safe-area-inset-bottom));left:50%;transform:translateX(-50%);z-index:2147483647;border:2px solid #f3c66a;border-radius:14px;background:#10283e;color:#ffe0a1;padding:14px 20px;font:bold 15px system-ui;box-shadow:0 8px 30px #000b;cursor:pointer;max-width:90vw;white-space:nowrap';
      document.body.appendChild(button);
    }
    button.style.display='block';
    button.onclick=function(){
      const payload={type:'genesis-share-finished-score',game:game,score:Math.max(0,Math.round(Number(score)||0))};
      if(window.parent!==window)window.parent.postMessage(JSON.stringify(payload),location.origin);
      else location.href='/share-result.html?'+new URLSearchParams({game:game,score:String(payload.score)});
    };
  }
  function hide(){if(button)button.style.display='none'}
  window.genesisShowEndShare=show;
  window.genesisHideEndShare=hide;
})();
