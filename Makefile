# New Hampshire 2026 SGP TAC deck — build pipeline
#
#   make            # incremental build (caches rebuilt only if LONG data changed)
#   make force      # force-rebuild both caches, then figures + render
#   make cache      # (re)build both summary caches
#   make figures    # vendor goodness-of-fit SVGs only
#   make render     # render the deck only (assumes caches + figures exist)
#   make clean      # remove rendered HTML + freeze/cache dirs (keeps summary/ + Figures/gof)

QMD      := New_Hampshire_2026_SGP_Results.qmd
HTML     := docs/index.html
CACHE    := summary/nh_sgp_summary.rds
WIDA     := summary/nh_wida_summary.rds
MANIFEST := Figures/gof/manifest.csv

export NH_LONG_DATA
export NH_GOF_ROOT
export WIDA_NH_LONG_DATA
export WIDA_NH_GOF_ROOT
export NH_DATA_RECEIVED

.PHONY: all force cache figures render clean

all: render

$(CACHE):
	Rscript R/01_generate_summary.R

$(WIDA):
	Rscript R/03_generate_wida_summary.R

cache: $(CACHE) $(WIDA)

force:
	Rscript R/01_generate_summary.R --force
	Rscript R/03_generate_wida_summary.R --force
	$(MAKE) figures render

$(MANIFEST):
	Rscript R/02_collect_figures.R

figures: $(MANIFEST)

render: $(CACHE) $(WIDA) $(MANIFEST)
	quarto render $(QMD) --to revealjs
	mkdir -p docs
	mv -f index.html docs/index.html
	rm -rf index_files

clean:
	rm -f $(HTML) index.html
	rm -rf .quarto index_files index_cache \
	       New_Hampshire_2026_SGP_Results_files New_Hampshire_2026_SGP_Results_cache
