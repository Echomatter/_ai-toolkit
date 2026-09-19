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

async function run(args: string[], cwd: string) {
  const candidates: string[][] = [["python", ...args]]
  const userProfile = process.env.USERPROFILE || ""
  const localAppData = process.env.LOCALAPPDATA || path.join(userProfile, "AppData", "Local")
  const programFiles = process.env.ProgramFiles || "C:\\Program Files"
  const pythonRoots = [
    path.join(localAppData, "Programs", "Python", "Python313", "python.exe"),
    path.join(localAppData, "Programs", "Python", "Python312", "python.exe"),
    path.join(programFiles, "Python313", "python.exe"),
    path.join(programFiles, "Python312", "python.exe"),
  ]
  for (const executable of pythonRoots) {
    if (fs.existsSync(executable)) candidates.push([executable, ...args])
  }
  const pyLauncher = path.join(process.env.WINDIR || "C:\\Windows", "py.exe")
  if (fs.existsSync(pyLauncher)) candidates.push([pyLauncher, "-3", ...args])
  candidates.push(["py", "-3", ...args], ["python3", ...args])
  let last = ""
  for (const cmd of candidates) {
    try {
      const { stdout, stderr, code } = await runCommand(cmd, cwd)
      if (code === 0) return stdout.trim()
      last = stderr.trim() || stdout.trim() || `exit ${code}`
    } catch (err) {
      last = String(err)
    }
  }
  throw new Error(`Project content indexer failed: ${last}`)
}

async function gitIndexPath(root: string) {
  try {
    const { stdout, code } = await runCommand(
      ["git", "rev-parse", "--git-path", "opencode-content-index.sqlite"],
      root,
    )
    const trimmed = stdout.trim()
    if (code === 0 && trimmed) return path.resolve(root, trimmed)
  } catch {}
  return path.join(root, ".content-index", "Project_Content_Index.sqlite")
}

export default tool({
  description:
    "Deterministic mixed-corpus project retrieval. Search/index docs, JSON/XML/CSV/XLSX/DOCX/PDF/ZIP content and derived facts. Use as a locator/completeness aid; verify governing source before authoritative claims or edits.",
  args: {
    operation: tool.schema
      .enum(["status", "search", "sources", "unit", "facts", "meta", "rebuild"])
      .describe("Index operation"),
    query: tool.schema.string().optional().describe("Search text for operation=search"),
    phrase: tool.schema.boolean().optional().describe("Treat search query as an exact phrase"),
    source: tool.schema.string().optional().describe("Substring source-path filter"),
    role: tool.schema.string().optional().describe("Exact inferred source role filter"),
    status: tool.schema.string().optional().describe("Exact inferred source status filter"),
    unit: tool.schema.number().int().positive().optional().describe("Unit number for operation=unit"),
    family: tool.schema.string().optional().describe("Fact family filter"),
    kind: tool.schema
      .enum(["structured", "label_value", "markdown_table", "special_field", "special_label_value", "special_match"])
      .optional()
      .describe("Fact kind filter"),
    label: tool.schema.string().optional().describe("Fact label filter"),
    stats: tool.schema.boolean().optional().describe("Return aggregate fact statistics"),
    facts: tool.schema.enum(["none", "general", "special", "both"]).optional().describe("Fact mode for rebuild"),
    specialFacts: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe("Focused rebuild rules as FAMILY=REGEX"),
    ocr: tool.schema.boolean().optional().describe("Use optional OCR fallback for nearly blank PDF pages"),
    limit: tool.schema.number().int().min(1).max(200).optional().describe("Maximum returned rows"),
  },
  async execute(args, context: Ctx) {
    if (args.operation === 'rebuild') {
      await (context as any).ask({ permission: 'edit', patterns: ['content-index database'], always: [], metadata: { operation: 'rebuild' } })
    }
    const root = path.resolve(context.worktree || context.directory)
    const locator = path.join(
      process.env.XDG_CONFIG_HOME || path.join(process.env.USERPROFILE || process.env.HOME || "", ".config"),
      "opencode",
      "tokenomics-root.txt",
    )
    if (!fs.existsSync(locator)) {
      throw new Error("Tokenomics toolkit root locator is missing. Run the toolkit installer/bootstrap.")
    }
    const toolkitRoot = fs.readFileSync(locator, "utf8").trim()
    const script = path.join(toolkitRoot, "tools", "Project_Content_Indexer.py")
    if (!fs.existsSync(script)) throw new Error(`Project content indexer missing: ${script}`)
    const db = await gitIndexPath(root)

    const cli: string[] = [script, "--db", db]
    switch (args.operation) {
      case "status":
        cli.push("status", "--root", root)
        break
      case "rebuild":
        cli.push("rebuild", "--root", root, "--facts", args.facts || "none")
        for (const spec of args.specialFacts || []) cli.push("--special-fact", spec)
        if (args.ocr) cli.push("--ocr")
        break
      case "search":
        if (!args.query) throw new Error("operation=search requires query")
        cli.push("search", args.query)
        if (args.phrase) cli.push("--phrase")
        if (args.source) cli.push("--source", args.source)
        if (args.role) cli.push("--role", args.role)
        if (args.status) cli.push("--status", args.status)
        cli.push("--limit", String(args.limit || 20))
        break
      case "sources":
        cli.push("sources")
        if (args.source) cli.push("--source", args.source)
        if (args.role) cli.push("--role", args.role)
        if (args.status) cli.push("--status", args.status)
        break
      case "unit":
        if (!args.source || !args.unit) throw new Error("operation=unit requires source and unit")
        cli.push("unit", "--source", args.source, "--unit", String(args.unit))
        break
      case "facts":
        cli.push("facts")
        if (args.family) cli.push("--family", args.family)
        if (args.source) cli.push("--source", args.source)
        if (args.kind) cli.push("--kind", args.kind)
        if (args.label) cli.push("--label", args.label)
        if (args.stats) cli.push("--stats")
        cli.push("--limit", String(args.limit || 100))
        break
      case "meta":
        cli.push("meta")
        break
    }
    return await run(cli, root)
  },
})
