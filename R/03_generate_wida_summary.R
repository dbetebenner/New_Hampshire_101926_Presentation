### 03_generate_wida_summary.R
###
### Loads WIDA_NH_SGP_LONG_Data.Rdata ONCE and writes a compact aggregate
### cache (summary/nh_wida_summary.rds). Small cells (N < 10) are masked.
###
### Headline on-track results use the 6-year baseline CUKU column — the
### longest horizon present, computed on the old ACCESS 2.0 scale against
### the WIDA Level 4.5 exit cut.
###
###   Rscript R/03_generate_wida_summary.R
###   Rscript R/03_generate_wida_summary.R --force

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
  "WIDA_NH_LONG_DATA",
  "/Users/conet/GitHub/CenterForAssessment/WIDA_NH/master/Data/WIDA_NH_SGP_LONG_Data.Rdata"
)
ANALYSIS_YEAR <- Sys.getenv("WIDA_NH_ANALYSIS_YEAR", "")
CACHE_PATH    <- file.path(PROJECT_ROOT, "summary", "nh_wida_summary.rds")

FORCE <- any(commandArgs(trailingOnly = TRUE) %in% c("--force", "-f"))

source(file.path(this_dir, "00_helpers.R"))

if (!file.exists(LONG_DATA_PATH)) {
  stop("WIDA LONG data file not found: ", LONG_DATA_PATH)
}

if (!FORCE && file.exists(CACHE_PATH) &&
    file.mtime(CACHE_PATH) > file.mtime(LONG_DATA_PATH)) {
  message("Cache is up to date (", CACHE_PATH, "). Use --force to rebuild.")
  quit(save = "no", status = 0)
}

t0 <- Sys.time()
message("Loading WIDA LONG data: ", LONG_DATA_PATH)
load_env <- new.env()
load(LONG_DATA_PATH, envir = load_env)
d <- get(ls(load_env)[1], envir = load_env)
setDT(d)
message("  loaded ", format(nrow(d), big.mark = ","), " rows in ",
        round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), "s")

if (!nzchar(ANALYSIS_YEAR)) {
  ANALYSIS_YEAR <- max(as.character(d$YEAR), na.rm = TRUE)
}
message("WIDA analysis year: ", ANALYSIS_YEAR)

w <- d[VALID_CASE == "VALID_CASE" & CONTENT_AREA == WIDA_CONTENT_AREA]
w[, GRADE_LABEL := pretty_grade(GRADE)]
w[, YEAR_LABEL := pretty_year(YEAR)]
w[, ACHIEVEMENT_LEVEL := factor(ACHIEVEMENT_LEVEL, levels = WIDA_LEVELS)]

gy <- w[YEAR == ANALYSIS_YEAR]

## ---------------------------------------------------------------------------
## participation
## ---------------------------------------------------------------------------

participation <- w[, .(
  n_tested          = .N,
  n_growth_cohort   = sum(!is.na(SGP)),
  n_growth_baseline = sum(!is.na(SGP_BASELINE))
), by = .(YEAR, YEAR_LABEL, GRADE, GRADE_LABEL)]
setorder(participation, YEAR, GRADE)
participation <- participation[order(YEAR, as.numeric(GRADE))]

## ---------------------------------------------------------------------------
## levels_dist
## ---------------------------------------------------------------------------

levels_dist <- w[!is.na(ACHIEVEMENT_LEVEL), .(n = .N),
                 by = .(YEAR, YEAR_LABEL, GRADE, GRADE_LABEL, ACHIEVEMENT_LEVEL)]
levels_dist[, pct := 100 * n / sum(n), by = .(YEAR, GRADE)]
levels_at_exit <- w[!is.na(ACHIEVEMENT_LEVEL),
  .(n = .N,
    n_proficient = sum(ACHIEVEMENT_LEVEL %in% WIDA_PROFICIENT_LEVELS),
    pct_proficient = 100 * mean(ACHIEVEMENT_LEVEL %in% WIDA_PROFICIENT_LEVELS)),
  by = .(YEAR, YEAR_LABEL, GRADE, GRADE_LABEL)]
