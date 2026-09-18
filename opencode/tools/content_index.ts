import { tool } from "@opencode-ai/plugin"
import path from "path"

function homeDir() {
  return process.env.USERPROFILE || process.env.HOME || ""
}

async function toolkitRoot() {
  const locator = path.join(homeDir(), ".config", "opencode", "ai-toolkit-root.txt")
  const text = await Bun.file(locator).text()
  return text.trim()
}

function addFlag(argv: string[], flag: string, value?: string | number | boolean | null) {
  if (value === undefined || value === null || value === "") return
  if (typeof value === "boolean") {
    if (value) argv.push(flag)
    return
  }
  argv.push(flag, String(value))
}

export default tool({
  description:
    "Search, inspect, or rebuild the deterministic mixed-content project index. Use for exhaustive/cross-document retrieval; verify governing source files before authoritative claims.",
  args: {
    operation: tool.schema
      .string()
      .describe("status | search | sources | unit | facts | meta | rebuild"),
    query: tool.schema.string().optional().describe("FTS query for search"),
    phrase: tool.schema.boolean().optional().describe("Treat search query as an exact phrase"),
    source: tool.schema.string().optional().describe("Source/virtual-path substring filter"),
    role: tool.schema.string().optional().describe("Exact inferred source role filter"),
    status: tool.schema.string().optional().describe("Exact inferred source status filter"),
    unit: tool.schema.number().optional().describe("Unit number for operation=unit"),
    family: tool.schema.string().optional().describe("Fact family filter"),
    kind: tool.schema.string().optional().describe("Fact kind filter"),
    label: tool.schema.string().optional().describe("Fact label filter"),
    stats: tool.schema.boolean().optional().describe("Return aggregate fact statistics"),
    limit: tool.schema.number().optional().describe("Result limit"),
    facts: tool.schema
      .string()
      .optional()
      .describe("Rebuild fact mode: none | general | special | both"),
    special_fact: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe("Repeated FAMILY=REGEX rules for focused fact overlays"),
    ocr: tool.schema.boolean().optional().describe("OCR nearly blank PDF pages during rebuild"),
  },
  async execute(args, context) {
    const root = await toolkitRoot()
    const script = path.join(root, "tools", "Project_Content_Indexer.py")
    const op = args.operation.toLowerCase().trim()
    const allowed = new Set(["status", "search", "sources", "unit", "facts", "meta", "rebuild"])
    if (!allowed.has(op)) throw new Error(`Unsupported content-index operation: ${args.operation}`)

    const argv = [script, op]
    if (op === "status" || op === "rebuild") addFlag(argv, "--root", context.worktree)

    if (op === "search") {
      if (!args.query) throw new Error("content_index search requires query")
      argv.push(args.query)
      addFlag(argv, "--phrase", args.phrase)
    }

    if (op === "unit") {
      if (!args.source || args.unit === undefined) {
        throw new Error("content_index unit requires source and unit")
      }
      addFlag(argv, "--source", args.source)
      addFlag(argv, "--unit", args.unit)
    } else {
      addFlag(argv, "--source", args.source)
    }

    if (op === "search" || op === "sources") {
      addFlag(argv, "--role", args.role)
      addFlag(argv, "--status", args.status)
    }

    if (op === "facts") {
      addFlag(argv, "--family", args.family)
      addFlag(argv, "--kind", args.kind)
      addFlag(argv, "--label", args.label)
      addFlag(argv, "--stats", args.stats)
    }

    if (op === "search" || op === "facts") addFlag(argv, "--limit", args.limit)

    if (op === "rebuild") {
      addFlag(argv, "--facts", args.facts || "none")
      for (const rule of args.special_fact || []) addFlag(argv, "--special-fact", rule)
      addFlag(argv, "--ocr", args.ocr)
    }

    const python = process.platform === "win32" ? "python" : "python3"
    const child = Bun.spawn([python, ...argv], {
      cwd: context.worktree,
      stdout: "pipe",
      stderr: "pipe",
    })
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(child.stdout).text(),
      new Response(child.stderr).text(),
      child.exited,
    ])

    if (exitCode !== 0) {
      throw new Error((stderr || stdout || `content index exited ${exitCode}`).trim())
    }
    return stdout.trim() || stderr.trim()
  },
})
