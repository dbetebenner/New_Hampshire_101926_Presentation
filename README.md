# New Hampshire 2026 SGP Analyses — NH TAC Presentation

Part of Damian Betebenner's talks: <https://dbetebenner.github.io/talks/>

A reveal.js (Quarto) presentation of New Hampshire's 2026 Student Growth
Percentile (SGP) results — NH SAS (ELA/Mathematics, grades 4–8) and WIDA
ACCESS (Overall ELP) — for the New Hampshire Technical Advisory Committee
on **October 19, 2026**.

The deck reuses the Rhode Island TAC pipeline (styling, cached aggregates,
vendored goodness-of-fit SVGs) in a leaner form: core 2026 results, model
fit, a light pandemic-context section, equity, catch-up/keep-up, and a
WIDA ACCESS section in place of Rhode Island's grade-11 SAT discussion.

## Decisions baked into this deck

- **WIDA exit remains Level 4.5**, as configured in `SGPstateData[["WIDA_NH"]]`
  and in the prep scripts since 2019. Fine-grained scores 4.5–4.9 are
  collapsed to 4.5. This is not New Mexico's 4.7.
- **Headline WIDA on-track results are baseline-referenced and computed on
  the old ACCESS 2.0 composite** (`SCALE_SCORE_OLD_SCALE` against the current
  4.5 cuts). The 2026 analysis ran cohort SGPs on the new ACCESS 3.0 scale
  and baseline SGPs on the old scale.
- **`WIDA_NH` does not yet carry the consortium 2026 transition metadata**
  (new cuts, knots, linkages). Cohort catch-up rates on the new scale
  against old cuts are shown only as a TAC discussion item.
- **Small cells (N < 10) are suppressed** in the cached aggregates.

## Present it

Open **`docs/index.html`** in any browser (self-contained, works offline).

- **`S`** — speaker view (per-slide notes + timer)
- **`F`** — fullscreen · **`O`** — overview · arrows / space to advance
- Click any goodness-of-fit plot to enlarge it.

**PDF of the slides:**
<https://dbetebenner.github.io/New_Hampshire_101926_Presentation/New_Hampshire_2026_SGP_Results.pdf>
(`docs/New_Hampshire_2026_SGP_Results.pdf`). It is a copy of
`assets/exported_pdf/New Hampshire 2026 SGP Results.pdf`, a browser print committed
at 09:51 on October 19. It predates that morning's later edits to the deck, so it
does not include the three WIDA scale-transition slides (concordance clusters, the 4.5
cut on each scale, the smoothing what-if) or the K–12 subtitle.

Leave GitHub Pages off (or the repository private) until NHDOE clears the
results for release.

## The pipeline

The student-level LONG files are large and are **never** read by the deck.
One-time R steps distill them into compact cached summaries.

```
New_Hampshire_SGP_LONG_Data.Rdata ─► R/01_generate_summary.R ─► summary/nh_sgp_summary.rds ─┐
WIDA_NH_SGP_LONG_Data.Rdata       ─► R/03_generate_wida_summary.R ─► summary/nh_wida_summary.rds ─┤
Goodness_of_Fit/*.svg             ─► R/02_collect_figures.R  ─► Figures/gof/*.svg          ─┤
                                                                                            ▼
                                     New_Hampshire_2026_SGP_Results.qmd ─► docs/index.html
```

### Build

```bash
./render.sh            # caches rebuilt only if the LONG data are newer; then render
./render.sh --force    # force cache rebuild, then figures + render
```

or with `make`:

```bash
make            # incremental build
make force      # force full rebuild
make cache      # both summary caches
make figures    # vendor goodness-of-fit SVGs only
make render     # render the deck only
```

Data / figure locations default to the `CenterForAssessment/New_Hampshire`
and `CenterForAssessment/WIDA_NH` working copies (Dropbox-symlinked `Data/`
and `Goodness_of_Fit/`) and can be overridden:

