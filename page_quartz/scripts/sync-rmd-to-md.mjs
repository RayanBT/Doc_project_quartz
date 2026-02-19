import { promises as fs } from "fs"
import path from "path"
import { fileURLToPath } from "url"

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(scriptDir, "..")
const rContentRoot = path.join(projectRoot, "content", "R")

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

function buildHtmlWrapper(htmlFilePath) {
  const fileName = path.basename(htmlFilePath)
  const folderName = path.basename(path.dirname(htmlFilePath))
  const title = escapeYamlDoubleQuoted(folderName)

  return `---
title: "${title}"
---

Document fourni en HTML.

- [Ouvrir ${fileName}](./${fileName})

<iframe src="./${fileName}" style="width:100%;min-height:85vh;border:1px solid #ddd;border-radius:8px;" loading="lazy"></iframe>
`
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

async function fileExists(filePath) {
  try {
    await fs.access(filePath)
    return true
  } catch {
    return false
  }
}

async function syncRmdToMd() {
  const rmdFiles = await collectFiles(rContentRoot, (name) => /\.(Rmd|rmd)$/.test(name))
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

  return { processed: rmdFiles.length, written, unchanged }
}

async function syncHtmlToMd() {
  const htmlFiles = await collectFiles(rContentRoot, (name) => /\.html$/i.test(name))
  let written = 0
  let skipped = 0

  for (const htmlPath of htmlFiles) {
    const destPath = htmlPath.replace(/\.html$/i, ".md")
    if (await fileExists(destPath)) {
      skipped += 1
      continue
    }

    const wrapper = buildHtmlWrapper(htmlPath)
    await fs.writeFile(destPath, wrapper, "utf8")
    written += 1
    console.log(`[sync:html] Wrote ${path.relative(projectRoot, destPath)}`)
  }

  return { processed: htmlFiles.length, written, skipped }
}

async function syncContentForQuartz() {
  if (!(await fileExists(rContentRoot))) {
    console.log("[sync] No content/R directory found. Nothing to do.")
    return
  }

  const rmd = await syncRmdToMd()
  const html = await syncHtmlToMd()

  console.log(`[sync:rmd] Processed ${rmd.processed} Rmd file(s): ${rmd.written} written, ${rmd.unchanged} unchanged.`)
  console.log(`[sync:html] Processed ${html.processed} HTML file(s): ${html.written} wrapper(s) written, ${html.skipped} skipped.`)
}

try {
  await syncContentForQuartz()
} catch (error) {
  console.error("[sync] Failed:", error)
  process.exitCode = 1
}
