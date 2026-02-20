args <- commandArgs(trailingOnly = TRUE)

project_root <- if (length(args) >= 1) {
  normalizePath(args[1], winslash = "/", mustWork = TRUE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

content_root <- file.path(project_root, "content", "R")

if (!dir.exists(content_root)) {
  cat("[render:rmd] No content/R directory found.\n")
  quit(save = "no", status = 0)
}

if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  stop("Package 'rmarkdown' is required. Install it with install.packages('rmarkdown').")
}

if (!requireNamespace("knitr", quietly = TRUE)) {
  stop("Package 'knitr' is required. Install it with install.packages('knitr').")
}

rmd_files <- list.files(
  content_root,
  pattern = "\\.[Rr]md$",
  recursive = TRUE,
  full.names = TRUE
)

if (length(rmd_files) == 0) {
  cat("[render:rmd] No Rmd files found.\n")
  quit(save = "no", status = 0)
}

render_one <- function(input_file) {
  output_dir <- dirname(input_file)
  stem <- tools::file_path_sans_ext(basename(input_file))
  md_output <- paste0(stem, ".md")
  html_output <- paste0(stem, ".html")

  cat(sprintf("[render:rmd] %s -> %s\n", input_file, file.path(output_dir, md_output)))
  rmarkdown::render(
    input = input_file,
    output_format = rmarkdown::github_document(
      html_preview = FALSE,
      preserve_yaml = TRUE
    ),
    output_file = md_output,
    output_dir = output_dir,
    clean = TRUE,
    quiet = TRUE,
    envir = new.env(parent = globalenv())
  )

  cat(sprintf("[render:rmd] %s -> %s\n", input_file, file.path(output_dir, html_output)))
  rmarkdown::render(
    input = input_file,
    output_format = rmarkdown::html_document(self_contained = TRUE),
    output_file = html_output,
    output_dir = output_dir,
    clean = TRUE,
    quiet = TRUE,
    envir = new.env(parent = globalenv())
  )
}

for (input_file in rmd_files) {
  tryCatch(
    render_one(input_file),
    error = function(e) {
      stop(sprintf("Failed rendering %s: %s", input_file, conditionMessage(e)))
    }
  )
}

cat(sprintf("[render:rmd] Rendered %d Rmd file(s).\n", length(rmd_files)))
