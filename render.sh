#!/usr/bin/env bash
#
# Build the New Hampshire 2026 SGP TAC deck end-to-end.
#
#   1. Regenerate the NH SAS summary cache from the LONG data (once).
#   2. Regenerate the WIDA ACCESS summary cache (once).
#   3. Vendor the goodness-of-fit SVGs the deck references.
#   4. Render the self-contained reveal.js HTML.
#
# Usage:
#   ./render.sh                 # incremental: rebuild caches only if data changed
#   ./render.sh --force         # force cache + figure rebuild, then render
#
# Data / GoF locations may be overridden with environment variables:
#   NH_LONG_DATA        path to New_Hampshire_SGP_LONG_Data.Rdata
#   NH_GOF_ROOT         path to the NH SAS Goodness_of_Fit directory
#   WIDA_NH_LONG_DATA   path to WIDA_NH_SGP_LONG_Data.Rdata
#   WIDA_NH_GOF_ROOT    path to the WIDA_NH Goodness_of_Fit directory
#   NH_DATA_RECEIVED    provenance date string
#
set -euo pipefail

cd "$(dirname "$0")"

FORCE=""
if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
  FORCE="--force"
fi

echo "==> [1/4] Generating NH SAS summary cache"
Rscript R/01_generate_summary.R ${FORCE}

echo "==> [2/4] Generating WIDA ACCESS summary cache"
Rscript R/03_generate_wida_summary.R ${FORCE}

echo "==> [3/4] Collecting goodness-of-fit figures"
Rscript R/02_collect_figures.R

echo "==> [4/4] Rendering deck"
quarto render New_Hampshire_2026_SGP_Results.qmd --to revealjs
mkdir -p docs
mv -f index.html docs/index.html
rm -rf index_files            # self-contained deck; supporting dir not needed

echo "==> Done: docs/index.html"
