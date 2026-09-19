import { tool } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"
import { spawn } from "node:child_process"

type Ctx = { directory: string; worktree?: string }

function runCommand(cmd: string[], cwd: string): Promise<{ stdout: string; stderr: string; code: number }> {
  return new Promise((resolve, reject) => {
    const [file, ...args] = cmd
    const child = spawn(file, args, { cwd, stdio: ["ignore", "pipe", "pipe"] })
    let stdout = ""
    let stderr = ""
    if (child.stdout) child.stdout.on("data", (d) => { stdout += d.toString() })
    if (child.stderr) child.stderr.on("data", (d) => { stderr += d.toString() })
    child.on("error", (err) => reject(err))
    child.on("close", (code) => resolve({ stdout, stderr, code: code ?? 1 }))
  })
}

// The selector is an AI-delegation advisor only. User-invoked routes inherit
// the initiating model and must not be blocked by selector availability.

async function runSelector(psArgs: string[], cwd: string) {
  const candidates: string[][] = [
    ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", ...psArgs],
    ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", ...psArgs],
  ]
  let last = ""
  for (const cmd of candidates) {
    try {
      const { stdout, stderr, code } = await runCommand(cmd, cwd)
      if (code === 0 && stdout.trim()) return stdout.trim()
      last = stderr.trim() || stdout.trim() || `exit ${code}`
    } catch (err) {
      last = String(err)
    }
  }
  throw new Error(`Model selector failed: ${last}`)
}

