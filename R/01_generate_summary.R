### 01_generate_summary.R
###
### Loads the (large) New Hampshire SGP LONG data ONCE and writes a compact
### summary cache (summary/nh_sgp_summary.rds) consumed by the Quarto deck.
### The deck never touches the LONG file, so re-rendering is fast.
###
###   Rscript R/01_generate_summary.R
###   Rscript R/01_generate_summary.R --force
###
###   NH_LONG_DATA=/path/to/LONG.Rdata NH_ANALYSIS_YEAR=2025_2026 Rscript ...

suppressPackageStartupMessages({
  library(data.table)
})

this_dir <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_arg)) dirname(normalizePath(file_arg)) else getwd()
}, error = function(e) getwd())

PROJECT_ROOT <- normalizePath(file.path(this_dir, ".."))

LONG_DATA_PATH <- Sys.getenv(
  "NH_LONG_DATA",
  "/Users/conet/GitHub/CenterForAssessment/New_Hampshire/master/Data/New_Hampshire_SGP_LONG_Data.Rdata"
)
ANALYSIS_YEAR <- Sys.getenv("NH_ANALYSIS_YEAR", "")
DATA_RECEIVED <- Sys.getenv("NH_DATA_RECEIVED", "July 9, 2026")
CACHE_PATH    <- file.path(PROJECT_ROOT, "summary", "nh_sgp_summary.rds")

FORCE <- any(commandArgs(trailingOnly = TRUE) %in% c("--force", "-f"))

source(file.path(this_dir, "00_helpers.R"))

if (!file.exists(LONG_DATA_PATH)) {
  stop("LONG data file not found: ", LONG_DATA_PATH)
}

if (!FORCE && file.exists(CACHE_PATH) &&
    file.mtime(CACHE_PATH) > file.mtime(LONG_DATA_PATH)) {
  message("Cache is up to date (", CACHE_PATH, "). Use --force to rebuild.")
  quit(save = "no", status = 0)
}

t0 <- Sys.time()
message("Loading LONG data: ", LONG_DATA_PATH)
load_env <- new.env()
load(LONG_DATA_PATH, envir = load_env)
long_obj_name <- ls(load_env)[1]
d <- get(long_obj_name, envir = load_env)
setDT(d)
message("  loaded ", format(nrow(d), big.mark = ","), " rows in ",
        round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), "s")

if (!nzchar(ANALYSIS_YEAR)) {
  ANALYSIS_YEAR <- max(as.character(d$YEAR), na.rm = TRUE)
}
message("Analysis year: ", ANALYSIS_YEAR)

## ---------------------------------------------------------------------------
## Prepare a trimmed working table
## ---------------------------------------------------------------------------

g <- d[VALID_CASE == "VALID_CASE" & CONTENT_AREA %in% GROWTH_CONTENT_AREAS]

g[, ETHNICITY := recode_ethnicity(ETHNICITY)]
g[, IEP_STATUS := clean_iep(IEP_STATUS)]
g[, ELL_STATUS := clean_ell(ELL_STATUS)]
g[, GENDER := clean_gender(GENDER)]
g[, FREE_REDUCED_LUNCH_STATUS := clean_ses(FREE_REDUCED_LUNCH_STATUS)]
if ("ACHIEVEMENT_LEVEL_PRIOR" %in% names(g)) {
  g[, ACHIEVEMENT_LEVEL_PRIOR := recode_prior_level(ACHIEVEMENT_LEVEL_PRIOR)]
}

g[, ASSESSMENT := assessment_of(CONTENT_AREA)]
g[, SUBJECT := pretty_subject(CONTENT_AREA)]
g[, GRADE_LABEL := pretty_grade(GRADE)]

## ---------------------------------------------------------------------------
## overall
## ---------------------------------------------------------------------------

overall <- summarise_sgp(g, by = c("CONTENT_AREA", "SUBJECT", "ASSESSMENT",
                                   "GRADE", "GRADE_LABEL", "YEAR"))
overall[, YEAR_LABEL := pretty_year(YEAR)]
setorder(overall, ASSESSMENT, SUBJECT, GRADE, YEAR)
suppress_small(overall, n_cols = c("n_cohort", "n_baseline"))

## ---------------------------------------------------------------------------
## levels
## ---------------------------------------------------------------------------

lev_cohort <- summarise_levels(
  g[!is.na(SGP_LEVEL)], "SGP_LEVEL",
  by = c("CONTENT_AREA", "SUBJECT", "ASSESSMENT", "GRADE", "GRADE_LABEL", "YEAR")
)
lev_cohort[, NORM := "Cohort"]