levels_dist <- levels_dist[order(YEAR, as.numeric(GRADE), ACHIEVEMENT_LEVEL)]
levels_at_exit <- levels_at_exit[order(YEAR, as.numeric(GRADE))]
suppress_small(levels_dist, n_cols = "n")
suppress_small(levels_at_exit, n_cols = "n")

## ---------------------------------------------------------------------------
## sgp_overall (analysis year) + sgp_trend
## ---------------------------------------------------------------------------

sgp_overall <- summarise_sgp(gy, by = c("GRADE", "GRADE_LABEL"))
sgp_overall[, YEAR := ANALYSIS_YEAR]
suppress_small(sgp_overall, n_cols = c("n_cohort", "n_baseline"))
sgp_overall <- sgp_overall[order(as.numeric(GRADE))]

sgp_trend <- w[, .(
  mean_baseline   = mean(SGP_BASELINE, na.rm = TRUE),
  median_baseline = as.numeric(median(SGP_BASELINE, na.rm = TRUE)),
  n_baseline      = sum(!is.na(SGP_BASELINE)),
  mean_cohort     = mean(SGP, na.rm = TRUE),
  n_cohort        = sum(!is.na(SGP))
), by = .(YEAR, YEAR_LABEL, GRADE, GRADE_LABEL)]
sgp_trend <- sgp_trend[order(YEAR, as.numeric(GRADE))]
suppress_small(sgp_trend, n_cols = c("n_baseline", "n_cohort"))

## ---------------------------------------------------------------------------
## scale_transition (2026 only)
## ---------------------------------------------------------------------------

scale_transition <- data.table()
level_crosstab <- data.table()

