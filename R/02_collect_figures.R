### 02_collect_figures.R
###
### Vendors goodness-of-fit SVGs from the (Dropbox-symlinked) NH SAS and
### WIDA_NH Goodness_of_Fit trees into Figures/gof/ using clean filenames.
###
### NH SAS:   ELA_2025_2026_cohort_g7.svg
### WIDA:     wida_2026_baseline_g4.svg
###
###   Rscript R/02_collect_figures.R
###
###   NH_GOF_ROOT=... WIDA_NH_GOF_ROOT=... Rscript ...

suppressPackageStartupMessages({
  library(data.table)
})

this_dir <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_arg)) dirname(normalizePath(file_arg)) else getwd()
}, error = function(e) getwd())
PROJECT_ROOT <- normalizePath(file.path(this_dir, ".."))

NH_GOF_ROOT <- Sys.getenv(
  "NH_GOF_ROOT",
  "/Users/conet/GitHub/CenterForAssessment/New_Hampshire/master/Goodness_of_Fit"
)
WIDA_GOF_ROOT <- Sys.getenv(
  "WIDA_NH_GOF_ROOT",
  "/Users/conet/GitHub/CenterForAssessment/WIDA_NH/master/Goodness_of_Fit"
)
DEST_ROOT <- file.path(PROJECT_ROOT, "Figures", "gof")

## Source directory prefix -> dest filename token. NH GoF files are named
## 2025_2026_READING_4;... so the parse token is the source content area.
## Directory prefix -> dest filename token. Source SVG stems use READING
## and MATH (not MATHEMATICS), e.g. 2025_2026_MATH_4;...
NH_CONTENT <- c(READING = "ELA", MATHEMATICS = "MATH")
NH_PARSE_TOKEN <- c(READING = "READING", MATHEMATICS = "MATH")
NH_YEARS <- c("2022_2023", "2023_2024", "2024_2025", "2025_2026")
NORMS <- c(cohort = "", baseline = ".BASELINE")

if (dir.exists(DEST_ROOT)) unlink(list.files(DEST_ROOT, full.names = TRUE), recursive = TRUE)
dir.create(DEST_ROOT, showWarnings = FALSE, recursive = TRUE)

manifest <- list()

copy_keep_longest <- function(svgs, year, src_token, dest_token, dest_prefix = NULL) {
  if (!length(svgs)) return(invisible(NULL))
  lead  <- sub(";.*$", "", basename(svgs))
  grade <- sub(paste0("^", year, "_", src_token, "_"), "", lead)
  n_seg <- lengths(regmatches(basename(svgs), gregexpr(";", basename(svgs))))
  keep  <- vapply(split(seq_along(grade), grade), function(idx) {
    idx[which.max(n_seg[idx])]
  }, integer(1))
  list(svgs = svgs[keep], grade = grade[keep], dest_token = dest_token,
       dest_prefix = dest_prefix)
}

## ---- NH SAS ---------------------------------------------------------------
if (dir.exists(NH_GOF_ROOT)) {
  for (content in names(NH_CONTENT)) {
    dest_token <- NH_CONTENT[[content]]
    for (year in NH_YEARS) {
      for (norm_i in seq_along(NORMS)) {
        norm_label  <- names(NORMS)[norm_i]
        norm_suffix <- NORMS[[norm_i]]
        src_dir <- file.path(NH_GOF_ROOT, paste0(content, ".", year, norm_suffix))
        if (!dir.exists(src_dir)) next
        svgs <- list.files(src_dir, pattern = "\\.svg$", full.names = TRUE)
        picked <- copy_keep_longest(svgs, year, NH_PARSE_TOKEN[[content]], dest_token)
        if (is.null(picked)) next
        for (i in seq_along(picked$svgs)) {
          g <- picked$grade[i]
          clean <- paste0(dest_token, "_", year, "_", norm_label, "_g", g, ".svg")
          dest  <- file.path(DEST_ROOT, clean)
          if (file.copy(picked$svgs[i], dest, overwrite = TRUE)) {
            manifest[[length(manifest) + 1L]] <- data.table(
              content_area = content,
              token        = dest_token,
              year         = year,
              norm         = norm_label,
              grade        = g,
              file         = clean,
              rel_path     = file.path("Figures", "gof", clean),
              source_file  = basename(picked$svgs[i]),
              program      = "NH SAS"
            )
          }
        }
      }
    }
  }
} else {
  warning("NH GoF root not found: ", NH_GOF_ROOT)
}

## ---- WIDA ACCESS ----------------------------------------------------------
if (dir.exists(WIDA_GOF_ROOT)) {
  wida_year <- "2026"
  for (norm_i in seq_along(NORMS)) {
    norm_label  <- names(NORMS)[norm_i]
    norm_suffix <- NORMS[[norm_i]]
    src_dir <- file.path(WIDA_GOF_ROOT, paste0("READING.", wida_year, norm_suffix))
    if (!dir.exists(src_dir)) next
    svgs <- list.files(src_dir, pattern = "\\.svg$", full.names = TRUE)
    picked <- copy_keep_longest(svgs, wida_year, "READING", "WIDA")
    if (is.null(picked)) next
    for (i in seq_along(picked$svgs)) {
      g <- picked$grade[i]
      clean <- paste0("wida_", wida_year, "_", norm_label, "_g", g, ".svg")
      dest  <- file.path(DEST_ROOT, clean)
      if (file.copy(picked$svgs[i], dest, overwrite = TRUE)) {
        manifest[[length(manifest) + 1L]] <- data.table(
          content_area = "READING",
          token        = "WIDA",
          year         = wida_year,
          norm         = norm_label,
          grade        = g,
          file         = clean,
          rel_path     = file.path("Figures", "gof", clean),
          source_file  = basename(picked$svgs[i]),
          program      = "WIDA"
        )
      }
    }
  }
} else {
  warning("WIDA GoF root not found: ", WIDA_GOF_ROOT)
}

if (!length(manifest)) stop("No GoF SVGs copied; check NH_GOF_ROOT / WIDA_NH_GOF_ROOT")

manifest_dt <- rbindlist(manifest)
setorder(manifest_dt, program, content_area, year, norm, grade)
fwrite(manifest_dt, file.path(DEST_ROOT, "manifest.csv"))

message("Copied ", nrow(manifest_dt), " GoF SVGs into ", DEST_ROOT)
message("  NH SAS: ", sum(manifest_dt$program == "NH SAS"),
        "  |  WIDA: ", sum(manifest_dt$program == "WIDA"))
message("Manifest: ", file.path(DEST_ROOT, "manifest.csv"))
