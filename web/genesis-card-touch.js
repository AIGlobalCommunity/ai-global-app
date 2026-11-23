/* Shared mobile card dragging: pointer events, hit testing and safe tap fallback.
 * Installed inside each game's closure so it uses the existing legal move validator.
 */
window.installGenesisCardTouch = function(config) {
  let active = null, ghost = null, suppressUntil = 0;
  const doc = document;
  const point = e => ({x:e.clientX,y:e.clientY});
  const clearGhost = () => {if(ghost){ghost.remove();ghost=null;}};
  const findDestination = (x,y) => {
    const node = doc.elementFromPoint(x,y);
    if(!node) return null;
    const slot = node.closest('.slot');
    if(slot && config.slotDestination) {
      const found = config.slotDestination(slot);
      if(found) return found;
    }
    const pile = node.closest('.pile');
    if(pile) {
      const parent = pile.parentElement;
      const index = Array.prototype.indexOf.call(parent.children,pile);
      if(index>=0) return {zone:'t',index};
    }
    return null;
  };
  const stop = () => {
    if(active?.element?.isConnected) active.element.classList.remove('genesis-touch-source');
    active=null;
    clearGhost();
  };
  doc.addEventListener('pointerdown',e=>{
    if(e.pointerType==='mouse'||e.button!==0||active||config.isWon()) return;
    const el=e.target.closest('.card');
    if(!el || !config.isMovable(el)) return;
    const src=config.source(el);
    if(!src) return;
    active={id:e.pointerId,element:el,src,start:point(e),last:point(e),dragging:false};
  },{capture:true,passive:true});
  doc.addEventListener('pointermove',e=>{
    if(!active||active.id!==e.pointerId) return;
    active.last=point(e);
    const dx=e.clientX-active.start.x,dy=e.clientY-active.start.y;
    if(!active.dragging && Math.hypot(dx,dy)>9) {
      active.dragging=true;
      ghost=active.element.cloneNode(true);
      ghost.classList.add('genesis-touch-ghost');
      ghost.style.width=active.element.getBoundingClientRect().width+'px';
      ghost.style.height=active.element.getBoundingClientRect().height+'px';
      doc.body.appendChild(ghost);
      active.element.classList.add('genesis-touch-source');
    }
    if(active.dragging){
      e.preventDefault();
      ghost.style.left=(e.clientX-ghost.offsetWidth/2)+'px';
      ghost.style.top=(e.clientY-ghost.offsetHeight/2)+'px';
      ghost.style.transform='rotate(-3deg)';
    }
  },{capture:true,passive:false});
  doc.addEventListener('pointerup',e=>{
    if(!active||active.id!==e.pointerId)return;
    const dragged=active.dragging;
    const src=active.src;
    if(dragged){
      e.preventDefault();
      e.stopImmediatePropagation();
      suppressUntil=Date.now()+450;
      clearGhost();
      const destination=findDestination(e.clientX,e.clientY);
      stop();
      if(destination) config.drop(src,destination);
    }else stop();
  },true);
  doc.addEventListener('pointercancel',stop,true);
  doc.addEventListener('click',e=>{
    if(Date.now()<suppressUntil){e.preventDefault();e.stopImmediatePropagation();}
  },true);
  const css=doc.createElement('style');
  css.textContent='.genesis-touch-ghost{position:fixed!important;pointer-events:none!important;z-index:2147483640!important;opacity:.92;box-shadow:0 16px 32px #0008;touch-action:none}.genesis-touch-source{opacity:.38!important}.card{touch-action:none!important;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}';
  doc.head.appendChild(css);
};