```bash
NH_LONG_DATA="/path/to/New_Hampshire_SGP_LONG_Data.Rdata" \
NH_GOF_ROOT="/path/to/New_Hampshire/Goodness_of_Fit" \
WIDA_NH_LONG_DATA="/path/to/WIDA_NH_SGP_LONG_Data.Rdata" \
WIDA_NH_GOF_ROOT="/path/to/WIDA_NH/Goodness_of_Fit" \
NH_DATA_RECEIVED="July 9, 2026" \
./render.sh --force
```

`R/inventory.R` is a throwaway column/level inventory. It prints names,
year counts, and unique levels only — never student rows.

## What the caches contain

`summary/nh_sgp_summary.rds` (NH SAS):

| Element | Contents |
|---|---|
| `meta` | Run date, source-file mtime, `SGP` package version, N tested / with growth, years available |
| `overall` | mean/median/SD/N of cohort & baseline SGP by content area × grade × year |
| `levels` | Low/Typical/High distribution (cohort & baseline) |
| `subgroups` | Analysis-year subgroup means by content × grade × group |
| `subgroups_pooled` | Analysis-year subgroup means pooled across grades |
| `targets` | Catch-up/keep-up & move-up/stay-up attainment by grade, with Wilson intervals and horizon |
| `targets_prior` | Catch-up/keep-up by prior achievement level |
| `proficiency` | Percent proficient by content area × grade × year |
| `sgp_distribution` | Cohort and baseline SGP distributions by decile |

`summary/nh_wida_summary.rds` (WIDA ACCESS):

| Element | Contents |
|---|---|
| `meta` | Exit level (4.5), 6-year CUKU column names, N tested / with growth |
| `participation` | N tested and N with cohort / baseline SGP by year and grade |
| `levels_dist` / `levels_at_exit` | Achievement-level distribution and percent at or above 4.5 |
| `sgp_overall` | 2026 mean/median/N by grade (cohort and baseline) |
| `sgp_trend` | Mean baseline SGP by year and grade |
| `scale_transition` | 2026 new-vs-old correlation and mean difference, consortium NEW_to_OLD linkage residual, the 4.5 cut on each scale (new = smallest new score linked to the old cut), % ≥ 4.5 on the old composite and on the new composite at the matched cut, and the invalid old-cuts-on-new-scores rate |
| `level_crosstab` | Reported level × old-scale level |
| `concordance_curves` | Consortium NEW_to_OLD concordance on a 100–600 grid, one curve per grade cluster (grades sharing a table are grouped automatically); no student data |
| `cut45_curves` | 4.5 cut by grade: old, concordance-matched new, isotonic and concave-monotone smoothed new (what-if for standard setting; after `SGP_Sandbox/WIDA_SCALE_SCORE_TRANSITION_2026`) |
| `cut45_whatif` | % of 2026 students ≥ 4.5 on the new composite under the matched, isotonic and concave-monotone cuts, and % whose classification changes |
| `on_track_grade` / `on_track_level` | Baseline 6-year catch-up rates with Wilson intervals (the 6-year CUKU column codes students who started below 4.5; Keep Up is not present) |
| `years_to_target` | Distribution of years to Level 4.5 |
| `on_track_compare` | Cohort vs baseline catch-up/keep-up (discussion item) |

## Files

```
New_Hampshire_2026_SGP_Results.qmd   deck source (reads the caches)
R/00_helpers.R                       recodes, labels, mean/median/N formatting
R/01_generate_summary.R              NH SAS LONG ─► summary/nh_sgp_summary.rds
R/02_collect_figures.R               Goodness_of_Fit ─► Figures/gof/*.svg
R/03_generate_wida_summary.R         WIDA LONG ─► summary/nh_wida_summary.rds
R/inventory.R                        column/level inventory (no student rows)
summary/*.rds                        compact cached summaries
Figures/gof/                         vendored goodness-of-fit SVGs + manifest.csv
render.sh · Makefile                 pipeline orchestration
docs/index.html                      rendered deck
styles/                              reveal.js theme + figure lightbox
```

Student-level `.Rdata` / `.rda` / `.txt.zip` files are gitignored and must
never be committed.

## Requirements

- [Quarto](https://quarto.org) ≥ 1.4
- R with `data.table`, `ggplot2`, and the `SGP` package (for the reported
  package version)
