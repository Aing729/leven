# Jamo decomposition and the vocabulary V

**Status: v1.0 — locked. Do not renumber existing indices. To extend, bump `V_version` and append.**

This document defines the symbol set V used by every cost matrix in this project, and the rules for converting between Korean text and sequences of V indices. Every `.mat` artifact records its `V_version`; loading a `.mat` against a mismatched V is a hard error.

## V_version

```
V_version = "v1.0"
|V| = 145
```

## V layout

V is partitioned into ordered groups. Within each group, ordering follows the canonical Unicode / KS X 1001 sequence. Group boundaries are kept aligned to round-number index ranges where possible to make heatmap visualization easier to read.

| Idx range | Count | Group | Notes |
|---|---|---|---|
| 1 | 1 | `<eps>` | Epsilon. Used by alignment to mark insertion/deletion positions. Never appears in a decomposed string. |
| 2 | 1 | `<unk>` | Out-of-vocabulary placeholder. Used only in lenient mode. |
| 3 | 1 | `<no_final>` | Marks the jongseong (final) slot of a syllable that has no batchim. |
| 4–22 | 19 | Choseong (initial) | ㄱ ㄲ ㄴ ㄷ ㄸ ㄹ ㅁ ㅂ ㅃ ㅅ ㅆ ㅇ ㅈ ㅉ ㅊ ㅋ ㅌ ㅍ ㅎ |
| 23–43 | 21 | Jungseong (medial) | ㅏ ㅐ ㅑ ㅒ ㅓ ㅔ ㅕ ㅖ ㅗ ㅘ ㅙ ㅚ ㅛ ㅜ ㅝ ㅞ ㅟ ㅠ ㅡ ㅢ ㅣ |
| 44–70 | 27 | Jongseong (final) | ㄱ ㄲ ㄳ ㄴ ㄵ ㄶ ㄷ ㄹ ㄺ ㄻ ㄼ ㄽ ㄾ ㄿ ㅀ ㅁ ㅂ ㅄ ㅅ ㅆ ㅇ ㅈ ㅊ ㅋ ㅌ ㅍ ㅎ |
| 71–96 | 26 | ASCII uppercase | A B C D E F G H I J K L M N O P Q R S T U V W X Y Z |
| 97–122 | 26 | ASCII lowercase | a b c d e f g h i j k l m n o p q r s t u v w x y z |
| 123–132 | 10 | Digits | 0 1 2 3 4 5 6 7 8 9 |
| 133 | 1 | Whitespace | (single space, U+0020) |
| 134–145 | 12 | Punctuation | `.` `,` `!` `?` `:` `;` `'` `"` `(` `)` `-` `/` |

Note: choseong ㄱ (idx 4) and jongseong ㄱ (idx 44) are **distinct symbols**. Same glyph shape, different positional role, different OCR confusion patterns. The model learns each independently.

Punctuation set notes:
- `'` is U+0027 (ASCII apostrophe), not U+2019 (right single quotation mark).
- `"` is U+0022 (ASCII quotation mark), not U+201C/U+201D (curly quotes).
- `-` is U+002D (hyphen-minus), not U+2010 / U+2013 / U+2014 (other dashes).
- `/` (forward slash) added to cover dates and ratios common in OCR text.

If a corpus contains curly quotes, em dashes, etc., they are OOV and handled per the OOV policy below. A future V version may normalize them, but v1.0 keeps the set strictly ASCII-printable.

## Hangul syllable decomposition

A precomposed Hangul syllable in the Unicode block U+AC00–U+D7A3 (가–힣, 11 172 syllables) is decomposed via the standard formula:

```
let s   = codepoint(syllable)
let n   = s - 0xAC00                  % 0 .. 11171
let cho = floor(n / 588)              % 0 .. 18    (588 = 21 * 28)
let jng = floor((n mod 588) / 28)     % 0 .. 20
let jng_offset = n mod 28             % 0 .. 27

if jng_offset == 0:
    jong = <no_final>
else:
    jong = jongseong[jng_offset - 1]  % map 1..27 to V indices 44..70
```

The `cho`, `jng`, `jng_offset` indices map into the choseong / jungseong / jongseong groups in V (in their canonical Unicode order, which matches the table above).

A syllable always decomposes to **exactly 3 V symbols** (cho, jng, jong-or-`<no_final>`). This invariant is what makes downstream code simple — every Hangul syllable contributes the same length to the decomposed sequence.

## Recomposition

Given a sequence of V indices, recomposition walks left-to-right and tries to assemble Hangul syllables greedily:

```
when seeing (cho, jng, X) where:
  cho is in choseong group (idx 4..22)
  jng is in jungseong group (idx 23..43)
  X   is in jongseong group (idx 44..70) or is <no_final> (idx 3)
=> emit one Hangul syllable
   syllable_codepoint = 0xAC00
                      + cho_offset * 588
                      + jng_offset * 28
                      + (X == <no_final> ? 0 : jongseong_offset(X) + 1)

otherwise:
=> emit each V index as its own character
   (jamo standalone, ASCII, digit, punctuation, whitespace)
```

