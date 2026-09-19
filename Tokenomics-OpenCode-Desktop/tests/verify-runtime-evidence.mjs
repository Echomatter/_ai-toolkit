// Read-only installed-runtime assertions, no inference and no credentials exported.
// node tests/verify-runtime-evidence.mjs http://127.0.0.1:PORT RECEIPT.json
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createDelegator, observe } from '../tools/runtime/delegation.mjs';
const [base, file] = process.argv.slice(2);
if (!base || !file) throw new Error('Provide the local test server URL and a completed receipt');
const url = new URL(base);
if (!['127.0.0.1','localhost','[::1]'].includes(url.hostname)) throw new Error('Only a local test server is supported');
const receipt=JSON.parse((await readFile(file,'utf8')).replace(/^\uFEFF/,''));
const attempt=receipt.attempts.at(-1);
assert.equal(receipt.status,'completed');
async function get(route) {
  const response=await fetch(new URL(route+'?directory='+encodeURIComponent(receipt.directory),url));
  if(!response.ok) throw new Error(`Runtime read failed: ${response.status}`);
  return response.json();
}
const parent=await get(`/session/${receipt.parent_session}/message`);
const child=await get(`/session/${attempt.child_session}/message`);
assert.deepEqual([...new Set(parent.filter(m=>m.info.role==='assistant').map(m=>`${m.info.providerID}/${m.info.modelID}`))],[receipt.parent_model]);
const observed=observe(child,attempt.selected_model,receipt.role);
assert.equal(observed.complete,true);assert.equal(observed.observed,attempt.dispatched_model);
assert.notEqual(observed.observed,receipt.parent_model);
assert.throws(()=>observe(child,'opencode/deliberate-wrong-model',receipt.role),/differs/);
const client={session:{get:async({path:{id}})=>({data:await get(`/session/${id}`)}),messages:async({path:{id}})=>({data:await get(`/session/${id}/message`)})}};
const guard=createDelegator({client,toolkitRoot:receipt.directory,directory:receipt.directory});
await assert.rejects(guard.checkTool({sessionID:attempt.child_session,tool:'bash'},{args:{command:'echo SHOULD_NOT_EXECUTE'}}),/Read-only/);
await assert.rejects(guard.checkTool({sessionID:attempt.child_session,tool:'content_index'},{args:{operation:'rebuild'}}),/Read-only/);
await guard.checkTool({sessionID:attempt.child_session,tool:'read'},{args:{filePath:'opencode/catalog.json'}});
console.log(JSON.stringify({proof:'installed-runtime with live provider messages',parent:receipt.parent_model,child:observed.observed,parent_unchanged:true,wrong_model_negative_control:'detected',restored_shell_and_rebuild_guard:'denied',read:'allowed',usage:observed.usage},null,2));