if ("SCALE_SCORE_OLD_SCALE" %in% names(gy)) {
  st <- gy[!is.na(SCALE_SCORE) & !is.na(SCALE_SCORE_OLD_SCALE)]
  st[, LEVEL_OLD := wida_level_from_old_scale(SCALE_SCORE_OLD_SCALE, GRADE)]
  ## Naive mix: current WIDA_NH 4.5 cuts applied to the NEW composite.
  st[, LEVEL_NAIVE := wida_level_from_old_scale(SCALE_SCORE, GRADE)]

  xform_path <- Sys.getenv(
    "WIDA_SCALE_XFORM",
    "/Users/conet/GitHub/DBetebenner/SGPstateData/master/Custom_Functions_Misc/WIDA/widaACCESS_2026_scale_score_transformation.R"
  )
  ## The 4.5 exit cut is the 4th WIDA_NH cut. The new-scale cut a WIDA_NH
  ## READING.2026 entry would carry is the smallest integer NEW score whose
  ## NEW_to_OLD image reaches it; OLD_to_NEW can land on a half point where
  ## two NEW scores share one OLD score.
  cut45 <- data.table(
    GRADE     = names(WIDA_NH_CUTS),
    CUT45_OLD = vapply(WIDA_NH_CUTS, function(x) x[4], numeric(1))
  )
  if (file.exists(xform_path)) {
    sys.source(xform_path, envir = environment())
    st[, SS_LINKED_OLD := widaACCESS_2026_scale_score_transformation(
      grade = GRADE, scale_score = SCALE_SCORE, direction = "NEW_to_OLD")]
    new_grid <- 100:600
    cut45[, CUT45_NEW := vapply(seq_len(.N), function(i) {
      linked <- widaACCESS_2026_scale_score_transformation(
        grade = rep(GRADE[i], length(new_grid)), scale_score = new_grid,
        direction = "NEW_to_OLD")
      hit <- new_grid[linked >= CUT45_OLD[i]]
      if (length(hit)) as.numeric(min(hit)) else NA_real_
    }, numeric(1))]
  } else {
    st[, SS_LINKED_OLD := NA_real_]
    cut45[, CUT45_NEW := NA_real_]
  }
  st <- merge(st, cut45, by = "GRADE", all.x = TRUE)

  scale_transition <- st[, .(
    n            = .N,
    cor_new_old  = stats::cor(SCALE_SCORE, SCALE_SCORE_OLD_SCALE),
    mean_new     = mean(SCALE_SCORE),
    mean_old     = mean(SCALE_SCORE_OLD_SCALE),
    mean_diff    = mean(SCALE_SCORE - SCALE_SCORE_OLD_SCALE),
    mean_abs_link = mean(abs(SCALE_SCORE_OLD_SCALE - SS_LINKED_OLD), na.rm = TRUE),
    n_level_agree = sum(as.character(ACHIEVEMENT_LEVEL) == as.character(LEVEL_OLD), na.rm = TRUE),
    cut45_old    = CUT45_OLD[1],
    cut45_new    = CUT45_NEW[1],
    pct_proficient_old_composite = 100 * mean(LEVEL_OLD %in% WIDA_PROFICIENT_LEVELS, na.rm = TRUE),
    pct_proficient_new_cut       = 100 * mean(SCALE_SCORE >= CUT45_NEW),
    pct_proficient_naive_new     = 100 * mean(LEVEL_NAIVE %in% WIDA_PROFICIENT_LEVELS, na.rm = TRUE)
  ), by = .(GRADE, GRADE_LABEL)]
  scale_transition <- scale_transition[order(as.numeric(GRADE))]
  suppress_small(scale_transition, n_cols = "n")

  level_crosstab <- st[!is.na(ACHIEVEMENT_LEVEL) & !is.na(LEVEL_OLD), .(n = .N),
                       by = .(GRADE, GRADE_LABEL,
                              LEVEL_REPORTED = as.character(ACHIEVEMENT_LEVEL),
                              LEVEL_OLD)]
  level_crosstab[, LEVEL_REPORTED := factor(LEVEL_REPORTED, levels = WIDA_LEVELS)]
  level_crosstab[, LEVEL_OLD := factor(LEVEL_OLD, levels = WIDA_LEVELS)]
  suppress_small(level_crosstab, n_cols = "n")
}

## ---------------------------------------------------------------------------
## transition anatomy (2026 only): concordance clusters, 4.5 cut articulation,
## and a what-if of the 4.5 cut after monotone smoothing across grades.
## Mirrors SGP_Sandbox/WIDA_SCALE_SCORE_TRANSITION_2026, re-expressed for the
## NH 4.5 exit cut instead of WIDA's whole levels.
## ---------------------------------------------------------------------------

concordance_curves <- data.table()
cut45_curves       <- data.table()
cut45_whatif       <- data.table()

