function [sub_cost, ins_cost, del_cost] = human_prior_costs()
%HUMAN_PRIOR_COSTS  Hand-specified baseline cost matrix.
%
%   [sub_cost, ins_cost, del_cost] = led.human_prior_costs()
%
%   Outputs:
%       sub_cost : 145 x 145 double. sub_cost(i, j) = substitution cost.
%                  Diagonal is 0 (identity is free).
%       ins_cost : 145 x 1 double. Insertion cost per symbol.
%       del_cost : 145 x 1 double. Deletion cost per symbol.
%
%   Specification: references/human_prior.md v1.
%   - Group-based defaults (cho/jng/jong/upper/lower/digit/space/punct/special)
%   - 18 visual confusion overrides (symmetric)
%   - <no_final> has lower del_cost (0.5)
%
%   This is a baseline. Learned models in this project are required to
%   beat it to count as a real result.
%
%   See also led.weighted_levenshtein

    V = 145;

    % --- Group index ranges (must match jamo.md v1.0) ---
    sizes.eps        = 1;
    sizes.unk        = 2;
    sizes.noFinal    = 3;
    sizes.choStart   = 4;    sizes.choEnd   = 22;
    sizes.jngStart   = 23;   sizes.jngEnd   = 43;
    sizes.jongStart  = 44;   sizes.jongEnd  = 70;
    sizes.upperStart = 71;   sizes.upperEnd = 96;
    sizes.lowerStart = 97;   sizes.lowerEnd = 122;
    sizes.digitStart = 123;  sizes.digitEnd = 132;
    sizes.space      = 133;
    sizes.punctStart = 134;  sizes.punctEnd = 145;

    % --- Build a per-index group label vector ---
    % Group codes:
    %   1 = special (eps, unk, no_final)
    %   2 = cho
    %   3 = jng
    %   4 = jong
    %   5 = upper
    %   6 = lower
    %   7 = digit
    %   8 = space
    %   9 = punct
    grp = zeros(V, 1, 'int32');
    grp([sizes.eps, sizes.unk, sizes.noFinal]) = 1;
    grp(sizes.choStart:sizes.choEnd)     = 2;
    grp(sizes.jngStart:sizes.jngEnd)     = 3;
    grp(sizes.jongStart:sizes.jongEnd)   = 4;
    grp(sizes.upperStart:sizes.upperEnd) = 5;
    grp(sizes.lowerStart:sizes.lowerEnd) = 6;
    grp(sizes.digitStart:sizes.digitEnd) = 7;
    grp(sizes.space)                     = 8;
    grp(sizes.punctStart:sizes.punctEnd) = 9;

    % --- Group-pair cost table (rows/cols match group codes 1..9) ---
    %         spec  cho  jng  jong upper lower digit space punct
    %    1   2    3    4    5     6     7     8     9
    G = [    1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0;   % 1 special
             1.0  0.5  1.5  1.0  2.0  2.0  2.0  2.0  2.0;   % 2 cho
             1.0  1.5  0.5  1.5  2.0  2.0  2.0  2.0  2.0;   % 3 jng
             1.0  1.0  1.5  0.5  2.0  2.0  2.0  2.0  2.0;   % 4 jong
             1.0  2.0  2.0  2.0  1.0  0.5  1.5  2.0  2.0;   % 5 upper
             1.0  2.0  2.0  2.0  0.5  1.0  1.5  2.0  2.0;   % 6 lower
             1.0  2.0  2.0  2.0  1.5  1.5  1.0  2.0  2.0;   % 7 digit
             1.0  2.0  2.0  2.0  2.0  2.0  2.0  0.0  2.0;   % 8 space
             1.0  2.0  2.0  2.0  2.0  2.0  2.0  2.0  1.0];  % 9 punct

    % --- Fill sub_cost from group table ---
    % Vectorized: sub_cost(i, j) = G(grp(i), grp(j)).
    [I, J] = ndgrid(1:V, 1:V);
    sub_cost = G(sub2ind(size(G), grp(I), grp(J)));

    % --- Diagonal exactly 0 (identity is free) ---
    sub_cost(1:V+1:end) = 0;

    % --- Visual confusion overrides (symmetric) ---
    % Choseong indices in V (idx 4..22 in canonical order):
    %   4=ㄱ 5=ㄲ 6=ㄴ 7=ㄷ 8=ㄸ 9=ㄹ 10=ㅁ 11=ㅂ 12=ㅃ 13=ㅅ 14=ㅆ 15=ㅇ
    %   16=ㅈ 17=ㅉ 18=ㅊ 19=ㅋ 20=ㅌ 21=ㅍ 22=ㅎ
    cho = struct('g', 4, 'kk', 5, 'n', 6, 'd', 7, 'dd', 8, 'r', 9, ...
                 'm', 10, 'b', 11, 'bb', 12, 's', 13, 'ss', 14, 'o', 15, ...
                 'j', 16, 'jj', 17, 'ch', 18, 'k', 19, 't', 20, 'p', 21, 'h', 22);

    % Jungseong indices (23..43):
    %   23=ㅏ 24=ㅐ 25=ㅑ 26=ㅒ 27=ㅓ 28=ㅔ 29=ㅕ 30=ㅖ 31=ㅗ 32=ㅘ 33=ㅙ
    %   34=ㅚ 35=ㅛ 36=ㅜ 37=ㅝ 38=ㅞ 39=ㅟ 40=ㅠ 41=ㅡ 42=ㅢ 43=ㅣ
    jng = struct('a', 23, 'ya', 25, 'eo', 27, 'yeo', 29, ...
                 'o', 31, 'yo', 35, 'u', 36, 'yu', 40);

    % Jongseong indices (44..70). Names suffixed with _f for "final":
    %   44=ㄱ 45=ㄲ 46=ㄳ 47=ㄴ 48=ㄵ 49=ㄶ 50=ㄷ 51=ㄹ 52=ㄺ 53=ㄻ 54=ㄼ
    %   55=ㄽ 56=ㄾ 57=ㄿ 58=ㅀ 59=ㅁ 60=ㅂ 61=ㅄ 62=ㅅ 63=ㅆ 64=ㅇ 65=ㅈ
    %   66=ㅊ 67=ㅋ 68=ㅌ 69=ㅍ 70=ㅎ
    jong = struct('g', 44, 'n', 47, 'd', 50, 'r', 51, 'm', 59, 'b', 60, 'o', 64);

    % ASCII indices: A=71, ..., I=79, ..., O=85, ..., Z=96
    %                a=97, ..., l=108, ..., z=122
    %                0=123, 1=124, ..., 9=132
    upI = 71 + ('I' - 'A');   % 79
    upO = 71 + ('O' - 'A');   % 85
    upS = 71 + ('S' - 'A');   % 89
    upB = 71 + ('B' - 'A');   % 72
    loL = 97 + ('l' - 'a');   % 108
    d0  = 123;
    d1  = 124;
    d5  = 128;
    d8  = 131;

    overrides = {
        % --- Choseong confusions ---
        cho.m,  cho.o,  0.2;   % ㅁ ↔ ㅇ
        cho.d,  cho.r,  0.3;   % ㄷ ↔ ㄹ
        cho.b,  cho.m,  0.3;   % ㅂ ↔ ㅁ
        cho.j,  cho.ch, 0.3;   % ㅈ ↔ ㅊ
        cho.s,  cho.j,  0.3;   % ㅅ ↔ ㅈ

        % --- Jungseong confusions ---
        jng.a,   jng.ya,  0.3;  % ㅏ ↔ ㅑ
        jng.eo,  jng.yeo, 0.3;  % ㅓ ↔ ㅕ
        jng.o,   jng.yo,  0.3;  % ㅗ ↔ ㅛ
        jng.u,   jng.yu,  0.3;  % ㅜ ↔ ㅠ

        % --- Jongseong confusions (mirror cho where applicable) ---
        jong.m,  jong.o,  0.2;  % ㅁ ↔ ㅇ
        jong.d,  jong.r,  0.3;  % ㄷ ↔ ㄹ
        jong.b,  jong.m,  0.3;  % ㅂ ↔ ㅁ

        % --- ASCII / digit confusions ---
        upO,  d0,  0.2;         % O ↔ 0
        loL,  d1,  0.3;         % l ↔ 1
        loL,  upI, 0.3;         % l ↔ I
        upI,  d1,  0.3;         % I ↔ 1
        upS,  d5,  0.4;         % S ↔ 5
        upB,  d8,  0.4;         % B ↔ 8
    };

    % Apply overrides symmetrically.
    for k = 1:size(overrides, 1)
        a = overrides{k, 1};
        b = overrides{k, 2};
        c = overrides{k, 3};
        sub_cost(a, b) = c;
        sub_cost(b, a) = c;
    end

    % --- Insertion / deletion costs ---
    ins_cost = ones(V, 1);
    del_cost = ones(V, 1);
    del_cost(sizes.noFinal) = 0.5;   % dropping a non-existent batchim is cheap
end