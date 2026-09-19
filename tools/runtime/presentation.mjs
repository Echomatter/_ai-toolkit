// OpenCode Desktop 1.18.31 only renders child-session navigation for `task`.
// Adapt the persisted display of a REAL delegate call, never run another task.
// Restore the original tool/input before history is sent to a model.
const marker = 'ai_toolkit_delegate_display';
export function taskCard(part) {
  if (part?.type !== 'tool' || part.tool !== 'delegate') return null;
  const state = part.state;
  if (!state || !['running', 'completed', 'error'].includes(state.status)) return null;
  if (state.metadata?.ai_toolkit_display_disabled === true) return null;
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
    input: { subagent_type: role, description: `delegate · ${selected}`, prompt: state.input?.task || '' },
    metadata: { ...meta, sessionId, parentSessionId: part.sessionID,
      [marker]: { version: 1, original_tool: 'delegate', original_input: state.input,
        original_metadata: meta, selected_model: selected, source: 'actual_sdk_child' } },
  } };
}
export function restoreDelegateTools(messages) {
  for (const message of messages) for (const part of message.parts || []) {
    const saved = part.state?.metadata?.[marker];
    if (part.type !== 'tool' || part.tool !== 'task' || saved?.version !== 1 || saved.original_tool !== 'delegate') continue;
    part.tool = 'delegate';
    part.state.input = saved.original_input;
    part.state.metadata = saved.original_metadata;
  }
}
export function createPresenter({ client, directory }) {
  const unwrap = r => { if(r?.error) throw new Error('Display update failed'); return r?.data ?? r; };
  return async function present(part) {
    const card = taskCard(part);
    if (!card) return false;
    const child = unwrap(await client.session.get({path:{id:card.state.metadata.sessionId},query:{directory}}));
    const selected=card.state.metadata[marker].selected_model;
    if (child.parentID !== part.sessionID || child.metadata?.ai_toolkit?.selected !== selected) return false;
    // Same part and callID: no synthetic inference, duplicate tool call or child.
    const args={path:{sessionID:part.sessionID,messageID:part.messageID,partID:part.id},query:{directory},body:card};
    // The injected v1 SDK omits Part; use its existing authenticated transport
    // for the documented endpoint (v2 exposes it as part.update).
    const result=client.part?.update ? await client.part.update(args) :
      await client._client.patch({...args,url:'/session/{sessionID}/message/{messageID}/part/{partID}',headers:{'Content-Type':'application/json'}});
    unwrap(result);
    return true;
  };
}