if (exists("st") && exists("widaACCESS_2026_scale_score_transformation")) {
  new_grid <- 100:600
  grade_set <- as.character(0:12)
  linked_by_grade <- lapply(grade_set, function(g)
    widaACCESS_2026_scale_score_transformation(
      grade = rep(g, length(new_grid)), scale_score = new_grid, direction = "NEW_to_OLD"))
  names(linked_by_grade) <- grade_set

  ## Grades whose NEW_to_OLD maps are identical share one concordance table.
  sig <- vapply(linked_by_grade, function(v) paste(round(v, 3), collapse = ","), character(1))
  cluster_id <- match(sig, unique(sig))
  clusters <- data.table(GRADE = grade_set, CLUSTER_ID = cluster_id)
  clusters[, CLUSTER := {
    lab <- pretty_grade(GRADE)
    if (.N == 1L) lab else paste0(lab[1], "\u2013", lab[.N])
  }, by = CLUSTER_ID]

  concordance_curves <- rbindlist(lapply(unique(cluster_id), function(k) {
    g <- grade_set[cluster_id == k][1]
    data.table(CLUSTER_ID = k, NEW = new_grid, OLD = linked_by_grade[[g]])
  }))
  concordance_curves <- merge(concordance_curves,
                              unique(clusters[, .(CLUSTER_ID, CLUSTER)]),
                              by = "CLUSTER_ID")

  smooth_isotonic <- function(y) stats::isoreg(y)$yf
  ## Least-squares fit with non-negative, non-increasing grade-to-grade steps.
  smooth_concave_monotone <- function(y, x) {
    if (!requireNamespace("quadprog", quietly = TRUE)) return(rep(NA_real_, length(y)))
    n <- length(y)
    h <- diff(x)
    cons <- list()
    for (i in 1:(n - 1)) { a <- numeric(n); a[i] <- -1; a[i + 1] <- 1; cons[[length(cons) + 1]] <- a }
    for (i in 1:(n - 2)) {
      a <- numeric(n)
      a[i] <- -1 / h[i]; a[i + 1] <- 1 / h[i] + 1 / h[i + 1]; a[i + 2] <- -1 / h[i + 1]
      cons[[length(cons) + 1]] <- a
    }
    sol <- tryCatch(
      quadprog::solve.QP(diag(2, n), 2 * y, do.call(cbind, cons), rep(0, length(cons))),
      error = function(e) NULL)
    if (is.null(sol)) rep(NA_real_, n) else sol$solution
  }

  cut45_curves <- merge(cut45, clusters, by = "GRADE")
  setorder(cut45_curves, CLUSTER_ID)
  cut45_curves <- cut45_curves[order(as.numeric(GRADE))]
  cut45_curves[, CUT45_ISO := smooth_isotonic(CUT45_NEW)]
  cut45_curves[, CUT45_CON := smooth_concave_monotone(CUT45_NEW, as.numeric(GRADE))]
  cut45_curves[, GRADE_LABEL := pretty_grade(GRADE)]

  wf <- merge(st[, .(GRADE, SCALE_SCORE)],
              cut45_curves[, .(GRADE, CUT45_NEW, CUT45_ISO, CUT45_CON)], by = "GRADE")
  cut45_whatif <- wf[, .(
    n              = .N,
    pct_matched    = 100 * mean(SCALE_SCORE >= CUT45_NEW),
    pct_isotonic   = 100 * mean(SCALE_SCORE >= CUT45_ISO),
    pct_concave    = 100 * mean(SCALE_SCORE >= CUT45_CON),
    pct_change_iso = 100 * mean((SCALE_SCORE >= CUT45_ISO) != (SCALE_SCORE >= CUT45_NEW)),
    pct_change_con = 100 * mean((SCALE_SCORE >= CUT45_CON) != (SCALE_SCORE >= CUT45_NEW))
  ), by = GRADE]
  cut45_whatif[, GRADE_LABEL := pretty_grade(GRADE)]
  cut45_whatif <- cut45_whatif[order(as.numeric(GRADE))]
  suppress_small(cut45_whatif, n_cols = "n")
}

## ---------------------------------------------------------------------------
## on_track (baseline, 6-year horizon) + compare
## ---------------------------------------------------------------------------

if (!WIDA_CUKU_BASELINE %in% names(gy)) {
  stop("Expected column missing: ", WIDA_CUKU_BASELINE)
}

grade_lu <- unique(gy[, .(GRADE_LABEL, GRADE)])

on_track_grade <- target_rates(gy, WIDA_CUKU_BASELINE, by = "GRADE_LABEL")
if (nrow(on_track_grade)) {
  on_track_grade <- merge(on_track_grade, grade_lu, by = "GRADE_LABEL", all.x = TRUE)
  on_track_grade <- on_track_grade[order(as.numeric(GRADE), aspiration)]
}

on_track_level <- target_rates(
  gy[!is.na(ACHIEVEMENT_LEVEL)],
  WIDA_CUKU_BASELINE,
  by = "ACHIEVEMENT_LEVEL"
)

