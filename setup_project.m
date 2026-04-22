function setup_project()
%SETUP_PROJECT  Create the learned-edit-distance project skeleton.
%
%   Run this from MATLAB Online inside a freshly cloned (empty) git repo
%   folder. It is idempotent -- safe to re-run after a partial failure.
%   Existing files are never overwritten.
%
%   Usage (from MATLAB Command Window):
%       cd <repo-folder>     % e.g. cd leven
%       setup_project
%
%   After running, commit the skeleton to git:
%       !git add -A
%       !git commit -m "chore: project skeleton"
%       !git push

    fprintf('Setting up project skeleton in: %s\n\n', pwd);

    % --- 1. Directories ---
    dirs = { ...
        '+led', ...
        'experiments', ...
        'data/raw', 'data/processed', 'data/synthetic', ...
        'results', ...
        'reports', ...
        'references', ...
        'scripts'};

    for i = 1:numel(dirs)
        d = dirs{i};
        if ~exist(d, 'dir')
            mkdir(d);
            fprintf('  created  %s/\n', d);
        else
            fprintf('  exists   %s/\n', d);
        end
    end

    % --- 2. .gitkeep files in each empty dir (best-effort) ---
    keepDirs = { ...
        '+led', ...
        'experiments', ...
        'data/raw', 'data/processed', 'data/synthetic', ...
        'results', ...
        'reports', ...
        'scripts'};
    nKeepOk = 0;
    nKeepFail = 0;
    for i = 1:numel(keepDirs)
        keepFile = fullfile(keepDirs{i}, '.gitkeep');
        if isfile(keepFile)
            nKeepOk = nKeepOk + 1;
            continue
        end
        fid = fopen(keepFile, 'w');
        if fid < 0
            warning('setup_project:GitkeepFailed', ...
                '  could not create %s (skipping; not critical)', keepFile);
            nKeepFail = nKeepFail + 1;
            continue
        end
        fclose(fid);
        nKeepOk = nKeepOk + 1;
    end
    fprintf('  .gitkeep markers: %d ok, %d skipped\n', nKeepOk, nKeepFail);

    % --- 3. .gitignore ---
    writeIfMissing('.gitignore', gitignoreContent());

    % --- 4. README.md ---
    writeIfMissing('README.md', readmeContent());

    % --- 5. references/jamo.md (substantive placeholder) ---
    writeIfMissing(fullfile('references', 'jamo.md'), jamoPlaceholder());

    % --- 6. Other reference placeholders ---
    refs = {'levenshtein', 'training_em', 'training_embedding', ...
            'evaluation', 'experiments', 'experiment_manager', ...
            'data', 'human_prior', 'reporting', 'extensions'};
    for i = 1:numel(refs)
        f = fullfile('references', [refs{i} '.md']);
        writeIfMissing(f, genericPlaceholder(refs{i}));
    end

    % --- Summary ---
    fprintf('\nDone.\n\n');
    if nKeepFail > 0
        fprintf('Note: %d .gitkeep files could not be created (likely +led/).\n', nKeepFail);
        fprintf('      This is harmless -- those folders will get real content soon.\n\n');
    end
    fprintf('Next steps:\n');
    fprintf('  1. Verify the layout:  ls   then   ls references\n');
    fprintf('  2. Commit and push:\n');
    fprintf('       !git add -A\n');
    fprintf('       !git commit -m "chore: project skeleton"\n');
    fprintf('       !git push\n');
    fprintf('  3. Open references/jamo.md and start locking the vocabulary V.\n');
end

% ---------------------------------------------------------------------------
% Helpers
% ---------------------------------------------------------------------------

function writeIfMissing(path, content)
    if isfile(path)
        fprintf('  skipped  %s (already exists, not overwriting)\n', path);
        return
    end
    fid = fopen(path, 'w', 'n', 'UTF-8');
    if fid < 0
        warning('setup_project:WriteFailed', ...
            '  could not write %s (skipping; check permissions)', path);
        return
    end
    fwrite(fid, content, 'char');
    fclose(fid);
    fprintf('  wrote    %s\n', path);
end

