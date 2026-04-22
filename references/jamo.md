# Jamo decomposition and the vocabulary V

**Status: TODO -- to be written next. This document locks V; once finalized, do not renumber.**

## What this document will contain

- Exact character set V, with canonical index order
- `V_version` string used in every `.mat` metadata
- Unicode formula for syllable to (chosung, jungsung, jongsung) decomposition
- Handling of standalone Jamo, ASCII, digits, punctuation, whitespace
- Out-of-vocabulary policy (decompose raises `led:decompose:UnknownChar`)
- Round-trip test cases (input strings -> decompose -> recompose -> must equal input)

## Why this is locked

`sub_cost(i, j)` is indexed by V order. Every `.mat` file is bound to one V version. Renumbering invalidates every saved cost matrix and every report. Treat V as an immutable artifact of the project.