years_to_target <- data.table()
if (WIDA_YTT_BASELINE %in% names(gy)) {
  years_to_target <- gy[!is.na(get(WIDA_YTT_BASELINE)),
    .(n = .N),
    by = .(GRADE, GRADE_LABEL,
           years = as.numeric(get(WIDA_YTT_BASELINE)))]
  years_to_target[, pct := 100 * n / sum(n), by = .(GRADE)]
  years_to_target <- years_to_target[order(as.numeric(GRADE), years)]
  suppress_small(years_to_target, n_cols = "n")
}

on_track_compare <- data.table()
cuku_b <- target_rates(gy, WIDA_CUKU_BASELINE, by = "GRADE_LABEL")
cuku_c <- target_rates(gy, WIDA_CUKU_COHORT,   by = "GRADE_LABEL")
if (nrow(cuku_b) && nrow(cuku_c)) {
  cuku_b[, NORM := "Baseline"]
  cuku_c[, NORM := "Cohort"]
  on_track_compare <- rbind(cuku_b, cuku_c, use.names = TRUE, fill = TRUE)
  on_track_compare <- merge(on_track_compare, grade_lu, by = "GRADE_LABEL", all.x = TRUE)
  on_track_compare <- on_track_compare[order(NORM, as.numeric(GRADE), aspiration)]
}

## ---------------------------------------------------------------------------
## meta
## ---------------------------------------------------------------------------

sgp_version <- tryCatch(as.character(utils::packageVersion("SGP")),
                        error = function(e) NA_character_)

meta <- list(
  analysis_year           = ANALYSIS_YEAR,
  analysis_year_label     = pretty_year(ANALYSIS_YEAR),
  years_available         = sort(unique(as.character(w$YEAR))),
  grades                  = sort(unique(as.character(w$GRADE))),
  exit_level              = WIDA_EXIT_LEVEL,
  cuku_horizon            = WIDA_CUKU_HORIZON,
  cuku_baseline_column    = WIDA_CUKU_BASELINE,
  cuku_cohort_column      = WIDA_CUKU_COHORT,
  n_tested_total          = nrow(gy),
  n_growth_cohort_total   = sum(!is.na(gy$SGP)),
  n_growth_baseline_total = sum(!is.na(gy$SGP_BASELINE)),
  has_old_scale           = "SCALE_SCORE_OLD_SCALE" %in% names(gy),
  n_old_scale             = if ("SCALE_SCORE_OLD_SCALE" %in% names(gy))
                              sum(!is.na(gy$SCALE_SCORE_OLD_SCALE)) else 0L,
  sgp_package_version     = sgp_version,
  source_file             = LONG_DATA_PATH,
  source_mtime            = file.mtime(LONG_DATA_PATH),
  generated_at            = Sys.time()
)

summary_list <- list(
  meta             = meta,
  participation    = participation,
  levels_dist      = levels_dist,
  levels_at_exit   = levels_at_exit,
  sgp_overall      = sgp_overall,
  sgp_trend        = sgp_trend,
  scale_transition = scale_transition,
  level_crosstab   = level_crosstab,
  concordance_curves = concordance_curves,
  cut45_curves     = cut45_curves,
  cut45_whatif     = cut45_whatif,
  on_track_grade   = on_track_grade,
  on_track_level   = on_track_level,
  years_to_target  = years_to_target,
  on_track_compare = on_track_compare
)

dir.create(dirname(CACHE_PATH), showWarnings = FALSE, recursive = TRUE)
saveRDS(summary_list, CACHE_PATH)

message("Wrote cache: ", CACHE_PATH,
        " (", round(file.size(CACHE_PATH) / 1024, 1), " KB)")
message("  N tested ", ANALYSIS_YEAR, ": ",
        format(meta$n_tested_total, big.mark = ","),
        "  |  with baseline SGP: ",
        format(meta$n_growth_baseline_total, big.mark = ","))
message("Done in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), "s")
