// Native OpenCode child execution. No global model/agent configuration is mutated.
// SDK response fields, not a model's self-description, establish execution identity.
import { createHash, randomUUID } from 'node:crypto';
import { readFile, mkdir, writeFile, rename, open, unlink, realpath } from 'node:fs/promises';
import path from 'node:path';

const roles = new Set(['worker', 'architect', 'researcher', 'review']);
const topology = { build: ['worker', 'architect', 'researcher', 'review'], worker: ['researcher', 'review'], architect: ['researcher', 'review'], review: ['researcher'], researcher: [] };
const readers = new Set(['read', 'list', 'glob', 'grep', 'webfetch', 'websearch', 'skill', 'todoread']);
const hash = x => createHash('sha256').update(x).digest('hex');
const rule = (permission, action = 'deny', pattern = '*') => ({ permission, pattern, action });
const routeOf = info => info?.providerID && info?.modelID ? `${info.providerID}/${info.modelID}` : null;
export const noWriteAssignment = text => /\b(explain[ -]only|read[ -]only|no[ -](?:file[ -])?(?:writes|edits)|do not (?:modify|edit|change|write)(?: any)? files|just inspect)\b/i.test(text || '');
export function splitModel(id) {
  if (typeof id !== 'string' || !/^[\w.-]+\/[^\s]+$/.test(id)) throw new Error('Invalid provider-qualified model');
  const at = id.indexOf('/');
  return { providerID: id.slice(0, at), modelID: id.slice(at + 1) };
}
export function failureKind(error) {
  const data = error?.data || error || {};
  const name = error?.name || '';
  const text = `${name} ${data.message || ''}`;
  if (/binding|identity/i.test(name)) return 'binding';
  if (/abort|cancel/i.test(name)) return 'cancelled';
  if (/quota|usage.?limit|insufficient.?credit|credit.*exhaust|limit.*reached/i.test(text)) return 'quota';
  if (+data.statusCode === 401 || +data.statusCode === 403) return 'auth';
  if (+data.statusCode === 404 || /model.?not.?found/i.test(name) || /model.*not supported|not supported.*model/i.test(text)) return 'model';
  if (+data.statusCode === 429 || /rate.?limit|ProviderRetry/i.test(name)) return 'throttle';
  if (+data.statusCode >= 500) return 'provider';
  if (/timeout/i.test(name)) return 'timeout';
  return 'execution';
}
function fault(name, message) { return Object.assign(new Error(message), { name }); }
function unwrap(r) {
  if (r?.error) throw Object.assign(new Error(r.error?.data?.message || 'SDK request failed'), r.error);
  return r && Object.hasOwn(r, 'data') ? r.data : r;
}
async function atomicJson(file, value) {
  await mkdir(path.dirname(file), { recursive: true });
  const tmp = `${file}.${randomUUID()}.tmp`;
  try { await writeFile(tmp, JSON.stringify(value, null, 2), { mode: 0o600 }); await rename(tmp, file); }
  finally { await unlink(tmp).catch(() => {}); }
}
async function readJson(file) {
  try { return JSON.parse((await readFile(file, 'utf8')).replace(/^\uFEFF/, '')); }
  catch (e) { if (e.code === 'ENOENT') return null; throw e; }
}
function equalRules(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b)) return false;
  const normalized = rows => rows.map(r => [r.permission, r.pattern, r.action]);
  return JSON.stringify(normalized(a)) === JSON.stringify(normalized(b));
}
function activeTool(messages) {
  return messages.some(m => (m.parts || []).some(p => p.type === 'tool' && ['pending', 'running'].includes(p.state?.status)));
}
export function observe(messages, selected, role) {
  if (!Array.isArray(messages)) throw fault('IdentityUnverified', 'Missing structured child messages');
  const assistants = messages.filter(m => m.info?.role === 'assistant' && !m.info.summary);
  const seen = new Set();
  const usage = { input: 0, output: 0, reasoning: 0, cache_read: 0, cache_write: 0, provider_dollars: 0 };
  let measured = true;
  for (const m of assistants) {
    if (role && m.info.agent && m.info.agent !== role) throw fault('BindingFailure', 'Runtime child role differs from dispatched role');
    if (!routeOf(m.info)) throw fault('IdentityUnverified', 'Child message lacks runtime model identity');
    if (routeOf(m.info) !== selected) throw Object.assign(fault('BindingFailure', 'Runtime child model differs from selected route'), { actual_model: routeOf(m.info) });
    if (!m.info.id || seen.has(m.info.id)) continue;
    seen.add(m.info.id);
    const t = m.info.tokens;
    if (m.info.error && (!t || !(t.input || t.output || t.reasoning || t.cache?.read || t.cache?.write))) measured = false;
    if (!t || ![t.input, t.output, t.reasoning || 0, t.cache?.read || 0, t.cache?.write || 0].every(v => Number.isFinite(v) && v >= 0)) { measured = false; continue; }
    usage.input += t.input; usage.output += t.output;
    usage.reasoning += t.reasoning || 0; usage.cache_read += t.cache?.read || 0;
    usage.cache_write += t.cache?.write || 0;
    usage.provider_dollars += Number.isFinite(m.info.cost) ? m.info.cost : 0;
  }
  const last = assistants.at(-1);
  return { assistants, observed: assistants.length ? selected : null, usage: assistants.length && measured ? usage : null,
    complete: Boolean(last?.info.time?.completed && last.info.finish && last.info.finish !== 'tool-calls' && !activeTool(messages)),
    error: last?.info.error,
    text: (last?.parts || []).filter(p => p.type === 'text').map(p => p.text).join('\n') };
}

