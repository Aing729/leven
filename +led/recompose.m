function s = recompose(seq)
%RECOMPOSE  Convert a sequence of V indices back to a string.
%
%   s = led.recompose(seq)
%
%   Inputs:
%       seq : int32 column vector of V indices in [1, 145].
%
%   Output:
%       s   : (1,1) string. The recomposed text.
%
%   Behavior follows references/jamo.md v1.0:
%   - Walks left-to-right. When the next 3 indices form
%     (choseong, jungseong, jongseong-or-<no_final>), emits one Hangul
%     syllable. Otherwise emits each index as its own character.
%   - Standalone choseong/jungseong/jongseong indices (not part of a
%     syllable triple) emit as Hangul Compatibility Jamo (U+31xx),
%     NOT as Hangul Jamo block (U+11xx).
%   - Errors:
%       led:recompose:NonRenderableSymbol  -- input contains <eps> or <unk>
%       led:recompose:InvalidIndex         -- input contains an integer
%                                             outside [1, 145]
%   - For sequences produced by led.decompose on a valid input string,
%     recompose(decompose(s)) == s.
%
%   See also led.decompose

    arguments
        seq (:,1) int32
    end

    [vSizes, idxToCompat, idxToChar] = buildReverseTables();

    n = numel(seq);
    if n == 0
        s = "";
        return
    end

    % Validate range up-front so we can give clean error messages.
    badRange = seq < 1 | seq > vSizes.total;
    if any(badRange)
        firstBad = find(badRange, 1);
        error("led:recompose:InvalidIndex", ...
            "seq(%d) = %d is outside [1, %d].", ...
            firstBad, seq(firstBad), vSizes.total);
    end

    % <eps> and <unk> are not renderable.
    badRender = seq == vSizes.eps | seq == vSizes.unk;
    if any(badRender)
        firstBad = find(badRender, 1);
        if seq(firstBad) == vSizes.eps
            sym = "<eps>";
        else
            sym = "<unk>";
        end
        error("led:recompose:NonRenderableSymbol", ...
            "seq(%d) is %s (idx %d). recompose is for round-tripping clean " + ...
            "sequences only.", firstBad, sym, seq(firstBad));
    end

    % --- Walk the sequence ---
    % Pre-allocate output buffer of UTF-16 code units. Worst case: every
    % index emits one char (for ASCII / digit / punct / standalone jamo /
    % <no_final>). Hangul syllables compress 3 indices into 1 char, so
    % the output is at most n chars long.
    HANGUL_BASE = uint32(hex2dec('AC00'));
    out = zeros(1, n, 'uint32');
    k = 0;     % output cursor
    i = 1;     % input cursor

    while i <= n
        idx = seq(i);

        % Try to match a Hangul syllable triple starting at i.
        if i + 2 <= n ...
                && isChoseong(idx, vSizes) ...
                && isJungseong(seq(i+1), vSizes) ...
                && (isJongseong(seq(i+2), vSizes) || seq(i+2) == vSizes.noFinal)
            % Compose syllable.
            cho_off = double(idx - vSizes.choStart);                     % 0..18
            jng_off = double(seq(i+1) - vSizes.jngStart);                % 0..20
            if seq(i+2) == vSizes.noFinal
                jong_part = 0;
            else
                jong_part = double(seq(i+2) - vSizes.jongStart) + 1;     % 1..27
            end
            cp = HANGUL_BASE + uint32(cho_off * 588 + jng_off * 28 + jong_part);
            k = k + 1;
            out(k) = cp;
            i = i + 3;
            continue
        end

        % Fall through: emit this single index as its own character.
        if idx == vSizes.noFinal
            % <no_final> outside a syllable triple is a malformed sequence.
            % Decompose never produces this; we treat it as non-renderable.
            error("led:recompose:NonRenderableSymbol", ...
                "seq(%d) is <no_final> (idx %d) outside a (cho, jng, jong) triple.", ...
                i, idx);
        end

        if isChoseong(idx, vSizes) || isJungseong(idx, vSizes) || isJongseong(idx, vSizes)
            % Standalone jamo -> compatibility jamo block.
            cp = uint32(idxToCompat(idx));
        else
            % ASCII / digit / space / punctuation -> direct char.
            cp = uint32(idxToChar(idx));
        end
        k = k + 1;
        out(k) = cp;
        i = i + 1;
    end

    s = string(char(out(1:k)));
end

% =========================================================================
% Reverse lookup tables. Cached.
% =========================================================================