Standalone jamo (a choseong, jungseong, or jongseong that does not form part of a valid triple) is rendered using the **Hangul Compatibility Jamo** block (U+3131–U+318E), not the Hangul Jamo block (U+1100–U+11FF). Compatibility jamo are what users see when typing on a Korean keyboard; the U+1100 block is for combining-jamo composition and renders awkwardly in most fonts.

`<eps>` and `<unk>` are never emitted by recomposition. If they appear in the input sequence, recomposition raises `led:recompose:NonRenderableSymbol` — recompose is for round-tripping clean sequences, not for rendering arbitrary internal state.

## Non-Hangul characters

Each non-Hangul character in V maps to its single V index — no decomposition. ASCII letters, digits, whitespace, and the 12 punctuation marks pass through 1-to-1.

## OOV policy

`led.decompose` accepts an `arguments` block:

```matlab
function seq = decompose(s, opts)
    arguments
        s (1,1) string
        opts.Mode (1,1) string {mustBeMember(opts.Mode, ["strict","lenient"])} = "strict"
    end
end
```

- `Mode = "strict"` (default): any character not in V causes `error("led:decompose:UnknownChar", ...)` with the offending character and its codepoint in the message.
- `Mode = "lenient"`: any character not in V is replaced with `<unk>` (idx 2). The function returns normally.

Why strict by default: silent OOV substitution is the kind of bug that destroys evaluation results without anyone noticing. The default makes data quality problems loud. Production training/eval scripts opt into lenient mode explicitly:

```matlab
seq = led.decompose(s, Mode="lenient");
```

## Whitespace handling

Only U+0020 (regular space) is in V. Tabs, newlines, non-breaking space (U+00A0), full-width space (U+3000), etc., are OOV.

Reasoning: OCR output is typically space-normalized before reaching this pipeline (one whitespace = one space). If a corpus has tabs or other whitespace, the data preprocessing step should normalize them; we don't carry that responsibility into the cost model.

## Errors

All errors raised by decompose/recompose use the `led:` namespace:

| Identifier | When |
|---|---|
| `led:decompose:UnknownChar` | strict mode, character not in V |
| `led:recompose:NonRenderableSymbol` | input sequence contains `<eps>` or `<unk>` |
| `led:recompose:InvalidIndex` | input sequence contains an integer outside [1, 145] |

## Round-trip test cases

Every test case below must satisfy: `recompose(decompose(s)) == s` (strict mode where no OOV; lenient mode otherwise, which is then a one-way test).

### Pure Hangul (round-trip required)

| Input | Decomposed length | Notes |
|---|---|---|
| `"가"` | 3 | Single syllable, no batchim |
| `"각"` | 3 | Single syllable, with batchim |
| `"한국어"` | 9 | 3 syllables, mixed batchim |
| `"읽다"` | 6 | Includes complex jongseong (ㄺ) |
| `"꽃"` | 3 | Tense choseong + complex jongseong (ㅊ here is simple, but tests ㄲ as choseong) |

### Mixed (round-trip required)

| Input | Decomposed length | Notes |
|---|---|---|
| `"Hello, 한국!"` | 5 + 1 + 1 + 1 + 3 + 1 = 12 | ASCII + comma + space + Hangul + punctuation. Verifies group boundaries. |
| `"2024년 12월"` | 4 + 6 + 1 + 2 + 3 = 16 | Digits + Hangul + space + digits + Hangul |

### OOV (lenient one-way; strict must raise)

| Input | Strict result | Lenient result |
|---|---|---|
| `"漢字"` | raises `led:decompose:UnknownChar` on `漢` | `[<unk>, <unk>]`, length 2 |
| `"café"` | raises on `é` | `[c, a, f, <unk>]`, length 4 |
| `"a\tb"` (tab) | raises on `\t` | `[a, <unk>, b]`, length 3 |

### Edge cases

| Input | Behavior |
|---|---|
| `""` (empty string) | Returns empty `int32` column vector. Both modes. |
| `" "` (single space) | Returns `[133]` (idx of space). |
| Already-decomposed jamo, e.g. `"ㄱㅏ"` (compatibility jamo block) | Treated as two standalone jamo. Each maps to its V index in the appropriate group. Round-trips back to compatibility jamo block (NOT recomposed into `"가"`). |

The last edge case is worth highlighting. `"가"` (U+AC00, precomposed) and `"ㄱㅏ"` (two compatibility jamo) are different inputs and produce different decomposed sequences (length 3 vs length 2). This is intentional: precomposed and decomposed inputs carry different information about the source text. We do not normalize one to the other.

## What this document does NOT cover

- The cost matrix shape or training algorithm (see `references/training_em.md`, `references/training_embedding.md`).
- The Levenshtein DP itself (see `references/levenshtein.md`).
- How OOV-bearing sequences participate in cost learning (the `<unk>` symbol gets a row/column in `sub_cost`, but its semantics — should it be a free-substitution wildcard? — are a training-time decision, not a vocabulary-time one).

## Changelog

- **v1.0** (initial): 145 symbols. Choseong/jongseong separated. ASCII printable subset of punctuation. Hanja and curly quotes are OOV.