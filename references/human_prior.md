# Human-specified prior cost matrix

**Status: v1 — specification for `led.human_prior_costs`.**

This document specifies a hand-crafted baseline cost matrix. It is one of the two mandatory baselines in every evaluation (the other is vanilla unit-cost Levenshtein). A learned cost matrix has to beat this baseline to count as a real result; matching only vanilla Levenshtein is too weak a claim.

The prior is **intentionally simple**. It captures broad structural intuition about Korean OCR confusability without claiming domain expertise. Refining it (more confusion pairs, weight tuning) is deferred until learned models give us signal about where the prior is weakest.

## Design philosophy

Two layers:

1. **Group-based defaults** — substitution cost depends on which V groups the two symbols belong to. Within-group substitutions are cheap; cross-group substitutions are expensive. This encodes the structural fact that an OCR system rarely confuses a Hangul jamo with a digit.
2. **Visual-confusion overrides** — a small number of well-known confusion pairs get explicitly lowered costs on top of the group defaults.

Insertion and deletion costs are uniform (1.0) except for `<no_final>`, which gets a lower deletion cost (0.5). Rationale: dropped batchim is a common OCR error and should be cheap to "delete".

## V group reminder (from jamo.md v1.0)

| Group | Idx range |
|---|---|
| `<eps>` | 1 |
| `<unk>` | 2 |
| `<no_final>` | 3 |
| Choseong | 4–22 |
| Jungseong | 23–43 |
| Jongseong | 44–70 |
| ASCII upper | 71–96 |
| ASCII lower | 97–122 |
| Digits | 123–132 |
| Space | 133 |
| Punctuation | 134–145 |

## Substitution cost — group defaults

`sub_cost(i, j)` for `i ≠ j` is determined by the group pair, looked up in this table. For `i == j`, `sub_cost(i, i) = 0` always.

| from \ to | Cho | Jng | Jong | Upper | Lower | Digit | Space | Punct | Special |
|---|---|---|---|---|---|---|---|---|---|
| **Cho** | 0.5 | 1.5 | 1.0 | 2.0 | 2.0 | 2.0 | 2.0 | 2.0 | 1.0 |
| **Jng** | 1.5 | 0.5 | 1.5 | 2.0 | 2.0 | 2.0 | 2.0 | 2.0 | 1.0 |
| **Jong** | 1.0 | 1.5 | 0.5 | 2.0 | 2.0 | 2.0 | 2.0 | 2.0 | 1.0 |
| **Upper** | 2.0 | 2.0 | 2.0 | 1.0 | 0.5 | 1.5 | 2.0 | 2.0 | 1.0 |
| **Lower** | 2.0 | 2.0 | 2.0 | 0.5 | 1.0 | 1.5 | 2.0 | 2.0 | 1.0 |
| **Digit** | 2.0 | 2.0 | 2.0 | 1.5 | 1.5 | 1.0 | 2.0 | 2.0 | 1.0 |
| **Space** | 2.0 | 2.0 | 2.0 | 2.0 | 2.0 | 2.0 | 0   | 2.0 | 1.0 |
| **Punct** | 2.0 | 2.0 | 2.0 | 2.0 | 2.0 | 2.0 | 2.0 | 1.0 | 1.0 |
| **Special** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |

Notes:

- **Special** = `<eps>`, `<unk>`, `<no_final>`. These rows/columns are mostly placeholders. `<eps>` and `<unk>` shouldn't be appearing in normal sub_cost queries during DP (they aren't in decomposed clean text). `<no_final>` does appear, but only in the jongseong slot, so its substitution with anything other than a jongseong or another `<no_final>` is unusual. Setting these to 1.0 is a safe default.
- The **Cho ↔ Jong** cost (1.0) is lower than Cho ↔ Jng (1.5) because choseong and jongseong share many glyph shapes (ㄱ, ㄴ, ㄷ, ㅁ, etc.) — they're "the same letter in a different position". A jng never has the same shape as a cho or jong.
- **Space ↔ Space = 0** is a degenerate case (only one space in V), but kept here for completeness.

## Substitution cost — visual confusion overrides

The following pairs override the group defaults with **lower costs**. All overrides are symmetric — `sub_cost(a, b) == sub_cost(b, a)`. (We may revisit asymmetry in v2 if data supports it.)

### Hangul jamo confusions

Choseong:
- ㅁ ↔ ㅇ : 0.2 (round vs square shape, very common confusion)
- ㄷ ↔ ㄹ : 0.3 (similar horizontal stroke pattern)
- ㅂ ↔ ㅁ : 0.3 (both have closed top)
- ㅈ ↔ ㅊ : 0.3 (differ only by a small stroke on top)
- ㅅ ↔ ㅈ : 0.3 (similar shape, ㅈ has top stroke)

Jungseong:
- ㅏ ↔ ㅑ : 0.3 (ㅑ is ㅏ with extra stroke)
- ㅓ ↔ ㅕ : 0.3 (same pattern)
- ㅗ ↔ ㅛ : 0.3 (same pattern)
- ㅜ ↔ ㅠ : 0.3 (same pattern)

Jongseong (mirror the choseong pairs where the same glyphs appear):
- ㅁ ↔ ㅇ : 0.2
- ㄷ ↔ ㄹ : 0.3
- ㅂ ↔ ㅁ : 0.3

### ASCII / digit confusions

- O (upper) ↔ 0 (digit) : 0.2 (visually nearly identical in many fonts)
- l (lower L) ↔ 1 (digit) : 0.3
- l (lower L) ↔ I (upper i) : 0.3
- I (upper i) ↔ 1 (digit) : 0.3
- S (upper) ↔ 5 (digit) : 0.4
- B (upper) ↔ 8 (digit) : 0.4

Total: 18 override pairs (each contributes 2 matrix entries due to symmetry, so 36 cells of the matrix differ from the group default).

## Insertion / deletion cost

| Symbol | ins_cost | del_cost |
|---|---|---|
| `<eps>` | 1.0 | 1.0 |
| `<unk>` | 1.0 | 1.0 |
| `<no_final>` | 1.0 | 0.5 |
| Everything else | 1.0 | 1.0 |

`<no_final>`'s lower deletion cost reflects that "removing a non-existent batchim" is a common OCR pattern. Insertion stays at 1.0 because hallucinating a batchim where there isn't one is less common.

## What this is NOT

- **Not symmetric in general** — group defaults are symmetric in v1, but the data structure allows asymmetry. v2 may exploit it.
- **Not normalized** — costs are not constrained to sum to anything. They are absolute values that the DP minimizes over.
- **Not learned** — by definition, this is the prior we want learned models to beat.

## Validation

`led.human_prior_costs` returns `(sub_cost, ins_cost, del_cost)` with:

- `sub_cost`: 145 × 145 double, all entries ≥ 0, diagonal exactly 0
- `ins_cost`: 145 × 1 double, all entries ≥ 0
- `del_cost`: 145 × 1 double, all entries ≥ 0

A test asserts these properties plus a few specific sample values from the table.

## Changelog

- **v1** (initial): Group-based defaults + 18 visual confusion overrides. Asymmetry not used. To be benchmarked against learned models.