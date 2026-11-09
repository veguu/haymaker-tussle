const p=document.querySelector('#movie_player'); const v=document.querySelector('video'); v.muted=true; v.play().catch(()=>{});
await new Promise(r=>setTimeout(r,1500));
p.loadModule&&p.loadModule('captions');
await new Promise(r=>setTimeout(r,400));
p.setOption('captions','track',{languageCode:'ja'});
await new Promise(r=>setTimeout(r,2500));
v.pause();
const urls=performance.getEntriesByType('resource').filter(e=>/timedtext/.test(e.name)).map(e=>e.name);
const lastUrl=urls[urls.length-1];
if(!lastUrl){ document.title+' NO CAPTIONS' } else {
const u=lastUrl.replace(/&fmt=[^&]*/,'').replace(/&tlang=[^&]*/,'');
const r=await fetch(u+'&fmt=json3&tlang=en'); const j=JSON.parse(await r.text());
let out=[],cur=null;
for(const e of j.events){ if(!e.segs)continue; const s=Math.floor(e.tStartMs/1000); const t=e.segs.map(x=>x.utf8).join('').replace(/\n/g,' ').replace(/\[Music\]/g,'').trim(); if(!t)continue; if(!cur||s-cur.s>=12){cur={s,t:[]};out.push(cur);} cur.t.push(t);}
document.title+'\n'+out.map(c=>Math.floor(c.s/60)+':'+String(c.s%60).padStart(2,'0')+' '+c.t.join(' ')).join('\n') }
