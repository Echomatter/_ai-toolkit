import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readdir, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createDelegator, observe, failureKind, splitModel } from '../tools/runtime/delegation.mjs';

async function fixture(t, options = {}) {
  const root = await mkdtemp(path.join(os.tmpdir(), 'toolkit-test-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  await mkdir(path.join(root, 'routing'));
  await writeFile(path.join(root, 'routing', 'policy.json'), JSON.stringify({ allowed_surfaces: ['opencode-go', 'opencode-free'], allow_overage: false }));
  const requests = [], sessions = new Map([['parent', { id: 'parent', permission: [{ permission: 'secret-tool', pattern: '*', action: 'deny' }] }]]);
  const messages = new Map(), states = {}, records = [];
  let next = 0, time = 0;
  const data = v => ({ data: v });
  const client = {
    config: { get: async () => data({ subagent_depth: options.depth ?? 2 }) },
    app: { agents: async () => data(['worker', 'architect', 'researcher', 'review'].map(name => ({ name, permission: [] }))) },
    session: {
      get: async ({ path: { id } }) => data(sessions.get(id)),
      message: async () => data({ info: { role: 'assistant', ...splitModel(options.parentModel || 'opencode/free-parent'), agent: options.parentRole || 'build' } }),
      create: async ({ body, query }) => {
        requests.push({ kind: 'create', body, query });
        const child = { ...body, id: `child${++next}` };
        if (options.stripPermission) delete child.permission;
        sessions.set(child.id, child); messages.set(child.id, []);
        return data(child);
      },
      promptAsync: async ({ path: { id }, body, query }) => {
        requests.push({ kind: 'prompt', id, body, query });
        if (options.submitTimeout) return new Promise(() => {});
        const model = options.wrongModel ? { providerID: 'opencode', modelID: 'free-parent' } : body.model;
        if (!options.hang) messages.set(id, [assistant(id, model, options.failFirst && id === 'child1' ? {error:{name:'APIError',data:{statusCode:503,message:'provider unavailable'}}} : {})]);
        else states[id] = { type: 'busy' };
        return { data: undefined };
      },
      messages: async ({ path: { id } }) => data(messages.get(id) || []),
      status: async () => data(states),
      abort: async ({ path: { id } }) => { requests.push({ kind: 'abort', id }); if (!options.abortFails) delete states[id]; return data(true); },
    },
  };
  const controller = new AbortController();
  const ctx = { sessionID: 'parent', messageID: 'message', agent: 'build', directory: root, worktree: root,
    abort: controller.signal, ask: async req => { requests.push({ kind: 'permission', req }); if (options.deny || (options.denyPaid && req.permission === 'paid_delegate')) throw new Error('denied'); }, metadata: () => {} };
  let choice = 0;
  const service = createDelegator({ client, toolkitRoot: root, directory: root,
    select: async a => {
      requests.push({ kind: 'select', args: a });
      const index=choice++;
      return { selected_model: options.noRoute ? null : options.models?.[index] || 'opencode-go/model-b', surface: options.surfaces?.[index] || options.surface || 'opencode-go', adequacy: options.adequacy || 'adequate', quota_state: { overage: options.overage } };
    },
    record: async r => records.push(structuredClone(r)), now: () => time,
    sleep: async ms => { time += ms; }, limits: { pollMs: 1, taskMs: 6, firstResponseMs: 2, stopMs: 4, requestMs: 20 },
  });
  return { root, ctx, client, service, requests, messages, records, sessions, states, controller };
}
function assistant(id, model, extra = {}) {
  return { info: { id: `${id}-answer`, role: 'assistant', sessionID: id, ...model,
    time: { created: 0, completed: 1 }, finish: 'stop', cost: 0.01,
    tokens: { input: 10, output: 5, reasoning: 0, cache: { read: 3, write: 1 } }, ...extra },
    parts: [{ type: 'text', text: 'A verified fixture result, not a live provider result.' }] };
}
const args = { role: 'worker', task: 'Perform a bounded task; preserve user changes.', needsWrites: true };

test('freeOnly is forwarded, enforced at dispatch and inherited by descendants', async t => {
  const f = await fixture(t);
  const denied = await f.service.execute({ ...args, freeOnly: true }, f.ctx);
  assert.equal(denied.status, 'free_only_violation');
  assert.equal(f.requests.find(r => r.kind === 'select').args.freeOnly, true);
  assert.equal(f.requests.filter(r => r.kind === 'create').length, 0);
  const g = await fixture(t, { surface: 'opencode-free', models: ['opencode/free'] });
  await g.service.execute({ ...args, freeOnly: true }, g.ctx);
  assert.equal(g.sessions.get('child1').metadata.ai_toolkit.freeOnly, true);
  g.sessions.get('parent').metadata = { ai_toolkit: { selected: 'opencode/free-parent', readOnly: false, freeOnly: true } };
  await g.service.execute({ ...args, freeOnly: false, task: 'Cannot weaken inherited free constraint' }, { ...g.ctx, messageID: 'new' });
  assert.equal(g.requests.filter(r => r.kind === 'select').at(-1).args.freeOnly, true);
  assert.equal(g.requests.filter(r => r.kind === 'permission' && r.req.permission === 'paid_delegate').length, 0);
});

test('subscription permission precedes creation and rejection never dispatches or retries', async t => {
  const f = await fixture(t, { denyPaid: true });
  const result = await f.service.execute(args, f.ctx);
  assert.equal(result.status, 'paid_permission_declined');
  assert.equal(result.subscription_request.selected_model, 'opencode-go/model-b');
  assert.equal(result.subscription_request.status, 'not_granted');
  assert.equal(result.attempts.length, 0);
  assert.match(result.result, /NO CHILD RAN/);
  assert.equal(f.requests.filter(r => r.kind === 'create').length, 0);
  const g = await fixture(t);
  await g.service.execute(args, g.ctx);
  assert.ok(g.requests.findIndex(r => r.req?.permission === 'paid_delegate') < g.requests.findIndex(r => r.kind === 'create'));
  assert.deepEqual(g.requests.find(r => r.req?.permission === 'paid_delegate').req.patterns, ['opencode-go/model-b']);
});

test('review defaults to model diversity and no-route cannot imply completed review', async t => {
  const f = await fixture(t, { noRoute: true });
  const result = await f.service.execute({ ...args, role: 'review', freeOnly: true }, f.ctx);
  assert.equal(f.requests.find(r => r.kind === 'select').args.needsModelDiversity, true);
  assert.equal(result.validation, 'pending');
  assert.match(result.result, /Do not record success/);
  assert.equal(result.routing_diagnostics.free_only, true);
});

test('CLI bridge forwards hard free constraint and specialist review mode', async () => {
  const { selectorArguments } = await import('../tools/runtime/bridge.mjs');
  const flags = selectorArguments({ role: 'review', freeOnly: true, reviewMode: 'specialist' }, 'select-model.ps1');
  assert.equal(flags[flags.indexOf('-FreeOnly') + 1], 'true');
  assert.equal(flags[flags.indexOf('-ReviewMode') + 1], 'specialist');
});

test('model parser keeps provider identity and nested model id', () => {
  assert.deepEqual(splitModel('go/vendor/model'), { providerID: 'go', modelID: 'vendor/model' });
  assert.throws(() => splitModel('missing-provider'));
});
test('selected B is dispatched and independently observed, parent A unchanged', async t => {
  const f = await fixture(t); const before = structuredClone(f.sessions.get('parent'));
  const result = await f.service.execute(args, f.ctx);
  assert.equal(result.status, 'completed'); assert.equal(result.validation, 'pending');
  assert.equal(result.parent_model, 'opencode/free-parent');
  assert.equal(result.attempts[0].observed_model, 'opencode-go/model-b');
  assert.equal(f.requests.find(r => r.kind === 'prompt').body.agent, 'worker');
  assert.deepEqual(f.requests.find(r => r.kind === 'prompt').body.model, { providerID: 'opencode-go', modelID: 'model-b' });
  assert.deepEqual(f.sessions.get('parent'), before);
  assert.equal(f.requests[0].kind, 'permission');
  assert.ok(f.sessions.get('child1').permission.some(r => r.permission === 'secret-tool' && r.action === 'deny'));
});
test('wrong-model adapter negative control fails and does not earn selected-model success', async t => {
  const f = await fixture(t, { wrongModel: true }); const result = await f.service.execute(args, f.ctx);
  assert.equal(result.status, 'failed'); assert.equal(result.attempts[0].failure, 'binding');
  assert.equal(result.attempts[0].observed_model, 'opencode/free-parent'); assert.equal(f.requests.filter(r => r.kind === 'prompt').length, 1);
  assert.ok(f.requests.some(r => r.kind === 'abort'));
});
test('SDK must echo preserved session permission rules before inference', async t => {
  const f = await fixture(t, { stripPermission: true }); const result = await f.service.execute(args, f.ctx);
  assert.notEqual(result.status, 'completed'); assert.equal(f.requests.filter(r => r.kind === 'prompt').length, 0);
});
test('task permission rejection prevents session creation', async t => {
  const f = await fixture(t, { deny: true }); await assert.rejects(f.service.execute(args, f.ctx), /denied/);
  assert.equal(f.requests.filter(r => r.kind === 'create').length, 0);
});
test('configured depth respected before creation', async t => {
  const f = await fixture(t, { depth: 0 }); await assert.rejects(f.service.execute(args, f.ctx), /depth/);
  assert.equal(f.requests.filter(r => r.kind === 'create').length, 0);
});
test('one role can execute B then C without editing a shared model pin', async t => {
  const f = await fixture(t, { models: ['opencode-go/b', 'opencode-go/c'] });
  const b = await f.service.execute(args, f.ctx);
  const c = await f.service.execute({ ...args, task: 'A different task' }, { ...f.ctx, messageID: 'next-message' });
  assert.equal(b.attempts[0].observed_model, 'opencode-go/b'); assert.equal(c.attempts[0].observed_model, 'opencode-go/c');
});
test('duplicate completion delivery does not launch another child', async t => {
  const f = await fixture(t); await f.service.execute(args, f.ctx);
  const replay = await f.service.execute(args, f.ctx);
  assert.equal(replay.replay, true); assert.equal(f.requests.filter(r => r.kind === 'prompt').length, 1);
});
test('simultaneous identical dispatch coalesces to one execution', async t => {
  const f = await fixture(t); await Promise.all([f.service.execute(args, f.ctx), f.service.execute(args, f.ctx)]);
  assert.equal(f.requests.filter(r => r.kind === 'prompt').length, 1);
});
test('timeout aborts actual session, no automatic replacement writer', async t => {
  const f = await fixture(t, { hang: true }); const result = await f.service.execute(args, f.ctx);
  assert.equal(result.status, 'failed'); assert.equal(result.attempts[0].abort_verified, true);
  assert.equal(f.requests.filter(r => r.kind === 'create').length, 1);
});
test('unverified abort retains writer lock instead of claiming safe stop', async t => {
  const f = await fixture(t, { hang: true, abortFails: true }); const result = await f.service.execute(args, f.ctx);
  assert.equal(result.status, 'stop_unverified');
  const names = await readdir(path.join(f.root, '.state', 'delegation')); assert.ok(names.some(n => n.endsWith('.lock')));
  await assert.rejects(f.service.execute({ ...args, task: 'second writer' }, f.ctx), /writer/i);
});
test('ambiguous prompt submission cannot release writer for an unsafe replacement', async t => {
  const f = await fixture(t, { submitTimeout: true }); const result = await f.service.execute(args, f.ctx);
  assert.equal(result.status, 'stop_unverified'); assert.equal(f.requests.filter(r => r.kind === 'create').length, 1);
});
test('read-only role forces write restrictions even when caller asks for writes', async t => {
  const f = await fixture(t); await f.service.execute({ ...args, role: 'researcher' }, f.ctx);
  const p = f.sessions.get('child1').permission;
  assert.ok(!p.some(r => r.permission === 'bash' && r.action === 'deny'));
  await assert.rejects(f.service.checkTool({ sessionID: 'child1', tool: 'bash' }, { args: { command: 'echo unsafe' } }), /Read-only/);
  assert.ok(p.some(r => r.permission === 'edit' && r.action === 'deny'));
});
test('unapproved overage and weak selection never execute', async t => {
  const f = await fixture(t, { overage: true }); const r = await f.service.execute(args, f.ctx);
  assert.equal(r.status, 'overage_not_authorized'); assert.equal(f.requests.filter(x => x.kind === 'create').length, 0);
  const g = await fixture(t, { adequacy: 'weak' }); const q = await g.service.execute(args, g.ctx);
  assert.equal(q.status, 'no_qualified_route');
});
test('all assistant tool continuations must retain selected binding', () => {
  const b = { providerID: 'go', modelID: 'b' };
  const first = assistant('1', b, { finish: 'tool-calls' });
  const second = assistant('2', b);
  assert.equal(observe([first, second], 'go/b').usage.input, 20);
  assert.throws(() => observe([first, assistant('2', { providerID: 'go', modelID: 'a' })], 'go/b'), /differs/);
});
test('same-model independent sessions are measured separately, duplicate message ids counted once', () => {
  const a = assistant('a', { providerID: 'go', modelID: 'b' });
  const b = assistant('b', { providerID: 'go', modelID: 'b' });
  assert.equal(observe([a, a], 'go/b').usage.input, 10);
  assert.equal(observe([b], 'go/b').usage.input, 10);
});
test('missing usage is unknown, not measured zero', () => {
  const m = assistant('a', { providerID: 'go', modelID: 'b' }); delete m.info.tokens;
  assert.equal(observe([m], 'go/b').usage, null);
});
test('quota vs binding vs provider errors stay separate', () => {
  assert.equal(failureKind({ name: 'FreeUsageLimitError' }), 'quota');
  assert.equal(failureKind({ name: 'BindingFailure' }), 'binding');
  assert.equal(failureKind({ data: { statusCode: 429 } }), 'throttle');
});


test('selector arguments preserve composite task categories and rejected routes', async () => {
  const { selectorArguments } = await import('../tools/runtime/bridge.mjs');
  const a = selectorArguments({ role: 'worker', taskTypes: ['ml', 'debugging'], rejected: ['go/b'], currentModel: 'go/a', needsWrites: true }, 'select-model.ps1');
  assert.equal(a[a.indexOf('-TaskType') + 1], 'ml,debugging');
  assert.equal(a[a.indexOf('-ExcludedModels') + 1], 'go/b');
  assert.equal(a[a.indexOf('-CurrentModel') + 1], 'go/a');
});
test('auxiliary process timeout returns instead of hanging the parent', async () => {
  const { runProcess } = await import('../tools/runtime/bridge.mjs');
  await assert.rejects(runProcess(process.execPath, ['-e', 'setTimeout(()=>{},10000)'], { timeoutMs: 25 }), /timed out/);
});
test('missing child identity is not an echoed-selector success', () => {
  const m = assistant('a', { providerID: 'go', modelID: 'b' }); delete m.info.providerID;
  assert.throws(() => observe([m], 'go/b'), /lacks runtime/);
});
test('provider error placeholder zeros are not measured consumption', () => {
  const m=assistant('a',{providerID:'go',modelID:'b'},{error:{name:'APIError'},tokens:{input:0,output:0,cache:{read:0,write:0}}});
  assert.equal(observe([m],'go/b').usage,null);
});

test('paid parent to free child retains provider-qualified identity', async t => {
  const f = await fixture(t, { parentModel: 'openai/paid-parent', models: ['opencode/free-child'], surface: 'opencode-free' });
  const r = await f.service.execute({ ...args, needsWrites: false }, f.ctx);
  assert.equal(r.parent_model, 'openai/paid-parent');
  assert.equal(r.attempts[0].observed_model, 'opencode/free-child');
  assert.equal(r.status, 'completed');
});

test('free provider failure permits one stopped read-only free fallback', async t => {
  const f=await fixture(t,{failFirst:true,models:['opencode/a','opencode/b'],surface:'opencode-free'});
  const r=await f.service.execute({...args,needsWrites:false},f.ctx);
  assert.equal(r.status,'completed');assert.equal(r.attempts.length,2);
  assert.equal(r.attempts[0].failure,'provider');assert.equal(r.attempts[0].abort_verified,true);
  assert.equal(r.attempts[1].observed_model,'opencode/b');
});

test('free failure never silently falls through to a subscription route', async t => {
  const f=await fixture(t,{failFirst:true,models:['opencode/a','opencode-go/b'],surfaces:['opencode-free','opencode-go']});
  const r=await f.service.execute({...args,needsWrites:false},f.ctx);
  assert.equal(r.status,'subscription_fallback_requires_parent');assert.equal(r.attempts.length,1);
  assert.equal(f.requests.filter(r=>r.kind==='prompt').length,1);
});

test('subscription provider failure returns to parent without a retry', async t => {
  const f=await fixture(t,{failFirst:true});
  const r=await f.service.execute({...args,needsWrites:false},f.ctx);
  assert.equal(r.status,'failed');assert.equal(r.attempts.length,1);
  assert.equal(f.requests.filter(r=>r.kind==='prompt').length,1);
});
test('independent review executes the selected different model as a read-only reviewer', async t => {
  const f=await fixture(t,{models:['opencode-go/independent-reviewer']});
  const r=await f.service.execute({...args,role:'review',needsWrites:false,needsModelDiversity:true,excludeModel:'opencode/free-parent'},f.ctx);
  assert.equal(r.role,'review');assert.equal(r.attempts[0].observed_model,'opencode-go/independent-reviewer');
  assert.notEqual(r.parent_model,r.attempts[0].observed_model);
  await assert.rejects(f.service.checkTool({sessionID:'child1',tool:'edit'},{args:{}}),/Read-only/);
});
test('null route cannot create a child or become an empty model id', async t => {
  const f = await fixture(t, { noRoute: true });
  const r = await f.service.execute(args, f.ctx);
  assert.equal(r.status, 'no_qualified_route'); assert.equal(r.attempts.length, 0);
  assert.equal(f.requests.filter(r => r.kind === 'create').length, 0);
});
test('worker cannot create another worker even if a permissive host approves task', async t => {
  const f = await fixture(t, { parentRole: 'worker' });
  await assert.rejects(f.service.execute(args, f.ctx), /topology/);
});
test('explicit no-write user assignment overrides a mistaken writer request', async t => {
  const f = await fixture(t);
  f.messages.set('parent', [{info:{role:'user'},parts:[{type:'text',text:'Explain only. Do not modify files.'}]}]);
  await f.service.execute(args, f.ctx);
  assert.equal(f.sessions.get('child1').metadata.ai_toolkit.readOnly, true);
  await assert.rejects(f.service.checkTool({ sessionID: 'child1', tool: 'content_index' }, { args: {operation:'rebuild'} }), /Read-only/);
  await f.service.checkTool({ sessionID: 'child1', tool: 'content_index' }, { args: {operation:'search'} });
});
test('parent ask and deny permissions remain authoritative in child', async t => {
  const f = await fixture(t);
  f.sessions.get('parent').permission.push({permission:'bash',pattern:'*',action:'ask'});
  f.sessions.get('parent').permission.push({permission:'bash',pattern:'git status*',action:'allow'});
  await f.service.execute(args, f.ctx);
  assert.ok(f.sessions.get('child1').permission.some(r=>r.permission==='bash' && r.action==='ask'));
  assert.ok(f.sessions.get('child1').permission.some(r=>r.permission==='bash' && r.pattern==='git status*' && r.action==='allow'));
});
test('read-only guard and binding survive controller restart through session metadata', async t => {
  const f = await fixture(t);
  await f.service.execute({...args,needsWrites:false},f.ctx);
  const restarted=createDelegator({client:f.client,toolkitRoot:f.root,directory:f.root});
  await assert.rejects(restarted.checkTool({sessionID:'child1',tool:'bash'},{args:{command:'echo no'}}),/Read-only/);
  await assert.rejects(restarted.checkModel({sessionID:'child1',model:{providerID:'wrong',id:'model'}}),/binding/);
});
test('nested researcher permitted at configured depth, then blocked at the limit', async t => {
  const f = await fixture(t, {parentRole:'worker',depth:2});
  f.sessions.set('grandparent',{id:'grandparent'}); f.sessions.get('parent').parentID='grandparent';
  const r=await f.service.execute({...args,role:'researcher',needsWrites:false},f.ctx);
  assert.equal(r.status,'completed');
  const limited=await fixture(t,{parentRole:'worker',depth:1});
  limited.sessions.set('grandparent',{id:'grandparent'}); limited.sessions.get('parent').parentID='grandparent';
  await assert.rejects(limited.service.execute({...args,role:'researcher',needsWrites:false},limited.ctx),/depth/);
});
