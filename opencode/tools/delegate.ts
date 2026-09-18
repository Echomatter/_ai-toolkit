import { tool } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"

type Ctx = { directory: string; worktree?: string }

// Phase 0 gate: OpenCode agents use statically pinned models. A custom tool
// cannot spawn a child session with an arbitrary per-invocation model. This
// tool therefore implements the selector/delegation interface cleanly: it runs
// the deterministic evidence-aware selector and returns the selected model
// plus honest execution guidance. True runtime model injection (if OpenCode
// ever supports it) plugs in at the ADAPTER POINT below without changing
// the selection contract.

async function runSelector(psArgs: string[], cwd: string) {
  const candidates: string[][] = [
    ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", ...psArgs],
    ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", ...psArgs],
  ]
  let last = ""
  for (const cmd of candidates) {
    try {
      const proc = Bun.spawn(cmd, { cwd, stdout: "pipe", stderr: "pipe" })
      const [stdout, stderr, code] = await Promise.all([
        new Response(proc.stdout).text(),
        new Response(proc.stderr).text(),
        proc.exited,
      ])
      if (code === 0 && stdout.trim()) return stdout.trim()
      last = stderr.trim() || stdout.trim() || `exit ${code}`
    } catch (err) {
      last = String(err)
    }
  }
  throw new Error(`Model selector failed: ${last}`)
}

function readPinnedModel(toolkitRoot: string, role: string): string | null {
  try {
    const statePath = path.join(toolkitRoot, "routing", "state.json")
    if (!fs.existsSync(statePath)) return null
    const state = JSON.parse(fs.readFileSync(statePath, "utf8"))
    if (role === "worker" && state.worker) return String(state.worker)
    if (role === "review" && state.review) return String(state.review)
    if (role === "index" && state.index) return String(state.index)
    return null
  } catch {
    return null
  }
}

export default tool({
  description:
    "Dynamic delegation advisor. Characterizes a bounded task, calls the deterministic evidence-aware model selector over cached roster/evidence/history, and returns the selected model plus execution guidance. Uses cached evidence only; never performs live web research. OpenCode child agents use statically pinned models, so the result also reports whether the selected model matches the pinned agent (adapter point for future runtime model injection).",
  args: {
    role: tool.schema
      .enum(["worker", "review", "index"])
      .describe("Delegation role: worker (generic implementation), review (independent verification), index (free retrieval)"),
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
    preferredCostClass: tool.schema
      .enum(["free", "any"])
      .optional()
      .describe("Cost preference; index defaults to free-biased"),
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
    psArgs.push("-Role", role)
    // Index is always free-biased; other roles honor an explicit free preference.
    if (role === "index" || args.preferredCostClass === "free") {
      psArgs.push("-PreferredCostClass", "free")
    }

    const raw = await runSelector(psArgs, root)
    const sel = JSON.parse(raw)

    const freshness = String(sel.evidence_freshness || "UNPOPULATED")
    const stale =
      freshness === "stale" || freshness === "very stale" || freshness === "partially stale"
    const staleWarning = stale
      ? `Evidence is ${freshness}; selection used the cache per policy. Run /refresh-model-evidence to refresh, but do not block delegation on it.`
      : null

    const pinned = readPinnedModel(toolkitRoot, role)
    const selected: string = String(sel.selected_model || sel.recommended || "")
    const modelMatchesPin = !!(pinned && selected && pinned === selected)

    const surface: string = String(sel.execution_surface || "")
    let recommendedAgent = role
    let canDelegate = true
    let needsSwitch = false
    if (surface === "combination") {
      recommendedAgent = "combination"
      canDelegate = true
    } else if (surface === "/models switch") {
      // Honest adapter behavior: the selected model is not pinned to the role
      // agent, so a session switch is the only way to run exactly that model.
      // Delegation to the pinned role agent remains possible as a fallback.
      needsSwitch = true
      canDelegate = modelMatchesPin
      if (!pinned) canDelegate = false
    } else if (surface === "@deep chunk" && role === "worker") {
      // Selector evidence favors the Deep-pinned model for this worker task.
      // Keep the worker role but report the evidence-preferred agent honestly.
      recommendedAgent = "deep"
      canDelegate = true
    } else if (surface === "@review" && role !== "review") {
      recommendedAgent = "review"
      canDelegate = true
    }

    // ADAPTER POINT for true runtime model injection (Phase 0 gate):
    // if OpenCode ever supports per-invocation child-session models, replace
    // the static `recommendedAgent` handoff with a spawn call here using
    // `selected`, keeping this selection contract unchanged.
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
      pinned_agent_model: pinned,
      model_matches_pin: modelMatchesPin,
      execution_guidance: {
        recommended_agent: recommendedAgent,
        can_delegate_to_agent: canDelegate,
        needs_models_switch: needsSwitch,
        suggested_models_switch: needsSwitch ? selected : null,
        execution_surface: surface,
        action: sel.action || null,
        phases: sel.phases || [],
      },
      runtime_note:
        "OpenCode child agents run their statically pinned models. Delegate to the recommended agent; use /models for a session switch only when needs_models_switch is true. Ordinary delegation never triggers web research.",
    }
    return JSON.stringify(delegation, null, 2)
  },
})