function [vSizes, idxToCompat, idxToChar] = buildReverseTables()
    persistent cachedSizes cachedCompat cachedChar
    if ~isempty(cachedSizes)
        vSizes = cachedSizes;
        idxToCompat = cachedCompat;
        idxToChar = cachedChar;
        return
    end

    sizes.eps        = int32(1);
    sizes.unk        = int32(2);
    sizes.noFinal    = int32(3);
    sizes.choStart   = int32(4);    % 19 entries, idx 4..22
    sizes.jngStart   = int32(23);   % 21 entries, idx 23..43
    sizes.jongStart  = int32(44);   % 27 entries, idx 44..70
    sizes.upperStart = int32(71);   % 26 entries, idx 71..96
    sizes.lowerStart = int32(97);   % 26 entries, idx 97..122
    sizes.digitStart = int32(123);  % 10 entries, idx 123..132
    sizes.space      = int32(133);
    sizes.punctStart = int32(134);  % 12 entries, idx 134..145
    sizes.total      = int32(145);

    % --- Compatibility jamo codepoints, indexed by V index ---
    % These mirror the lists in decompose.m but are organized as
    % idxToCompat(v_index) -> codepoint.
    cho_compat = uint32([ ...
        hex2dec('3131'), hex2dec('3132'), hex2dec('3134'), hex2dec('3137'), ...
        hex2dec('3138'), hex2dec('3139'), hex2dec('3141'), hex2dec('3142'), ...
        hex2dec('3143'), hex2dec('3145'), hex2dec('3146'), hex2dec('3147'), ...
        hex2dec('3148'), hex2dec('3149'), hex2dec('314A'), hex2dec('314B'), ...
        hex2dec('314C'), hex2dec('314D'), hex2dec('314E')]);

    jng_compat = uint32([ ...
        hex2dec('314F'), hex2dec('3150'), hex2dec('3151'), hex2dec('3152'), ...
        hex2dec('3153'), hex2dec('3154'), hex2dec('3155'), hex2dec('3156'), ...
        hex2dec('3157'), hex2dec('3158'), hex2dec('3159'), hex2dec('315A'), ...
        hex2dec('315B'), hex2dec('315C'), hex2dec('315D'), hex2dec('315E'), ...
        hex2dec('315F'), hex2dec('3160'), hex2dec('3161'), hex2dec('3162'), ...
        hex2dec('3163')]);

    jong_compat = uint32([ ...
        hex2dec('3131'), hex2dec('3132'), hex2dec('3133'), hex2dec('3134'), ...
        hex2dec('3135'), hex2dec('3136'), hex2dec('3137'), hex2dec('3139'), ...
        hex2dec('313A'), hex2dec('313B'), hex2dec('313C'), hex2dec('313D'), ...
        hex2dec('313E'), hex2dec('313F'), hex2dec('3140'), hex2dec('3141'), ...
        hex2dec('3142'), hex2dec('3144'), hex2dec('3145'), hex2dec('3146'), ...
        hex2dec('3147'), hex2dec('3148'), hex2dec('314A'), hex2dec('314B'), ...
        hex2dec('314C'), hex2dec('314D'), hex2dec('314E')]);

    % Build a single array indexed by V index (1..145). Entries we don't
    % care about (eps, unk, no_final, ASCII slots) are 0.
    idxToCompat = zeros(1, double(sizes.total), 'uint32');
    idxToCompat(double(sizes.choStart):double(sizes.choStart)+18) = cho_compat;
    idxToCompat(double(sizes.jngStart):double(sizes.jngStart)+20) = jng_compat;
    idxToCompat(double(sizes.jongStart):double(sizes.jongStart)+26) = jong_compat;

    % --- Direct character codepoints for ASCII / digit / space / punct ---
    idxToChar = zeros(1, double(sizes.total), 'uint32');
    idxToChar(double(sizes.upperStart):double(sizes.upperStart)+25) = uint32('A':'Z');
    idxToChar(double(sizes.lowerStart):double(sizes.lowerStart)+25) = uint32('a':'z');
    idxToChar(double(sizes.digitStart):double(sizes.digitStart)+9)  = uint32('0':'9');
    idxToChar(double(sizes.space)) = uint32(' ');
    idxToChar(double(sizes.punctStart):double(sizes.punctStart)+11) = uint32('.,!?:;''"()-/');

    cachedSizes = sizes;
    cachedCompat = idxToCompat;
    cachedChar = idxToChar;

    vSizes = sizes;
end

% =========================================================================
% Group membership predicates
% =========================================================================

function tf = isChoseong(idx, sz)
    tf = idx >= sz.choStart && idx <= sz.choStart + 18;
end

function tf = isJungseong(idx, sz)
    tf = idx >= sz.jngStart && idx <= sz.jngStart + 20;
end

function tf = isJongseong(idx, sz)
    tf = idx >= sz.jongStart && idx <= sz.jongStart + 26;
end