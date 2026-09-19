import { tool, type Plugin } from '@opencode-ai/plugin'
import fs from 'node:fs'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

// Registered once as the existing `delegate` tool. Use OpenCode's own authenticated
// client, permission prompts and child sessions; no second server or global pin.
const DelegationPlugin: Plugin = async ({ client, directory }) => {
  const base = process.env.XDG_CONFIG_HOME || path.join(process.env.USERPROFILE || process.env.HOME || '', '.config')
  const locator = path.join(base, 'opencode', 'ai-toolkit-root.txt')
  const toolkitRoot = fs.readFileSync(locator, 'utf8').trim()
  const { createBridge } = await import(pathToFileURL(path.join(toolkitRoot, 'tools/runtime/bridge.mjs')).href)
  const { createDelegator } = await import(pathToFileURL(path.join(toolkitRoot, 'tools/runtime/delegation.mjs')).href)
  const delegate = createDelegator({ client, toolkitRoot, directory, ...createBridge(toolkitRoot) })
  return {
    tool: {
      delegate: tool({
        description: 'Execute one bounded child on the selected provider/model. Returns actual session/model evidence. Does not switch the parent. Do not invoke another agent after this tool: it already runs the child.',
        args: {
          role: tool.schema.enum(['worker', 'architect', 'researcher', 'review']),
          task: tool.schema.string().min(1).describe('Complete bounded assignment including exclusions and relevant orientation handoff'),
          userTaskId: tool.schema.string().optional().describe('Stable user task ID shared by related child attempts and review'),
          taskTypes: tool.schema.array(tool.schema.string()).optional(),
          needsWrites: tool.schema.boolean().optional().describe('True only for authorized source edits. Defaults to read-only.'),
          needsTerminal: tool.schema.boolean().optional(),
          needsWeb: tool.schema.boolean().optional(),
          minimumContext: tool.schema.number().int().min(0).optional(),
          needsDeepReasoning: tool.schema.boolean().optional(),
          highConsequenceIfWrong: tool.schema.boolean().optional(),
          needsModelDiversity: tool.schema.boolean().optional(),
          excludeModel: tool.schema.string().optional(),
          expectedInputTokens: tool.schema.number().int().min(0).optional(),
          expectedOutputTokens: tool.schema.number().int().min(0).optional(),
          expectedCacheReadTokens: tool.schema.number().int().min(0).optional(),
          preferredCostClass: tool.schema.enum(['free', 'any']).optional(),
          variant: tool.schema.string().optional().describe('A supported reasoning variant for this child only, when explicitly required'),
        },
        async execute(args, context) {
          return JSON.stringify(await delegate.execute(args, context), null, 2)
        },
      }),
    },
    'chat.params': async input => { await delegate.checkModel(input) },
    'tool.execute.before': async (input, output) => { await delegate.checkTool(input, output) },
  }
}
export default DelegationPlugin