/** Inject the plugin's authenticated v1 SDK client; never start another OpenCode server. */
export function createDelegator({ client, toolkitRoot, directory, select, record, beforeSelect = async () => {},
  now = () => Date.now(), sleep = ms => new Promise(r => setTimeout(r, ms)),
  limits = {} }) {
  const cfg = { requestMs: 10000, firstResponseMs: 60000, taskMs: 600000, stopMs: 10000, pollMs: 750, ...limits };
  const live = new Map();
  const inFlight = new Map();
  const stateDir = path.join(toolkitRoot, '.state', 'delegation');
  const stamp = () => new Date(now()).toISOString();
  async function call(group, method, args, signal, timeout = cfg.requestMs) {
    if (signal?.aborted) throw fault('AbortError', 'Parent cancelled');
    const fn = client[group]?.[method];
    if (typeof fn !== 'function') throw fault('UnsupportedRuntime', `SDK lacks ${group}.${method}`);
    const ctl = new AbortController();
    let timer;
    let abort;
    const expired = new Promise((_, reject) => {
      timer = setTimeout(() => { ctl.abort(); reject(fault('RequestTimeout', `${group}.${method} timed out`)); }, timeout);
      abort = () => { ctl.abort(); reject(fault('AbortError', 'Parent cancelled')); };
      if (signal?.aborted) abort(); else signal?.addEventListener('abort', abort, { once: true });
    });
    try { return unwrap(await Promise.race([fn.call(client[group], { ...args, signal: ctl.signal }), expired])); }
    finally { clearTimeout(timer); signal?.removeEventListener('abort', abort); }
  }
  const query = directory => ({ directory });
  const sessionArgs = (id, directory) => ({ path: { id }, query: query(directory) });
  async function parentContext(ctx) {
    const q = query(ctx.directory);
    const parent = await call('session', 'get', sessionArgs(ctx.sessionID, ctx.directory), ctx.abort);
    const message = await call('session', 'message', { path: { id: ctx.sessionID, messageID: ctx.messageID }, query: q }, ctx.abort);
    if (message?.info?.role !== 'assistant' || !routeOf(message.info)) throw fault('IdentityUnverified', 'Parent identity is unavailable');
    const config = await call('config', 'get', { query: q }, ctx.abort);
    const seen = new Set([parent.id]);
    let depth = 0, cursor = parent;
    while (cursor.parentID) {
      if (seen.has(cursor.parentID) || ++depth > 32) throw fault('DepthLimit', 'Invalid session ancestry');
      seen.add(cursor.parentID);
      cursor = await call('session', 'get', sessionArgs(cursor.parentID, ctx.directory), ctx.abort);
    }
    if (depth >= (config?.subagent_depth ?? 1)) throw fault('DepthLimit', 'Configured subagent depth reached');
    const rows = await call('session', 'messages', sessionArgs(ctx.sessionID, ctx.directory), ctx.abort);
    const user = rows.filter(m => m.info?.role === 'user').at(-1);
    const assignment = (user?.parts || []).filter(p => p.type === 'text').map(p => p.text).join('\n');
    return { parent, parentModel: routeOf(message.info), config, assignment, parentRole: message.info.agent || ctx.agent };
  }
  async function stopped(id, directory) {
    // An abort acknowledgement alone is NOT proof of stop. Independently inspect
    // status and outstanding tool parts twice. Unknown/failed checks fail closed.
    try {
      await call('session', 'abort', sessionArgs(id, directory));
      const deadline = now() + cfg.stopMs;
      let idle = 0;
      while (now() < deadline) {
        const statuses = await call('session', 'status', { query: query(directory) });
        const messages = await call('session', 'messages', sessionArgs(id, directory));
        if (!statuses || !Array.isArray(messages)) return false;
        if ((!statuses[id] || statuses[id].type === 'idle') && !activeTool(messages)) {
          if (++idle === 2) return true;
        } else idle = 0;
        await sleep(cfg.pollMs);
      }
    } catch {}
    return false;
  }
  async function lookup(id, directory) {
    const visited = new Set();
    while (id && !visited.has(id) && visited.size < 32) {
      if (live.has(id)) return live.get(id);
      visited.add(id);
      const session = await call('session', 'get', sessionArgs(id, directory));
      const saved = session?.metadata?.ai_toolkit;
      if (saved?.selected && typeof saved.readOnly === 'boolean') return { ...saved, directory };
      id = session?.parentID;
    }
    return null;
  }
  async function emit(receipt) {
    try { await record?.(receipt); }
    catch { receipt.recording_error = 'Outcome hook failed; durable execution receipt retained'; }
  }
  async function run(args, ctx) {
    if (!roles.has(args.role) || !args.task?.trim()) throw new Error('A supported role and bounded task are required');
    if (typeof ctx.ask !== 'function') throw fault('UnsupportedRuntime', 'Native task permission check unavailable');
    await ctx.ask({ permission: 'task', patterns: [args.role], always: ['*'], metadata: { role: args.role } });
    const { parent, parentModel, config, assignment, parentRole } = await parentContext(ctx);
    if (!topology[parentRole]?.includes(args.role)) throw fault('PermissionError', `Role topology does not allow ${parentRole} to delegate ${args.role}`);
    const agents = await call('app', 'agents', { query: query(ctx.directory) }, ctx.abort);
    const agent = agents?.find(a => a.name === args.role);
    if (!agent || !Array.isArray(agent.permission)) throw fault('UnsupportedRuntime', 'Effective role permissions unavailable');
    if (agent.model) throw fault('PinnedRole', 'Remove the helper model pin before dynamic delegation');
    const inherited = await lookup(ctx.sessionID, ctx.directory);
    const freeOnly = inherited?.freeOnly === true || args.freeOnly === true;
    const needsModelDiversity = args.needsModelDiversity ?? args.role === 'review';
    const readOnly = inherited?.readOnly || ['researcher', 'review'].includes(parentRole) ||
      ['researcher', 'review'].includes(args.role) || args.needsWrites !== true || noWriteAssignment(args.task) || noWriteAssignment(assignment);
    if (inherited?.readOnly && args.needsWrites) throw fault('PermissionError', 'Read-only parent cannot create a writer');
    const policy = await readJson(path.join(toolkitRoot, 'routing', 'policy.json'));
    const allowed = new Set(policy?.allowed_surfaces || []);
    const id = hash(JSON.stringify([ctx.sessionID, ctx.messageID, args]));
    const receiptFile = path.join(stateDir, `${id}.json`);
    const previous = await readJson(receiptFile);
    if (previous) {
      const a = previous.attempts?.at(-1);
      if (previous.status === 'completed' && a?.child_session) {
        const rows = await call('session', 'messages', sessionArgs(a.child_session, ctx.directory), ctx.abort);
        const saved = observe(rows, a.selected_model, args.role);
        if (saved.complete) return { ...previous, replay: true, result: saved.text };
      }
      return { ...previous, replay: true, result: 'Existing attempt not replayed. Inspect the listed child session before retrying.' };
    }
    let lock;
    let worktree = await realpath(ctx.worktree || ctx.directory);
    if (process.platform === 'win32') worktree = worktree.toLowerCase();
    const lockPath = path.join(stateDir, `writer-${hash(worktree)}.lock`);
    await mkdir(stateDir, { recursive: true });
    if (!readOnly) {
      try { lock = await open(lockPath, 'wx', 0o600); await lock.writeFile(JSON.stringify({ task_id: id, parent: ctx.sessionID })); }
      catch (e) { if (e.code === 'EEXIST') throw fault('WriterBusy', 'A managed writer is active or its stop is unverified; inspect the writer lock before proceeding'); throw e; }
    }
    const receipt = { task_id: id, user_task_id: args.userTaskId || `${ctx.sessionID}/${ctx.messageID}`, parent_session: ctx.sessionID, parent_model: parentModel, role: args.role,
      task_hash: hash(args.task), task_types: args.taskTypes || [], directory: ctx.directory, free_only: freeOnly,
      created_at: stamp(), status: 'running', validation: 'pending', attempts: [] };
    let release = true;
    try {
      await atomicJson(receiptFile, receipt);
      const rejected = [];
      for (let n = 0; n < 2; n++) {
        if (ctx.abort?.aborted) throw fault('AbortError', 'Parent cancelled');
        await beforeSelect({ signal: ctx.abort });
        const selection = await select({ ...args, freeOnly, needsModelDiversity, needsWrites: !readOnly, currentModel: parentModel, rejected }, ctx);
        const selected = selection?.selected_model;
        if (!selected || !allowed.has(selection.surface) || !['adequate', 'strong'].includes(selection.adequacy)) {
          receipt.status = 'no_qualified_route';
          receipt.routing_diagnostics = { free_only: freeOnly, review_basis: selection?.review_basis,
            reasons: selection?.reason_codes || [], filtered_out: selection?.filtered_out || [] };
          break;
        }
        if (freeOnly && selection.surface !== 'opencode-free') { receipt.status = 'free_only_violation'; break; }
        if (n > 0 && selection.surface !== 'opencode-free') {
          receipt.status = 'subscription_fallback_requires_parent'; break;
        }
        if (selection.quota_state?.overage && policy?.allow_overage !== true) { receipt.status = 'overage_not_authorized'; break; }
        if (rejected.includes(selected)) { receipt.status = 'no_alternative'; break; }
        if (selection.surface !== 'opencode-free') {
          receipt.status = 'awaiting_paid_permission';
          receipt.subscription_request = { selected_model: selected, surface: selection.surface,
            requested_at: stamp(), status: 'pending' };
          await atomicJson(receiptFile, receipt);
          try {
            await ctx.ask({ permission: 'paid_delegate', patterns: [selected], always: [selected],
              metadata: { model: selected, surface: selection.surface, role: args.role,
                reason: (selection.reason_codes || []).join('; '),
                consumption_estimate: selection.consumption_estimate || null,
                note: 'Uses subscription capacity. Provider price proxies are not a cash charge estimate.' } });
          } catch {
            receipt.status = ctx.abort?.aborted ? 'cancelled' : 'paid_permission_declined';
            receipt.subscription_request.status = 'not_granted'; break;
          }
          receipt.subscription_request.status = 'allowed_by_native_permission';
          receipt.status = 'running';
        }
        const model = splitModel(selected);
        const attempt = { selected_model: selected, dispatched_model: null, observed_model: null,
          surface: selection.surface, selection_reasons: selection.reason_codes || [], adequacy: selection.adequacy,
          review_basis: selection.review_basis || null,
          started_at: stamp(), status: 'starting', abort_verified: null };
        receipt.attempts.push(attempt);
        const permissions = [
          ...(parent.permission || []),
          ...((config.experimental?.primary_tools || []).map(p => rule(p))),
          ...(agent.permission.some(r => r.permission === 'todowrite') ? [] : [rule('todowrite')]),
          // Keep the native bash schema visible: OpenCode free routes reject
          // requests without it. checkTool blocks its execution before any shell
          // starts, including descendants. Explicit USER bash denies still apply.
          ...(readOnly ? [rule('edit'), rule('write'), rule('apply_patch')] : []),
        ];
        let child;
        let acknowledged = false;
        let submitted = false;
        try {
          child = await call('session', 'create', { query: query(ctx.directory), body: {
            parentID: ctx.sessionID, title: `Toolkit ${args.role} (${id.slice(0, 8)})`, agent: args.role, permission: permissions,
            metadata: { ai_toolkit: { selected, readOnly, freeOnly } },
          } }, ctx.abort);
          if (!child?.id || child.id === ctx.sessionID) throw fault('UnsupportedRuntime', 'Child session was not created');
          attempt.child_session = child.id;
          await atomicJson(receiptFile, receipt);
          const verify = await call('session', 'get', sessionArgs(child.id, ctx.directory), ctx.abort);
          if (verify.parentID !== ctx.sessionID || !equalRules(verify.permission, permissions)) {
            throw fault('UnsupportedRuntime', 'Server did not preserve child linkage/permissions; no inference sent');
          }
          live.set(child.id, { selected, readOnly, freeOnly, directory: ctx.directory });
          ctx.metadata?.({ title: `@${args.role} · ${selected}`, metadata: { sessionId: child.id, parentSessionId: ctx.sessionID, role: args.role, selected_model: selected, model, task_id: id } });
          submitted = true;
          attempt.dispatched_model = selected;
          await call('session', 'promptAsync', { ...sessionArgs(child.id, ctx.directory), body: {
            agent: args.role, model, ...(args.variant ? { variant: args.variant } : {}),
            parts: [{ type: 'text', text: `${args.task}\n\n${readOnly ? 'READ-ONLY: do not change source or local artifacts; return evidence.' : 'Preserve unrelated work. Validate changes; report unverified checks honestly.'}` }],
          } }, ctx.abort);
          acknowledged = true;
          attempt.dispatched_model = selected;
          const start = now();
          while (now() - start < cfg.taskMs) {
            if (ctx.abort?.aborted) throw fault('AbortError', 'Parent cancelled');
            const messages = await call('session', 'messages', sessionArgs(child.id, ctx.directory), ctx.abort);
            const observation = observe(messages, selected, args.role);
            attempt.observed_model = observation.observed;
            attempt.usage = observation.usage;
            attempt.usage_source = observation.usage ? 'session_messages' : 'unavailable';
            if (observation.error) throw Object.assign(new Error('Child failed'), observation.error);
            const statuses = await call('session', 'status', { query: query(ctx.directory) }, ctx.abort);
            if (!statuses || typeof statuses !== 'object' || Array.isArray(statuses)) throw fault('UnsupportedRuntime', 'Missing runtime session status');
            if (statuses?.[child.id]?.type === 'retry') throw fault('ProviderRetry', 'Provider entered retry; returning control instead of waiting indefinitely');
            if (observation.complete && (!statuses?.[child.id] || statuses[child.id].type === 'idle')) {
              attempt.status = 'completed'; attempt.completed_at = stamp(); attempt.elapsed_ms = now() - start;
              receipt.status = 'completed';
              await atomicJson(receiptFile, receipt);
              await emit(receipt);
              return { ...receipt, result: observation.text, note: 'Execution complete; task correctness still requires validation.' };
            }
            if (!observation.observed && now() - start > cfg.firstResponseMs) throw fault('StartupTimeout', 'No observable child response within startup bound');
            await sleep(cfg.pollMs);
          }
          throw fault('TaskTimeout', 'Bounded child execution time reached');
        } catch (e) {
          if (e.actual_model) attempt.observed_model = e.actual_model;
          attempt.status = 'failed'; attempt.failure = failureKind(e); attempt.error_type = e.name || 'Error';
          attempt.completed_at = stamp();
          if (child?.id) attempt.abort_verified = await stopped(child.id, ctx.directory);
          else attempt.abort_verified = true; // No prompt was sent without a known child ID.
          // A failed/ambiguous submission is not safe to replay as another writer.
          if (!attempt.abort_verified || (!acknowledged && submitted)) release = false;
          receipt.status = release ? 'failed' : 'stop_unverified';
          await atomicJson(receiptFile, receipt);
          await emit(receipt);
          // No automatic competing writer, even after stop: inspect partial edits first.
          // Read-only model-specific failures can take one qualified alternative.
          if (!release || !readOnly || selection.surface !== 'opencode-free' || !attempt.abort_verified || !['model', 'throttle', 'provider'].includes(attempt.failure)) break;
          rejected.push(selected);
        } finally { if (child?.id && release) live.delete(child.id); }
      }
      await atomicJson(receiptFile, receipt);
      return { ...receipt, result: receipt.attempts.length === 0
        ? 'NO CHILD RAN. No independent review or validated outcome exists. Report the status and routing diagnostics. Do not record success or present parent self-review as independent. Keep the parent model unchanged; do not retry the same request or relax free-only/quality requirements silently.'
        : 'No completed child result. Inspect the listed sessions and partial results. Do not record success or claim independent verification. Keep the parent model unchanged.' };
    } finally {
      if (lock) { await lock.close(); if (release) await unlink(lockPath).catch(() => {}); }
    }
  }
  return {
    async execute(args, ctx) {
      const key = hash(JSON.stringify([ctx.sessionID, ctx.messageID, args]));
      if (inFlight.has(key)) return inFlight.get(key);
      const promise = run(args, ctx);
      inFlight.set(key, promise);
      try { return await promise; } finally { inFlight.delete(key); }
    },
    // Guard before the model request, plus independent message observation after it.
    async checkModel(input) {
      const entry = await lookup(input.sessionID, input.directory || directory);
      if (!entry) return;
      const id = `${input.model?.providerID}/${input.model?.id}`;
      if (id !== entry.selected) throw fault('BindingFailure', 'Model binding changed before inference');
    },
    async checkTool(input, output) {
      let entry = await lookup(input.sessionID, input.directory || directory);
      if (!entry) {
        // Direct user-invoked read-only roles and their native Explore children
        // retain the same boundary, even without a managed delegation receipt.
        let id = input.sessionID;
        const seen = new Set();
        while (id && !seen.has(id) && seen.size < 32) {
          seen.add(id);
          const rows = await call('session', 'messages', sessionArgs(id, input.directory || directory));
          const assistant = rows.filter(m => m.info?.role === 'assistant').at(-1);
          const user = rows.filter(m => m.info?.role === 'user').at(-1);
          const assignment = (user?.parts || []).filter(p => p.type === 'text').map(p => p.text).join('\n');
          if (['researcher', 'review'].includes(assistant?.info.agent) || noWriteAssignment(assignment)) { entry = { readOnly: true }; break; }
          id = (await call('session', 'get', sessionArgs(id, input.directory || directory)))?.parentID;
        }
      }
      if (!entry) return;
      if (input.tool === 'task' && output.args?.background) throw fault('PermissionError', 'Untracked background children are not permitted in a managed attempt');
      if (input.tool === 'task' && output.args?.subagent_type !== 'explore') throw fault('PermissionError', 'Use delegate for dynamically selected helper execution, not a second native task');
      if (!entry.readOnly) return;
      if (readers.has(input.tool)) return;
      if (input.tool === 'task' && output.args?.subagent_type === 'explore' && !output.args?.command) return;
      if (input.tool === 'delegate' && output.args?.needsWrites !== true && roles.has(output.args?.role)) return;
      if (input.tool === 'content_index' && ['status', 'search', 'sources', 'unit', 'facts', 'meta'].includes(output.args?.operation)) return;
      // Do not claim edit:deny alone makes arbitrary shell/custom tools read-only.
      throw fault('PermissionError', 'Read-only delegated task cannot execute this tool. Return the required check to Build.');
    },
  };
}