function s = gitignoreContent()
    lines = {
        '# --- MATLAB byproducts ---'
        '*.asv'
        '*.m~'
        '*.mex*'
        '*.mlapp.bak'
        'slprj/'
        'sccprj/'
        'codegen/'
        '*.autosave'
        'octave-workspace'
        ''
        '# --- MATLAB project files (optional: comment out if you want to track them) ---'
        '*.prj'
        'resources/'
        ''
        '# --- Data: track folder structure (.gitkeep) but not contents ---'
        'data/raw/*'
        '!data/raw/.gitkeep'
        'data/processed/*'
        '!data/processed/.gitkeep'
        'data/synthetic/*'
        '!data/synthetic/.gitkeep'
        ''
        '# --- Results: experiment outputs are reproducible; don''t commit by default ---'
        '# To keep a specific final result, force-add it: git add -f results/<n>'
        'results/*'
        '!results/.gitkeep'
        ''
        '# --- Reports: track .mlx but not generated HTML/PDF exports ---'
        'reports/*.html'
        'reports/*.pdf'
        'reports/.ipynb_checkpoints/'
        ''
        '# --- OS / editor cruft ---'
        '.DS_Store'
        'Thumbs.db'
        '.vscode/'
        '.idea/'
        '*.swp'
        '*.swo'
        };
    s = strjoin(lines, newline);
end

function s = readmeContent()
    lines = {
        '# Learned Edit Distance (Korean OCR)'
        ''
        'A metric-learned replacement for the 0/1 Levenshtein cost. Substitution / insertion / deletion costs are learned from data so they reflect actual character confusability in Korean OCR post-correction. Strings are processed at the Jamo level.'
        ''
        '## Status'
        ''
        'Project skeleton only. No functions implemented yet. See `references/` for the design specification (in progress).'
        ''
        '## Layout'
        ''
        '```'
        '+led/         MATLAB package namespace. Call as led.funcname(...).'
        'experiments/  One subfolder per Experiment Manager project.'
        'data/         raw/ (originals), processed/ (jamo-decomposed .mat), synthetic/ (generated noise).'
        'results/      Per-run cost .mat + eval artifacts. Timestamped subfolders.'
        'reports/      Live Script (.mlx) reports, one per finalized experiment.'
        'references/   Design docs. Read these before changing the corresponding code.'
        'scripts/      One-off scripts (sanity checks, data import, etc.). Not the package API.'
        '```'
        ''
        '## Quick start'
        ''
        'Nothing to run yet. Next step: lock the vocabulary V in `references/jamo.md`, then implement `+led/decompose.m` and `+led/recompose.m`.'
        ''
        '## Conventions'
        ''
        'See `references/` for the binding rules. Highlights:'
        ''
        '- All strings are Jamo-decomposed before any distance computation.'
        '- Every training run produces a single `.mat` file with `sub_cost`, `ins_cost`, `del_cost`, and a `metadata` struct.'
        '- Costs are a function of the character pair only - DP stays O(nm).'
        '- Every evaluation reports learned vs. vanilla Levenshtein vs. human-prior baseline.'
        };
    s = strjoin(lines, newline);
end

function s = jamoPlaceholder()
    lines = {
        '# Jamo decomposition and the vocabulary V'
        ''
        '**Status: TODO -- to be written next. This document locks V; once finalized, do not renumber.**'
        ''
        '## What this document will contain'
        ''
        '- Exact character set V, with canonical index order'
        '- `V_version` string used in every `.mat` metadata'
        '- Unicode formula for syllable to (chosung, jungsung, jongsung) decomposition'
        '- Handling of standalone Jamo, ASCII, digits, punctuation, whitespace'
        '- Out-of-vocabulary policy (decompose raises `led:decompose:UnknownChar`)'
        '- Round-trip test cases (input strings -> decompose -> recompose -> must equal input)'
        ''
        '## Why this is locked'
        ''
        '`sub_cost(i, j)` is indexed by V order. Every `.mat` file is bound to one V version. Renumbering invalidates every saved cost matrix and every report. Treat V as an immutable artifact of the project.'
        };
    s = strjoin(lines, newline);
end

function s = genericPlaceholder(name)
    lines = {
        ['# ' name]
        ''
        '**Status: TODO**'
        ''
        'This document will be written when work on this area begins. See SKILL.md routing table for what topics it covers.'
        };
    s = strjoin(lines, newline);
end