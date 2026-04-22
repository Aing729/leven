function seq = decompose(s, opts)
%DECOMPOSE  Convert a string to a sequence of V indices.
%
%   seq = led.decompose(s)
%   seq = led.decompose(s, Mode="strict")    % default
%   seq = led.decompose(s, Mode="lenient")
%
%   Inputs:
%       s    : (1,1) string. The text to decompose.
%       Mode : "strict"  -> any character not in V raises
%                          led:decompose:UnknownChar
%              "lenient" -> any character not in V is replaced with <unk>
%
%   Output:
%       seq  : int32 column vector of V indices.
%
%   Behavior follows references/jamo.md v1.0:
%   - Hangul syllables in U+AC00..U+D7A3 decompose to exactly 3 V symbols
%     (choseong, jungseong, jongseong-or-<no_final>).
%   - Non-Hangul characters in V map to their single index.
%   - Standalone compatibility jamo (U+3131..U+318E) map to their position
%     in the choseong/jungseong/jongseong groups (NOT recombined into
%     syllables -- see jamo.md "Edge cases").
%   - V_version locked at "v1.0", |V| = 145.
%
%   See also led.recompose

    arguments
        s (1,1) string
        opts.Mode (1,1) string {mustBeMember(opts.Mode, ["strict", "lenient"])} = "strict"
    end

    [vMap, vSizes] = buildVocab();   % cached on first call

    % Empty string -> empty int32 column.
    if strlength(s) == 0
        seq = zeros(0, 1, 'int32');
        return
    end

    % Convert to a row vector of UTF-16 code units. For chars in the BMP
    % (which covers all of V and standard Hangul), one code unit == one
    % Unicode codepoint, so we can iterate code-unit-wise. Hangul syllables
    % U+AC00..U+D7A3 are all in the BMP.
    chars = char(s);   % row char array

    % Pre-allocate. Worst case: every char is a Hangul syllable (3 indices each).
    n = numel(chars);
    out = zeros(3 * n, 1, 'int32');
    k = 0;

    HANGUL_BASE = uint32(hex2dec('AC00'));
    HANGUL_END  = uint32(hex2dec('D7A3'));

    for i = 1:n
        cp = uint32(chars(i));

        if cp >= HANGUL_BASE && cp <= HANGUL_END
            % Precomposed Hangul syllable -> 3 V symbols.
            n_syl   = cp - HANGUL_BASE;            % 0..11171
            cho_off = floor(double(n_syl) / 588);  % 0..18
            jng_off = floor(mod(double(n_syl), 588) / 28);  % 0..20
            jng_idx = mod(double(n_syl), 28);      % 0..27 (0 means no final)

            out(k+1) = vSizes.choStart + int32(cho_off);
            out(k+2) = vSizes.jngStart + int32(jng_off);
            if jng_idx == 0
                out(k+3) = vSizes.noFinal;
            else
                out(k+3) = vSizes.jongStart + int32(jng_idx - 1);
            end
            k = k + 3;

        elseif isKey(vMap, cp)
            % Single-symbol mapping (ASCII, digit, space, punctuation,
            % standalone compatibility jamo).
            out(k+1) = vMap(cp);
            k = k + 1;

        else
            % Out-of-vocabulary.
            if opts.Mode == "strict"
                error("led:decompose:UnknownChar", ...
                    "Character '%s' (U+%04X) is not in V (v1.0). " + ...
                    "Use Mode=""lenient"" to substitute with <unk>.", ...
                    chars(i), cp);
            else
                out(k+1) = vSizes.unk;
                k = k + 1;
            end
        end
    end

    seq = out(1:k);
end

% =========================================================================
% Vocabulary construction. Cached across calls.
% =========================================================================

