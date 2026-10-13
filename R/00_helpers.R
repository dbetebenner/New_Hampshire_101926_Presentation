### 00_helpers.R
### Shared recode/label/format helpers for the New Hampshire 2026 SGP
### presentation pipeline. Sourced by 01/02/03 and the Quarto deck.

suppressPackageStartupMessages({
  library(data.table)
})

## ---------------------------------------------------------------------------
## Analysis constants
## ---------------------------------------------------------------------------

## NH SAS growth content areas. Grade 3 has no prior, so no SGP; SCIENCE
## and grade 11 are INVALID_CASE in the annual prep scripts.
GROWTH_CONTENT_AREAS <- c("READING", "MATHEMATICS")

## Subgroup dimensions surfaced in the equity section.
SUBGROUP_DIMENSIONS <- list(
  Gender                   = "GENDER",
  `Race/Ethnicity`         = "ETHNICITY",
  `English Learner`        = "ELL_STATUS",
  `Students w/ Disability` = "IEP_STATUS",
  `Economically Disadv.`   = "FREE_REDUCED_LUNCH_STATUS"
)

## Pre-pandemic baseline norm year (NH SAS academic-year label).
BASELINE_NORM_YEAR <- "2018_2019"

## Achievement levels counted as proficient on NH SAS.
PROFICIENT_LEVELS <- c("Proficient", "Above Proficient")

## WIDA ACCESS
WIDA_CONTENT_AREA <- "READING"
WIDA_EXIT_LEVEL <- "WIDA Level 4.5"
WIDA_LEVELS <- c(
  "WIDA Level 1", "WIDA Level 2", "WIDA Level 3", "WIDA Level 4",
  "WIDA Level 4.5", "WIDA Level 5", "WIDA Level 6"
)
WIDA_PROFICIENT_LEVELS <- c("WIDA Level 4.5", "WIDA Level 5", "WIDA Level 6")
WIDA_CUKU_HORIZON <- 6L
WIDA_CUKU_BASELINE <- paste0("CATCH_UP_KEEP_UP_STATUS_BASELINE_", WIDA_CUKU_HORIZON, "_YEAR")
WIDA_CUKU_COHORT   <- paste0("CATCH_UP_KEEP_UP_STATUS_", WIDA_CUKU_HORIZON, "_YEAR")
WIDA_YTT_BASELINE  <- paste0("SGP_TARGET_BASELINE_", WIDA_CUKU_HORIZON, "_YEAR_NUM_YEARS_TO_TARGET")
WIDA_YTT_COHORT    <- paste0("SGP_TARGET_", WIDA_CUKU_HORIZON, "_YEAR_NUM_YEARS_TO_TARGET")

## Old-scale (ACCESS 2.0) 4.5-exit cuts from SGPstateData[["WIDA_NH"]].
WIDA_NH_CUTS <- list(
  "0"  = c(229, 261, 293, 309, 325, 350),
  "1"  = c(242, 274, 315, 330, 344, 368),
  "2"  = c(254, 289, 329, 344, 359, 383),
  "3"  = c(265, 300, 340, 356, 371, 396),
  "4"  = c(279, 309, 350, 366, 382, 406),
  "5"  = c(286, 317, 358, 374, 390, 415),
  "6"  = c(291, 324, 365, 382, 399, 423),
  "7"  = c(298, 331, 372, 389, 406, 431),
  "8"  = c(304, 337, 378, 395, 412, 438),
  "9"  = c(311, 344, 385, 402, 418, 446),
  "10" = c(318, 350, 391, 408, 424, 453),
  "11" = c(325, 356, 397, 413, 429, 459),
  "12" = c(331, 362, 402, 418, 434, 466)
)

SMALL_N <- 10L

## ---------------------------------------------------------------------------
## Recodes
## ---------------------------------------------------------------------------

recode_ethnicity <- function(x) {
  x <- as.character(x)
  x[x == "American Indian or Alaskan Native"]    <- "American Indian or Alaska Native"
  x[x == "Native Hawaiiian or Pacific Islander"] <- "Native Hawaiian or Pacific Islander"
  x[x == "Two or more races"]                    <- "Two or More Races"
  x[x %in% c("Not reported", "NULL", "")]        <- NA_character_
  x
}

clean_iep <- function(x) {
  x <- as.character(x)
  x[x == "Students with Disabilities (SWD/IEP)"]        <- "Students with Disabilities (SWD)"
  x[x == "Students without Disabilities (Non-SWD/IEP)"] <- "Students without Disabilities (Non-SWD)"
  x[!x %in% c("Students with Disabilities (SWD)",
              "Students without Disabilities (Non-SWD)")] <- NA_character_
  x
}

clean_gender <- function(x) {
  x <- as.character(x)
  x[!x %in% c("Female", "Male")] <- NA_character_
  x
}

clean_ell <- function(x) {
  x <- as.character(x)
  x[grepl("^English Language Learners", x)]     <- "English Learners (EL)"
  x[grepl("^Non-English Language Learners", x)] <- "Non-English Learners (Non-EL)"
  x[!x %in% c("English Learners (EL)",
              "Non-English Learners (Non-EL)")] <- NA_character_
  x
}

clean_ses <- function(x) {
  x <- as.character(x)
  x[x == "Economically Disadvantaged (SES)"]         <- "Economically Disadvantaged"
  x[x == "Not Economically Disadvantaged (Non-SES)"] <- "Not Economically Disadvantaged"
  x[!x %in% c("Economically Disadvantaged",
              "Not Economically Disadvantaged")] <- NA_character_
  x
}

