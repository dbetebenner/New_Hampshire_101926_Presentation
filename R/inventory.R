### inventory.R
###
### Throwaway column/level inventory. Loads each LONG file and prints only
### names(), year counts, and unique levels of categorical columns. Never
### prints student rows.
###
###   Rscript R/inventory.R

suppressPackageStartupMessages(library(data.table))

nh_path <- Sys.getenv(
  "NH_LONG_DATA",
  "/Users/conet/GitHub/CenterForAssessment/New_Hampshire/master/Data/New_Hampshire_SGP_LONG_Data.Rdata"
)
wida_path <- Sys.getenv(
  "WIDA_NH_LONG_DATA",
  "/Users/conet/GitHub/CenterForAssessment/WIDA_NH/master/Data/WIDA_NH_SGP_LONG_Data.Rdata"
)

load_first <- function(path) {
  if (!file.exists(path)) stop("Not found: ", path)
  env <- new.env()
  load(path, envir = env)
  obj <- get(ls(env)[1], envir = env)
  setDT(obj)
  obj
}

report <- function(label, d) {
  cat("\n================================================================\n")
  cat(label, "\n")
  cat("================================================================\n")
  cat("nrow:", format(nrow(d), big.mark = ","), "\n")
  cat("\n--- names() ---\n")
  cat(paste(names(d), collapse = "\n"), "\n")
  if ("YEAR" %in% names(d)) {
    cat("\n--- table(YEAR) ---\n")
    print(sort(table(as.character(d$YEAR), useNA = "ifany")))
  }
  if ("CONTENT_AREA" %in% names(d)) {
    cat("\n--- table(CONTENT_AREA) ---\n")
    print(sort(table(as.character(d$CONTENT_AREA), useNA = "ifany")))
  }
  if ("GRADE" %in% names(d)) {
    cat("\n--- unique(GRADE) ---\n")
    print(sort(unique(as.character(d$GRADE))))
  }
  cats <- c(
    "ACHIEVEMENT_LEVEL", "ACHIEVEMENT_LEVEL_PRIOR",
    "ETHNICITY", "GENDER", "IEP_STATUS",
    "FREE_REDUCED_LUNCH_STATUS", "ELL_STATUS", "HIGH_NEED_STATUS",
    "SGP_LEVEL", "SGP_LEVEL_BASELINE",
    "VALID_CASE"
  )
  for (col in cats) {
    if (!col %in% names(d)) next
    cat("\n--- unique(", col, ") ---\n", sep = "")
    print(sort(unique(as.character(d[[col]])), na.last = TRUE))
  }
  cuku <- grep("CATCH_UP_KEEP_UP|MOVE_UP_STAY_UP|SGP_TARGET|NUM_YEARS_TO_TARGET",
               names(d), value = TRUE)
  cat("\n--- target / CUKU columns ---\n")
  if (length(cuku)) cat(paste(cuku, collapse = "\n"), "\n") else cat("(none)\n")
  for (col in cuku[grepl("CATCH_UP_KEEP_UP|MOVE_UP_STAY_UP", cuku)]) {
    cat("\n--- unique(", col, ") ---\n", sep = "")
    print(sort(unique(as.character(d[[col]])), na.last = TRUE))
  }
  extra <- c("SCALE_SCORE_OLD_SCALE", "SCALE_SCORE_PRIOR", "SCALE_SCORE")
  cat("\n--- numeric extras present ---\n")
  print(extra[extra %in% names(d)])
  if ("YEAR" %in% names(d) && "SCALE_SCORE_OLD_SCALE" %in% names(d)) {
    cat("\n--- SCALE_SCORE_OLD_SCALE non-NA by YEAR ---\n")
    print(d[, .(n = .N, n_old = sum(!is.na(SCALE_SCORE_OLD_SCALE))),
            by = YEAR][order(YEAR)])
  }
}

report("NH SAS LONG", load_first(nh_path))
report("WIDA_NH LONG", load_first(wida_path))
cat("\nDone.\n")