function [vMap, vSizes] = buildVocab()
    persistent cachedMap cachedSizes
    if ~isempty(cachedMap)
        vMap = cachedMap;
        vSizes = cachedSizes;
        return
    end

    % --- Index layout (must match references/jamo.md v1.0) ---
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

    % --- Compatibility jamo codepoints (U+31xx) for standalone jamo input ---
    % These are the chars users actually type/see; the U+11xx Hangul Jamo
    % block is for combining and renders awkwardly. We map standalone
    % compatibility jamo to the same V indices as syllable-internal jamo.
    %
    % Compatibility jamo block ordering does NOT directly match Unicode
    % syllable-internal ordering for jongseong, so we list each explicitly.

    cho_compat = [ ...
        hex2dec('3131'), ... % ㄱ
        hex2dec('3132'), ... % ㄲ
        hex2dec('3134'), ... % ㄴ
        hex2dec('3137'), ... % ㄷ
        hex2dec('3138'), ... % ㄸ
        hex2dec('3139'), ... % ㄹ
        hex2dec('3141'), ... % ㅁ
        hex2dec('3142'), ... % ㅂ
        hex2dec('3143'), ... % ㅃ
        hex2dec('3145'), ... % ㅅ
        hex2dec('3146'), ... % ㅆ
        hex2dec('3147'), ... % ㅇ
        hex2dec('3148'), ... % ㅈ
        hex2dec('3149'), ... % ㅉ
        hex2dec('314A'), ... % ㅊ
        hex2dec('314B'), ... % ㅋ
        hex2dec('314C'), ... % ㅌ
        hex2dec('314D'), ... % ㅍ
        hex2dec('314E')];    % ㅎ

    jng_compat = [ ...
        hex2dec('314F'), ... % ㅏ
        hex2dec('3150'), ... % ㅐ
        hex2dec('3151'), ... % ㅑ
        hex2dec('3152'), ... % ㅒ
        hex2dec('3153'), ... % ㅓ
        hex2dec('3154'), ... % ㅔ
        hex2dec('3155'), ... % ㅕ
        hex2dec('3156'), ... % ㅖ
        hex2dec('3157'), ... % ㅗ
        hex2dec('3158'), ... % ㅘ
        hex2dec('3159'), ... % ㅙ
        hex2dec('315A'), ... % ㅚ
        hex2dec('315B'), ... % ㅛ
        hex2dec('315C'), ... % ㅜ
        hex2dec('315D'), ... % ㅝ
        hex2dec('315E'), ... % ㅞ
        hex2dec('315F'), ... % ㅟ
        hex2dec('3160'), ... % ㅠ
        hex2dec('3161'), ... % ㅡ
        hex2dec('3162'), ... % ㅢ
        hex2dec('3163')];    % ㅣ

    % Jongseong group, in V's canonical (Unicode syllable-internal) order:
    % ㄱ ㄲ ㄳ ㄴ ㄵ ㄶ ㄷ ㄹ ㄺ ㄻ ㄼ ㄽ ㄾ ㄿ ㅀ ㅁ ㅂ ㅄ ㅅ ㅆ ㅇ ㅈ ㅊ ㅋ ㅌ ㅍ ㅎ
    jong_compat = [ ...
        hex2dec('3131'), ... % ㄱ  (note: same compat codepoint as choseong ㄱ)
        hex2dec('3132'), ... % ㄲ
        hex2dec('3133'), ... % ㄳ
        hex2dec('3134'), ... % ㄴ
        hex2dec('3135'), ... % ㄵ
        hex2dec('3136'), ... % ㄶ
        hex2dec('3137'), ... % ㄷ
        hex2dec('3139'), ... % ㄹ
        hex2dec('313A'), ... % ㄺ
        hex2dec('313B'), ... % ㄻ
        hex2dec('313C'), ... % ㄼ
        hex2dec('313D'), ... % ㄽ
        hex2dec('313E'), ... % ㄾ
        hex2dec('313F'), ... % ㄿ
        hex2dec('3140'), ... % ㅀ
        hex2dec('3141'), ... % ㅁ
        hex2dec('3142'), ... % ㅂ
        hex2dec('3144'), ... % ㅄ
        hex2dec('3145'), ... % ㅅ
        hex2dec('3146'), ... % ㅆ
        hex2dec('3147'), ... % ㅇ
        hex2dec('3148'), ... % ㅈ
        hex2dec('314A'), ... % ㅊ
        hex2dec('314B'), ... % ㅋ
        hex2dec('314C'), ... % ㅌ
        hex2dec('314D'), ... % ㅍ
        hex2dec('314E')];    % ㅎ

    % --- Build the lookup dictionary ---
    % NOTE on conflict: some compatibility codepoints are valid as both
    % choseong and jongseong (e.g. ㄱ at U+3131). The user-facing intent for
    % a standalone compat jamo is ambiguous. We resolve by mapping it to its
    % CHOSEONG index. This is the more common interpretation when typing
    % isolated jamo (e.g. learning materials show "ㄱ" as the initial sound).
    % This decision is documented; round-tripping a standalone-jong-only
    % input is not a goal of v1.0.

    keys = uint32([]);
    vals = int32([]);

    % Choseong compatibility jamo
    keys = [keys, uint32(cho_compat)];
    vals = [vals, sizes.choStart + int32(0:18)];

    % Jungseong compatibility jamo
    keys = [keys, uint32(jng_compat)];
    vals = [vals, sizes.jngStart + int32(0:20)];

    % Jongseong compatibility jamo -- only add ones that don't already exist
    % as choseong (resolves the ambiguity above by keeping the choseong
    % mapping). The exclusively-jongseong ones (ㄳ ㄵ ㄶ ㄺ ㄻ ㄼ ㄽ ㄾ ㄿ ㅀ ㅄ)
    % do get added here.
    for j = 1:numel(jong_compat)
        if ~ismember(uint32(jong_compat(j)), keys)
            keys = [keys, uint32(jong_compat(j))];
            vals = [vals, sizes.jongStart + int32(j - 1)];
        end
    end

    % ASCII uppercase A-Z
    keys = [keys, uint32('A':'Z')];
    vals = [vals, sizes.upperStart + int32(0:25)];

    % ASCII lowercase a-z
    keys = [keys, uint32('a':'z')];
    vals = [vals, sizes.lowerStart + int32(0:25)];

    % Digits 0-9
    keys = [keys, uint32('0':'9')];
    vals = [vals, sizes.digitStart + int32(0:9)];

    % Space
    keys = [keys, uint32(' ')];
    vals = [vals, sizes.space];

    % Punctuation: . , ! ? : ; ' " ( ) - /
    punct = uint32('.,!?:;''"()-/');
    keys = [keys, punct];
    vals = [vals, sizes.punctStart + int32(0:11)];

    % Build dictionary. Requires R2022b+.
    cachedMap = dictionary(keys, vals);
    cachedSizes = sizes;

    vMap = cachedMap;
    vSizes = cachedSizes;
end