lev_baseline <- summarise_levels(
  g[!is.na(SGP_LEVEL_BASELINE)], "SGP_LEVEL_BASELINE",
  by = c("CONTENT_AREA", "SUBJECT", "ASSESSMENT", "GRADE", "GRADE_LABEL", "YEAR")
)
lev_baseline[, NORM := "Baseline"]

levels_dt <- rbind(lev_cohort, lev_baseline)
levels_dt[, YEAR_LABEL := pretty_year(YEAR)]
levels_dt[, LEVEL := factor(LEVEL, levels = c("Low", "Typical", "High"))]
suppress_small(levels_dt, n_cols = "n")

## ---------------------------------------------------------------------------
## subgroups (analysis year)
## ---------------------------------------------------------------------------

gy <- g[YEAR == ANALYSIS_YEAR]

build_subgroup <- function(dim_label, col) {
  x <- copy(gy)
  x[, GROUP := as.character(get(col))]
  x <- x[!is.na(GROUP)]
  out <- summarise_sgp(x, by = c("ASSESSMENT", "SUBJECT", "GRADE_LABEL", "GROUP"))
  out[, DIMENSION := dim_label]
  suppress_small(out, n_cols = c("n_cohort", "n_baseline"))
}

subgroups <- rbindlist(
  Map(build_subgroup, names(SUBGROUP_DIMENSIONS), unlist(SUBGROUP_DIMENSIONS)),
  use.names = TRUE
)
setcolorder(subgroups, c("DIMENSION", "GROUP", "ASSESSMENT", "SUBJECT", "GRADE_LABEL"))

build_subgroup_pooled <- function(dim_label, col) {
  x <- copy(gy)
  x[, GROUP := as.character(get(col))]
  x <- x[!is.na(GROUP)]
  out <- summarise_sgp(x, by = c("ASSESSMENT", "SUBJECT", "GROUP"))
  out[, DIMENSION := dim_label]
  suppress_small(out, n_cols = c("n_cohort", "n_baseline"))
}
subgroups_pooled <- rbindlist(
  Map(build_subgroup_pooled, names(SUBGROUP_DIMENSIONS), unlist(SUBGROUP_DIMENSIONS)),
  use.names = TRUE
)
setcolorder(subgroups_pooled, c("DIMENSION", "GROUP", "ASSESSMENT", "SUBJECT"))

## ---------------------------------------------------------------------------
## targets
## ---------------------------------------------------------------------------

cuku_overall <- target_rates(gy, "CATCH_UP_KEEP_UP_STATUS_3_YEAR",
                             by = c("ASSESSMENT", "SUBJECT", "GRADE_LABEL"))
if (nrow(cuku_overall)) cuku_overall[, `:=`(NORM = "Cohort", METRIC = "Catch Up / Keep Up")]

cuku_baseline <- target_rates(gy, "CATCH_UP_KEEP_UP_STATUS_BASELINE_3_YEAR",
                              by = c("ASSESSMENT", "SUBJECT", "GRADE_LABEL"))
if (nrow(cuku_baseline)) cuku_baseline[, `:=`(NORM = "Baseline", METRIC = "Catch Up / Keep Up")]

musu_overall <- target_rates(gy, "MOVE_UP_STAY_UP_STATUS_3_YEAR",
                             by = c("ASSESSMENT", "SUBJECT", "GRADE_LABEL"))
if (nrow(musu_overall)) musu_overall[, `:=`(NORM = "Cohort", METRIC = "Move Up / Stay Up")]

targets <- rbind(cuku_overall, cuku_baseline, musu_overall, use.names = TRUE, fill = TRUE)

if ("SGP_TARGET_3_YEAR_NUM_YEARS_TO_TARGET" %in% names(gy) && nrow(targets)) {
  target_horizon <- gy[!is.na(CATCH_UP_KEEP_UP_STATUS_3_YEAR) &
                       !is.na(SGP_TARGET_3_YEAR_NUM_YEARS_TO_TARGET),
    .(years_to_target = as.numeric(stats::median(
      as.numeric(SGP_TARGET_3_YEAR_NUM_YEARS_TO_TARGET), na.rm = TRUE))),
    by = .(ASSESSMENT, SUBJECT, GRADE_LABEL)]
  targets <- merge(targets, target_horizon,
                   by = c("ASSESSMENT", "SUBJECT", "GRADE_LABEL"), all.x = TRUE)
}

