import { promises as fs } from "fs"
import path from "path"
import { spawn } from "child_process"
import { fileURLToPath } from "url"

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(scriptDir, "..")
const rContentRoot = path.join(projectRoot, "content", "R")
const HTML_WRAPPER_MARKER = "<!-- AUTO-GENERATED: html-link-wrapper -->"

function normalizeLineEndings(text) {
  return text.replace(/\r\n/g, "\n")
}

function convertRmdToQuartzMd(input) {
  const lines = normalizeLineEndings(input).split("\n")
  const out = []
  let insideRawHtmlFence = false

  for (const line of lines) {
    if (insideRawHtmlFence) {
      if (/^```+\s*$/.test(line)) {
        insideRawHtmlFence = false
      } else {
        out.push(line)
      }
      continue
    }

    if (/^```+\{=html\}\s*$/.test(line)) {
      insideRawHtmlFence = true
      continue
    }

    const chunkOpen = line.match(/^(```+)\{([A-Za-z][\w+-]*)([^}]*)\}\s*$/)
    if (chunkOpen) {
      const [, ticks, lang] = chunkOpen
      out.push(`${ticks}${lang.toLowerCase()}`)
      continue
    }

    out.push(line)
  }

  return `${out.join("\n").trimEnd()}\n`
}

function escapeYamlDoubleQuoted(text) {
  return text.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
}

function shouldOverwriteHtmlMd(existingContent) {
  return (
    existingContent.includes(HTML_WRAPPER_MARKER) ||
    existingContent.includes("AUTO-GENERATED: html-pdf-wrapper") ||
    existingContent.includes("Document exporte en PDF.") ||
    existingContent.includes("Document HTML (PDF non genere automatiquement).") ||
    existingContent.includes("<iframe src=\"./")
  )
}

function buildHtmlWrapper(htmlFilePath, hasPdf) {
  const fileName = path.basename(htmlFilePath)
  const pdfName = fileName.replace(/\.html$/i, ".pdf")
  const folderName = path.basename(path.dirname(htmlFilePath))
  const title = escapeYamlDoubleQuoted(folderName)

  const lines = [
    "---",
    `title: "${title}"`,
    "---",
    "",
    HTML_WRAPPER_MARKER,
    "",
    "Document rendu en HTML.",
    "",
    `- <a href="./${fileName}" target="_blank" rel="noopener noreferrer">Ouvrir la version HTML (${fileName})</a>`,
  ]

  if (hasPdf) {
    lines.push(`- [Telecharger le PDF (${pdfName})](./${pdfName})`)
  }

  lines.push("")
  return `${lines.join("\n")}\n`
}

function runCommand(command, args, timeoutMs = 1200000) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      stdio: ["ignore", "pipe", "pipe"],
      windowsHide: true,
      shell: false,
    })

    let stdout = ""
    let stderr = ""
    let timedOut = false

    const timer = setTimeout(() => {
      timedOut = true
      child.kill("SIGTERM")
    }, timeoutMs)

    child.stdout.on("data", (data) => {
      stdout += data.toString()
    })

    child.stderr.on("data", (data) => {
      stderr += data.toString()
    })

    child.on("error", (error) => {
      clearTimeout(timer)
      reject(error)
    })

    child.on("close", (code) => {
      clearTimeout(timer)
      if (timedOut) {
        reject(new Error(`Command timed out: ${command}`))
        return
      }
      if (code !== 0) {
        reject(new Error(`Command failed (${code}): ${command}\n${stderr || stdout}`))
        return
      }
      resolve({ stdout, stderr })
    })
  })
}

async function canRunCommand(command) {
  try {
    await runCommand(command, ["--version"], 15000)
    return true
  } catch {
    return false
  }
}

async function fileExists(filePath) {
  try {
    await fs.access(filePath)
    return true
  } catch {
    return false
  }
}

async function collectFiles(dir, predicate, acc = []) {
  const entries = await fs.readdir(dir, { withFileTypes: true })
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      await collectFiles(fullPath, predicate, acc)
      continue
    }

    if (entry.isFile() && predicate(entry.name)) {
      acc.push(fullPath)
    }
  }
  return acc
}

async function findRscriptExecutable() {
  const candidates = []

  if (process.env.RSCRIPT_PATH) {
    candidates.push(process.env.RSCRIPT_PATH)
  }
  candidates.push("Rscript")

  if (process.platform === "win32") {
    const baseDir = "C:\\Program Files\\R"
    if (await fileExists(baseDir)) {
      try {
        const dirs = await fs.readdir(baseDir, { withFileTypes: true })
        const versions = dirs.filter((d) => d.isDirectory()).map((d) => d.name).sort().reverse()
        for (const version of versions) {
          candidates.push(path.join(baseDir, version, "bin", "Rscript.exe"))
        }
      } catch {
        // ignore and continue with known candidates
      }
    }
  }

  for (const candidate of candidates) {
    if (await canRunCommand(candidate)) {
      return candidate
    }
  }

  return null
}

async function renderRmdWithRscript(rscriptPath) {
  const renderer = path.join(projectRoot, "scripts", "render-rmd.R")
  if (!(await fileExists(renderer))) {
    throw new Error(`R renderer script not found: ${renderer}`)
  }

  const { stdout } = await runCommand(rscriptPath, [renderer, projectRoot], 1800000)
  if (stdout.trim().length > 0) {
    console.log(stdout.trim())
  }
}

async function fallbackRmdConversion(rmdFiles) {
  let written = 0
  let unchanged = 0

  for (const srcPath of rmdFiles) {
    const destPath = srcPath.replace(/\.(Rmd|rmd)$/, ".md")
    const srcContent = await fs.readFile(srcPath, "utf8")
    const converted = convertRmdToQuartzMd(srcContent)

    const destExists = await fileExists(destPath)
    if (destExists) {
      const current = normalizeLineEndings(await fs.readFile(destPath, "utf8"))
      if (current === converted) {
        unchanged += 1
        continue
      }
    }

    await fs.writeFile(destPath, converted, "utf8")
    written += 1
    console.log(`[sync:rmd] Wrote ${path.relative(projectRoot, destPath)}`)
  }

  return { mode: "fallback", processed: rmdFiles.length, written, unchanged }
}

async function syncRmdToMd() {
  const rmdFiles = await collectFiles(rContentRoot, (name) => /\.(Rmd|rmd)$/.test(name))
  if (rmdFiles.length === 0) {
    return { mode: "none", processed: 0, written: 0, unchanged: 0 }
  }

  const rscript = await findRscriptExecutable()
  if (rscript) {
    try {
      console.log(`[sync:rmd] Using Rscript: ${rscript}`)
      await renderRmdWithRscript(rscript)
      return { mode: "rscript", processed: rmdFiles.length, written: rmdFiles.length, unchanged: 0 }
    } catch (error) {
      console.log(`[sync:rmd] R rendering failed, fallback to plain conversion. ${String(error)}`)
    }
  } else {
    console.log("[sync:rmd] Rscript not found. Using plain conversion fallback.")
  }

  return fallbackRmdConversion(rmdFiles)
}

async function syncHtmlWrappers() {
  const htmlFiles = await collectFiles(rContentRoot, (name) => /\.html$/i.test(name))
  let written = 0
  let skipped = 0

  for (const htmlPath of htmlFiles) {
    const upperRmd = htmlPath.replace(/\.html$/i, ".Rmd")
    const lowerRmd = htmlPath.replace(/\.html$/i, ".rmd")
    if ((await fileExists(upperRmd)) || (await fileExists(lowerRmd))) {
      continue
    }

    // If an index.md page already exists in this folder, avoid generating duplicate wrappers
    // for renamed HTML exports like td2.html/td3.html.
    const htmlName = path.basename(htmlPath).toLowerCase()
    if (htmlName !== "index.html") {
      const siblingIndexMd = path.join(path.dirname(htmlPath), "index.md")
      if (await fileExists(siblingIndexMd)) {
        continue
      }
    }

    const mdPath = htmlPath.replace(/\.html$/i, ".md")
    const hasPdf = await fileExists(htmlPath.replace(/\.html$/i, ".pdf"))
    const wrapper = buildHtmlWrapper(htmlPath, hasPdf)

    if (await fileExists(mdPath)) {
      const current = normalizeLineEndings(await fs.readFile(mdPath, "utf8"))
      if (current === wrapper) {
        continue
      }
      if (!shouldOverwriteHtmlMd(current)) {
        skipped += 1
        console.log(
          `[sync:html] Skipped ${path.relative(projectRoot, mdPath)} (custom file not managed by script).`,
        )
        continue
      }
    }

    await fs.writeFile(mdPath, wrapper, "utf8")
    written += 1
    console.log(`[sync:html] Wrote ${path.relative(projectRoot, mdPath)}`)
  }

  return { processed: htmlFiles.length, written, skipped }
}

async function syncContentForQuartz() {
  if (!(await fileExists(rContentRoot))) {
    console.log("[sync] No content/R directory found. Nothing to do.")
    return
  }

  const rmd = await syncRmdToMd()
  const html = await syncHtmlWrappers()

  if (rmd.mode === "rscript") {
    console.log(`[sync:rmd] Rendered ${rmd.processed} Rmd file(s) with R.`)
  } else if (rmd.mode === "fallback") {
    console.log(
      `[sync:rmd] Fallback conversion for ${rmd.processed} Rmd file(s): ${rmd.written} written, ${rmd.unchanged} unchanged.`,
    )
  } else {
    console.log("[sync:rmd] No Rmd files found.")
  }

  console.log(
    `[sync:html] Processed ${html.processed} HTML file(s): ${html.written} wrapper(s) written, ${html.skipped} skipped.`,
  )
}

try {
  await syncContentForQuartz()
} catch (error) {
  console.error("[sync] Failed:", error)
  process.exitCode = 1
}
