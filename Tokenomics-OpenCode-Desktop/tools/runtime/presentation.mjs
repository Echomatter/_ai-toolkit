// OpenCode Desktop 1.18.31 only renders child-session navigation for `task`.
// Adapt the persisted display of a REAL delegate call, never run another task.
// Restore the original tool/input before history is sent to a model.
const marker = 'tokenomics_delegate_display';
const savedDisplay = part => part?.state?.metadata?.[marker] || part?.state?.metadata?.ai_toolkit_delegate_display;
export function completionMetadata(receipt, args) {
  const attempt = receipt.attempts?.at(-1);
  const metadata = { sessionId: attempt?.child_session, parentSessionId: receipt.parent_session,
    role: receipt.role, selected_model: attempt?.selected_model, task_id: receipt.task_id,
    tokenomics_activity: receipt.activity };
  // The host replaces metadata on completion but retains the displayed tool/input.
  // Carry restoration data in the returned result as well as the running updates.
  return attempt?.child_session ? { ...metadata, [marker]: { version: 1,
    original_tool: 'delegate', original_input: args, original_metadata: metadata,
    selected_model: attempt.selected_model, source: 'actual_sdk_child' } } : metadata;
}
export function taskCard(part) {
  if (part?.type !== 'tool' || part.tool !== 'delegate') return null;
  const state = part.state;
  if (!state || !['running', 'completed', 'error'].includes(state.status)) return null;
  if (state.metadata?.tokenomics_display_disabled === true || state.metadata?.ai_toolkit_display_disabled === true) return null;
  let receipt;
  if (state.status === 'completed') {
    try { receipt = JSON.parse(state.output); } catch { return null; }
    if (receipt.parent_session !== part.sessionID) return null;
  }
  const attempt = receipt?.attempts?.at(-1);
  const meta = state.metadata || {};
  const sessionId = attempt?.child_session || meta.sessionId;
  const role = receipt?.role || meta.role;
  const selected = attempt?.selected_model || meta.selected_model;
  if (!sessionId || !selected || !['worker','architect','researcher','review'].includes(role)) return null;
  return { ...part, tool: 'task', state: { ...state,
    input: { subagent_type: role, description: `${selected}${meta.tokenomics_activity?.label ? ` · ${meta.tokenomics_activity.label}` : ''}`, prompt: state.input?.task || '' },
    metadata: { ...meta, sessionId, parentSessionId: part.sessionID,
      [marker]: { version: 1, original_tool: 'delegate', original_input: state.input,
        original_metadata: meta, selected_model: selected, source: 'actual_sdk_child' } },
  } };
}
export function restoreDelegateTools(messages) {
  for (const message of messages) for (const part of message.parts || []) {
    const saved = savedDisplay(part);
    if (part.type !== 'tool' || part.tool !== 'task' || saved?.version !== 1 || saved.original_tool !== 'delegate') continue;
    part.tool = 'delegate';
    part.state.input = saved.original_input;
    part.state.metadata = saved.original_metadata;
  }
}
export function createPresenter({ client, directory }) {
  const unwrap = r => { if(r?.error) throw new Error('Display update failed'); return r?.data ?? r; };
  async function present(part) {
    const card = taskCard(part);
    if (!card) return false;
    const child = unwrap(await client.session.get({path:{id:card.state.metadata.sessionId},query:{directory},signal:AbortSignal.timeout(3000)}));
    const selected=card.state.metadata[marker].selected_model;
    if (child.parentID !== part.sessionID || (child.metadata?.tokenomics || child.metadata?.ai_toolkit)?.selected !== selected) return false;
    // Same part and callID: no synthetic inference, duplicate tool call or child.
    const args={path:{sessionID:part.sessionID,messageID:part.messageID,partID:part.id},query:{directory},body:card,signal:AbortSignal.timeout(3000)};
    // The injected v1 SDK omits Part; use its existing authenticated transport
    // for the documented endpoint (v2 exposes it as part.update).
    const result=client.part?.update ? await client.part.update(args) :
      await client._client.patch({...args,url:'/session/{sessionID}/message/{messageID}/part/{partID}',headers:{'Content-Type':'application/json'}});
    unwrap(result);
    return true;
  }
  // OpenCode 1.18.31 bridges plugin ask(), but exposes metadata() as an
  // unevaluated host Effect. Publish through the same authenticated SDK instead.
  present.metadata = async (ctx, update) => {
    const message = unwrap(await client.session.message({path:{id:ctx.sessionID,messageID:ctx.messageID},query:{directory},signal:AbortSignal.timeout(3000)}));
    const candidates = (message.parts || []).filter(p => p.type === 'tool' &&
      ['running','pending'].includes(p.state?.status) && (ctx.callID ? p.callID === ctx.callID :
        p.tool === 'delegate' || savedDisplay(p)?.original_tool === 'delegate'));
    if (candidates.length !== 1) return false;
    const original = structuredClone(candidates[0]);
    restoreDelegateTools([{parts:[original]}]);
    if (original.tool !== 'delegate' || original.sessionID !== ctx.sessionID) return false;
    original.state = { ...original.state, status: 'running', title: update.title ?? original.state.title,
      metadata: { ...original.state.metadata, ...update.metadata } };
    return present(original);
  };
  return present;
}
