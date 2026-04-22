# Learned Edit Distance (Korean OCR)

A metric-learned replacement for the 0/1 Levenshtein cost. Substitution / insertion / deletion costs are learned from data so they reflect actual character confusability in Korean OCR post-correction. Strings are processed at the Jamo level.

## Status

Project skeleton only. No functions implemented yet. See `references/` for the design specification (in progress).

## Layout

```
+led/         MATLAB package namespace. Call as led.funcname(...).
experiments/  One subfolder per Experiment Manager project.
data/         raw/ (originals), processed/ (jamo-decomposed .mat), synthetic/ (generated noise).
results/      Per-run cost .mat + eval artifacts. Timestamped subfolders.
reports/      Live Script (.mlx) reports, one per finalized experiment.
references/   Design docs. Read these before changing the corresponding code.
scripts/      One-off scripts (sanity checks, data import, etc.). Not the package API.
```

## Quick start

Nothing to run yet. Next step: lock the vocabulary V in `references/jamo.md`, then implement `+led/decompose.m` and `+led/recompose.m`.

## Conventions

See `references/` for the binding rules. Highlights:

- All strings are Jamo-decomposed before any distance computation.
- Every training run produces a single `.mat` file with `sub_cost`, `ins_cost`, `del_cost`, and a `metadata` struct.
- Costs are a function of the character pair only - DP stays O(nm).
- Every evaluation reports learned vs. vanilla Levenshtein vs. human-prior baseline.