export default tool({
  description:
    "AI-delegation advisor. Characterizes a bounded task, calls the deterministic evidence-aware model selector over cached roster/evidence/history, and returns a cheaper adequate route plus execution guidance. User-invoked routes inherit the initiating model and are never blocked by this advisor. Uses cached evidence only; never performs live web research.",
  args: {
    role: tool.schema
      .enum(["worker", "architect", "researcher", "review"])
      .describe("Delegation role: worker (bounded implementation), architect (hard tradeoff/plan), researcher (orientation/investigation), review (independent verification)"),
    task: tool.schema.string().describe("Brief bounded task description"),
    taskTypes: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe("Task types for the selector (e.g. debugging, bounded_feature, code_review)"),
    needsWrites: tool.schema.boolean().optional().describe("Task requires file writes"),
    needsTerminal: tool.schema.boolean().optional().describe("Task requires terminal access"),
    needsWeb: tool.schema.boolean().optional().describe("Task requires web access"),
    minimumContext: tool.schema
      .number()
      .int()
      .min(0)
      .optional()
      .describe("Minimum context tokens when genuinely known; otherwise omit"),
    needsDeepReasoning: tool.schema.boolean().optional().describe("Task needs deep/long-horizon reasoning"),
    highConsequenceIfWrong: tool.schema.boolean().optional().describe("High consequence for incorrect output"),
    needsModelDiversity: tool.schema.boolean().optional().describe("Need a different model from the reference (review independence)"),
    excludeModel: tool.schema.string().optional().describe("Exclude this model ID (diversity reference)"),
    currentModel: tool.schema.string().optional().describe("Calling session model ID (stay-put reference)"),
    expectedInputTokens: tool.schema
      .number()
      .int()
      .min(0)
      .optional()
      .describe("Estimated input tokens for quota-aware economics; omit when unknown"),
    expectedOutputTokens: tool.schema
      .number()
      .int()
      .min(0)
      .optional()
      .describe("Estimated output tokens for quota-aware economics; omit when unknown"),
    expectedCacheReadTokens: tool.schema
      .number()
      .int()
      .min(0)
      .optional()
      .describe("Estimated cache-read tokens for quota-aware economics; omit when unknown"),
    preferredCostClass: tool.schema
      .enum(["free", "any"])
      .optional()
      .describe("Cost preference; researcher defaults to free-biased"),
  },
  async execute(args, context: Ctx) {
    const root = path.resolve(context.worktree || context.directory)
    const locator = path.join(
      process.env.USERPROFILE || process.env.HOME || "",
      ".config",
      "opencode",
      "ai-toolkit-root.txt",
    )
    if (!fs.existsSync(locator)) {
      throw new Error("AI toolkit root locator is missing. Run the toolkit installer/bootstrap.")
    }
    const toolkitRoot = fs.readFileSync(locator, "utf8").trim()
    const script = path.join(toolkitRoot, "scripts", "select-model.ps1")
    if (!fs.existsSync(script)) throw new Error(`Model selector missing: ${script}`)

    const role = args.role || "worker"
    const psArgs: string[] = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script]
    const types = (args.taskTypes || []).filter((t) => t && t.trim())
    if (types.length > 0) {
      psArgs.push("-TaskType", types.join(","))
    }
    if (args.needsWrites) psArgs.push("-NeedsWrites", "$true")
    if (args.needsTerminal) psArgs.push("-NeedsTerminal", "$true")
    if (args.needsWeb) psArgs.push("-NeedsWeb", "$true")
    if (typeof args.minimumContext === "number" && args.minimumContext > 0) {
      psArgs.push("-NeedsLargeContextTokens", String(Math.floor(args.minimumContext)))
    }
    if (args.needsDeepReasoning) psArgs.push("-NeedsDeepReasoning", "$true")
    if (args.highConsequenceIfWrong) psArgs.push("-HighConsequence", "$true")
    if (args.needsModelDiversity) psArgs.push("-NeedsModelDiversity", "$true")
    if (args.excludeModel) psArgs.push("-ExcludeModel", args.excludeModel)
    if (args.currentModel) psArgs.push("-CurrentModel", args.currentModel)
    if (typeof args.expectedInputTokens === "number" && args.expectedInputTokens > 0) {
      psArgs.push("-ExpectedInputTokens", String(Math.floor(args.expectedInputTokens)))
    }
    if (typeof args.expectedOutputTokens === "number" && args.expectedOutputTokens > 0) {
      psArgs.push("-ExpectedOutputTokens", String(Math.floor(args.expectedOutputTokens)))
    }
    if (typeof args.expectedCacheReadTokens === "number" && args.expectedCacheReadTokens > 0) {
      psArgs.push("-ExpectedCacheReadTokens", String(Math.floor(args.expectedCacheReadTokens)))
    }
    psArgs.push("-Role", role)
    // AI-driven researcher delegation is free-biased.
    if (role === "researcher" || args.preferredCostClass === "free") {
      psArgs.push("-PreferredCostClass", "free")
    }

    const raw = await runSelector(psArgs, root)
    const sel = JSON.parse(raw)

    const freshness = String(sel.evidence_freshness || "UNPOPULATED")
    const stale =
      freshness === "stale" || freshness === "very stale" || freshness === "partially stale"
    const staleWarning = stale
      ? `Evidence is ${freshness}; selection used the cache per policy. Run the model-routing skill explicit refresh to refresh, but do not block delegation on it.`
      : null

    const selected: string = String(sel.selected_model || sel.recommended || "")

    const surface: string = String(sel.execution_surface || "")
    let recommendedAgent = role
    let canDelegate = true
    let needsSwitch = false
    if (surface === "combination") {
      recommendedAgent = "combination"
      canDelegate = true
    } else if (surface === "/models switch") {
      // Exact selected-model execution requires an explicit session switch.
      needsSwitch = true
    } else if (surface === "@architect chunk" && role === "worker") {
      // Report the evidence-preferred role honestly; its model still comes
      // from the invoking session unless explicitly switched.
      recommendedAgent = "architect"
      canDelegate = true
    } else if (surface === "@review" && role !== "review") {
      recommendedAgent = "review"
      canDelegate = true
    }

    const delegation = {
      role,
      task: args.task,
      selected_model: selected,
      surface: sel.surface || null,
      access: sel.access || null,
      adequacy: sel.adequacy || "unknown",
      reason_codes: sel.reason_codes || sel.why || [],
      fallback_model: sel.fallback_model || (sel.fallback && sel.fallback.id) || null,
      evidence_freshness: freshness,
      evidence_age_days: sel.evidence_age_days ?? null,
      evidence_readiness: sel.evidence_readiness || "UNPOPULATED",
      needs_research: !!sel.needs_research,
      stale_evidence_warning: staleWarning,
      pinned_agent_model: null,
      model_matches_pin: false,
      quota: sel.quota_state || null,
      consumption_estimate: sel.consumption_estimate || null,
      abort_verified: false,
      execution_guidance: {
        recommended_agent: recommendedAgent,
        can_delegate_to_agent: canDelegate,
        needs_models_switch: needsSwitch,
        suggested_models_switch: needsSwitch ? selected : null,
        execution_surface: surface,
        action: sel.action || null,
        phases: sel.phases || [],
      },
      fallback_policy:
        "On child failure: preserve partial changes for inspection, do not start a competing writer (child abort is unavailable in the installed OpenCode CLI — verified: session supports list/delete only), return control to the parent with the specific unresolved remainder. Record confirmed quota/rate-limit failures via refresh-quota.ps1 -BlockSurface so subsequent routing avoids the exhausted pool.",
      runtime_note:
        "User-invoked routes inherit the initiating model. AI-driven delegation may use the selector recommendation, but exact selected-model execution requires an explicit /models switch. Ordinary delegation never triggers web research.",
    }
    return JSON.stringify(delegation, null, 2)
  },
})