recode_prior_level <- function(x) {
  x <- as.character(x)
  x[x == "Level 1"] <- "Below Proficient"
  x[x == "Level 2"] <- "Approaching Proficient"
  x[x == "Level 3"] <- "Proficient"
  x[x == "Level 4"] <- "Above Proficient"
  x[!x %in% c("Below Proficient", "Approaching Proficient",
              "Proficient", "Above Proficient")] <- NA_character_
  x
}

## Old-scale WIDA achievement level from SCALE_SCORE_OLD_SCALE + grade cuts.
wida_level_from_old_scale <- function(score, grade) {
  grade <- as.character(grade)
  n <- length(score)
  out <- rep(NA_character_, n)
  for (g in unique(grade)) {
    cuts <- WIDA_NH_CUTS[[g]]
    if (is.null(cuts)) next
    idx <- which(grade == g)
    ss <- score[idx]
    brk <- c(-Inf, cuts, Inf)
    out[idx] <- WIDA_LEVELS[as.integer(cut(ss, breaks = brk, labels = FALSE,
                                           right = FALSE, include.lowest = TRUE))]
  }
  out
}

## ---------------------------------------------------------------------------
## Pretty labels
## ---------------------------------------------------------------------------

assessment_of <- function(content_area) {
  fifelse(content_area %in% GROWTH_CONTENT_AREAS, "NH SAS", "Other")
}

pretty_subject <- function(content_area) {
  data.table::fcase(
    content_area == "READING",     "ELA",
    content_area == "MATHEMATICS", "Mathematics",
    default = content_area
  )
}

pretty_grade <- function(grade, content_area = NULL) {
  g <- as.character(grade)
  fifelse(g == "0", "K", g)
}

pretty_year <- function(year) {
  ## "2025_2026" -> "2026"; "2026" stays "2026"
  y <- as.character(year)
  ifelse(grepl("^[0-9]{4}_", y), sub("^[0-9]{4}_", "", y), y)
}

pretty_wida_level <- function(x) {
  sub("^WIDA Level ", "L", as.character(x))
}

## ---------------------------------------------------------------------------
## Formatting
## ---------------------------------------------------------------------------

fmt_count <- function(n) {
  if (length(n) != 1L || is.na(n)) return("&mdash;")
  formatC(as.integer(n), format = "d", big.mark = ",")
}

fmt_mmn <- function(mean_val, median_val, n) {
  if (length(n) && !is.na(n) && n < SMALL_N) return("&mdash;")
  if (any(is.na(c(mean_val, median_val, n)))) return("&mdash;")
  paste0(
    formatC(round(mean_val, 1), format = "f", digits = 1),
    "/",
    formatC(round(median_val, 0), format = "d"),
    "/",
    fmt_count(n)
  )
}

fmt_pct <- function(p, digits = 0) {
  if (length(p) != 1L || is.na(p)) return("&mdash;")
  paste0(formatC(round(p, digits), format = "f", digits = digits), "%")
}

## ---------------------------------------------------------------------------
## Core aggregation helpers
## ---------------------------------------------------------------------------

summarise_sgp <- function(dt, by) {
  dt[, .(
    mean_cohort     = mean(SGP, na.rm = TRUE),
    median_cohort   = as.numeric(median(SGP, na.rm = TRUE)),
    sd_cohort       = as.numeric(stats::sd(SGP, na.rm = TRUE)),
    n_cohort        = sum(!is.na(SGP)),
    mean_baseline   = mean(SGP_BASELINE, na.rm = TRUE),
    median_baseline = as.numeric(median(SGP_BASELINE, na.rm = TRUE)),
    sd_baseline     = as.numeric(stats::sd(SGP_BASELINE, na.rm = TRUE)),
    n_baseline      = sum(!is.na(SGP_BASELINE))
  ), by = by]
}

summarise_levels <- function(dt, level_col, by) {
  x <- dt[!is.na(get(level_col)),
          .(n = .N), by = c(by, level_col)]
  x[, pct := 100 * n / sum(n), by = by]
  setnames(x, level_col, "LEVEL")
  x[]
}

## Wilson score interval for a proportion, returned in percentage points.
wilson_ci <- function(x, n, z = 1.96) {
  p <- x / n
  den <- 1 + z^2 / n
  ctr <- p + z^2 / (2 * n)
  hw  <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))
  list(100 * (ctr - hw) / den, 100 * (ctr + hw) / den)
}

## Mask statistics in rows whose count is below SMALL_N. `n_cols` names the
## count columns; every other numeric column in those rows is set to NA.
suppress_small <- function(dt, n_cols = "n", min_n = SMALL_N) {
  if (!nrow(dt)) return(invisible(dt))
  small <- Reduce(`|`, lapply(n_cols, function(col) {
    if (!col %in% names(dt)) return(rep(FALSE, nrow(dt)))
    !is.na(dt[[col]]) & dt[[col]] < min_n
  }))
  if (!any(small)) return(invisible(dt))
  num_cols <- names(dt)[vapply(dt, is.numeric, logical(1))]
  mask_cols <- setdiff(num_cols, n_cols)
  for (col in mask_cols) dt[small, (col) := NA_real_]
  invisible(dt)
}

## Attainment rate = Yes / (Yes + No) within each aspiration group.
target_rates <- function(dt, status_col, by) {
  if (!status_col %in% names(dt)) {
    return(data.table::data.table())
  }
  x <- dt[!is.na(get(status_col)), .(status = get(status_col)), by = by]
  x[, aspiration := sub(":.*$", "", status)]
  x[, attained := grepl("Yes$", status)]
  out <- x[, .(n = .N, attained = sum(attained)), by = c(by, "aspiration")]
  out[, rate := 100 * attained / n]
  out[, c("rate_lo", "rate_hi") := wilson_ci(attained, n)]
  suppress_small(out, n_cols = "n")
}