## Catch-up / keep-up by prior achievement level (replaces RI high-need slide).
targets_prior <- target_rates(
  gy[!is.na(ACHIEVEMENT_LEVEL_PRIOR)],
  "CATCH_UP_KEEP_UP_STATUS_3_YEAR",
  by = c("ASSESSMENT", "SUBJECT", "ACHIEVEMENT_LEVEL_PRIOR")
)
if (nrow(targets_prior)) {
  targets_prior[, `:=`(NORM = "Cohort", METRIC = "Catch Up / Keep Up")]
}

## ---------------------------------------------------------------------------
## proficiency
## ---------------------------------------------------------------------------

proficiency <- g[!is.na(ACHIEVEMENT_LEVEL),
  .(pct_proficient = 100 * mean(ACHIEVEMENT_LEVEL %in% PROFICIENT_LEVELS),
    n = .N),
  by = .(CONTENT_AREA, SUBJECT, ASSESSMENT, GRADE, GRADE_LABEL, YEAR)]
proficiency[, YEAR_LABEL := pretty_year(YEAR)]
setorder(proficiency, ASSESSMENT, SUBJECT, GRADE, YEAR)
suppress_small(proficiency, n_cols = "n")

## ---------------------------------------------------------------------------
## sgp_distribution
## ---------------------------------------------------------------------------

dist_one <- function(col, norm_label) {
  x <- g[YEAR == ANALYSIS_YEAR & !is.na(get(col))]
  out <- x[, .(n = .N),
           by = .(CONTENT_AREA, SUBJECT, ASSESSMENT, GRADE, GRADE_LABEL,
                  DECILE = pmin(9L, as.integer(get(col)) %/% 10L))]
  out[, NORM := norm_label]
  out
}

sgp_distribution <- rbind(dist_one("SGP", "Cohort"),
                          dist_one("SGP_BASELINE", "Baseline"))
sgp_distribution[, pct := 100 * n / sum(n),
                 by = .(CONTENT_AREA, GRADE_LABEL, NORM)]
setorder(sgp_distribution, ASSESSMENT, SUBJECT, GRADE, NORM, DECILE)

## ---------------------------------------------------------------------------
## meta
## ---------------------------------------------------------------------------

n_tested <- gy[, .(n_tested = .N,
                   n_growth_cohort = sum(!is.na(SGP)),
                   n_growth_baseline = sum(!is.na(SGP_BASELINE))),
               by = .(ASSESSMENT, SUBJECT, GRADE_LABEL)]

sgp_version <- tryCatch(as.character(utils::packageVersion("SGP")),
                        error = function(e) NA_character_)

meta <- list(
  analysis_year           = ANALYSIS_YEAR,
  analysis_year_label     = pretty_year(ANALYSIS_YEAR),
  years_available         = sort(unique(as.character(g$YEAR))),
  content_areas           = GROWTH_CONTENT_AREAS,
  nhsas_grades            = sort(unique(g$GRADE)),
  n_tested                = n_tested,
  n_tested_total          = nrow(gy),
  n_growth_cohort_total   = sum(!is.na(gy$SGP)),
  n_growth_baseline_total = sum(!is.na(gy$SGP_BASELINE)),
  sgp_package_version     = sgp_version,
  source_file             = LONG_DATA_PATH,
  source_mtime            = file.mtime(LONG_DATA_PATH),
  data_received           = DATA_RECEIVED,
  baseline_norm_year      = BASELINE_NORM_YEAR,
  generated_at            = Sys.time()
)

summary_list <- list(
  meta             = meta,
  overall          = overall,
  levels           = levels_dt,
  subgroups        = subgroups,
  subgroups_pooled = subgroups_pooled,
  targets          = targets,
  targets_prior    = targets_prior,
  proficiency      = proficiency,
  sgp_distribution = sgp_distribution
)

dir.create(dirname(CACHE_PATH), showWarnings = FALSE, recursive = TRUE)
saveRDS(summary_list, CACHE_PATH)

message("Wrote cache: ", CACHE_PATH,
        " (", round(file.size(CACHE_PATH) / 1024, 1), " KB)")
message("  N tested ", ANALYSIS_YEAR, ": ",
        format(meta$n_tested_total, big.mark = ","),
        "  |  with cohort SGP: ",
        format(meta$n_growth_cohort_total, big.mark = ","))
message("Done in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), "s")
