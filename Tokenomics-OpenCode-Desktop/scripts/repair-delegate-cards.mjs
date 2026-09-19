// Existing session display maintenance only; never starts inference.
// node scripts/repair-delegate-cards.mjs LOCAL_SERVER SESSION_ID [--restore]
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createPresenter,restoreDelegateTools} from '../tools/runtime/presentation.mjs';
const [server,sessionID,mode]=process.argv.slice(2);
const url=new URL(server);
if(!['127.0.0.1','localhost','[::1]'].includes(url.hostname)||!/^ses_[\w]+$/.test(sessionID||''))throw Error('Provide a local OpenCode server and session ID.');
const directory=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
async function request(route,body){const r=await fetch(new URL(route+'?directory='+encodeURIComponent(directory),url),body?{method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}:{});if(!r.ok)throw Error('Local session request failed: '+r.status);return{data:await r.json()};}
const messages=(await request('/session/'+sessionID+'/message')).data;
const backupDir=path.join(directory,'.state','display-backups');await mkdir(backupDir,{recursive:true});
const backup=path.join(backupDir,sessionID+'-'+Date.now()+'.json');await writeFile(backup,JSON.stringify(messages,null,2));
const update=body=>request(`/session/${body.sessionID}/message/${body.messageID}/part/${body.id}`,body);
const present=createPresenter({client:{session:{get:({path})=>request('/session/'+path.id)},part:{update:({body})=>update(body)}},directory});
let count=0;
for(const m of messages)for(const p of m.parts||[]){
 if(mode==='--restore'){
  if(p.state?.metadata?.tokenomics_delegate_display?.version!==1)continue;
  restoreDelegateTools([{parts:[p]}]);p.state.metadata={...p.state.metadata,tokenomics_display_disabled:true};await update(p);count++;
 }else{
  if(p.state?.metadata)delete p.state.metadata.tokenomics_display_disabled;
  if(await present(p))count++;
 }
}
console.log(JSON.stringify({updated:count,mode:mode==='--restore'?'restore':'native_cards',provider_calls:0,new_sessions:0,backup}));
