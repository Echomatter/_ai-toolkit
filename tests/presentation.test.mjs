import test from 'node:test';
import assert from 'node:assert/strict';
import {taskCard,restoreDelegateTools,createPresenter} from '../tools/runtime/presentation.mjs';
const part=()=>({id:'prt_1',sessionID:'parent',messageID:'msg_1',callID:'call1',type:'tool',tool:'delegate',state:{status:'running',input:{role:'researcher',task:'Inspect math',needsWrites:false},metadata:{sessionId:'child',role:'researcher',selected_model:'opencode/free'},time:{start:1}}});
test('native card points to the real child and restores exact model-visible tool history',()=>{
 const original=part(),card=taskCard(original);assert.equal(card.tool,'task');assert.equal(card.state.metadata.sessionId,'child');assert.equal(card.callID,original.callID);
 const messages=[{parts:[card]}];restoreDelegateTools(messages);assert.deepEqual(messages[0].parts[0],original);
});
test('completion recovers child link from durable receipt; no-route has no fake agent',()=>{
 const p=part();p.state.status='completed';p.state.metadata={truncated:false};p.state.output=JSON.stringify({parent_session:'parent',role:'researcher',attempts:[{child_session:'child',selected_model:'opencode/free'}]});
 assert.equal(taskCard(p).state.metadata.sessionId,'child');p.state.output=JSON.stringify({parent_session:'parent',attempts:[]});assert.equal(taskCard(p),null);
});
test('display adapter never prompts or creates sessions; ignores its own updates',async()=>{
 let updated;const client={session:{get:async()=>({data:{parentID:'parent',metadata:{ai_toolkit:{selected:'opencode/free'}}}})},part:{update:async args=>{updated=args.body;return{data:args.body}}}};
 const present=createPresenter({client,directory:'repo'});assert.equal(await present(part()),true);assert.equal(updated.id,'prt_1');assert.equal(await present(updated),false);
 client.session.get=async()=>({data:{parentID:'other'}});assert.equal(await present(part()),false);
});
test('restored display-disabled calls are not automatically converted again',()=>{
 const p=part();p.state.metadata.ai_toolkit_display_disabled=true;assert.equal(taskCard(p),null);
});
test('injected v1 transport supports the documented part endpoint',async()=>{
 let request;const client={session:{get:async()=>({data:{parentID:'parent',metadata:{ai_toolkit:{selected:'opencode/free'}}}})},_client:{patch:async args=>{request=args;return{data:args.body}}}};
 assert.equal(await createPresenter({client,directory:'repo'})(part()),true);
 assert.equal(request.url,'/session/{sessionID}/message/{messageID}/part/{partID}');assert.equal(request.path.partID,'prt_1');
});
