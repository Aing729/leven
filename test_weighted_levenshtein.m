function test_weighted_levenshtein()
%TEST_WEIGHTED_LEVENSHTEIN  Verify led.weighted_levenshtein.
%
%   Run from project root:
%       cd /MATLAB Drive/leven
%       test_weighted_levenshtein

    fprintf('\n=== test_weighted_levenshtein ===\n\n');

    nPass = 0;
    nFail = 0;

    V = 145;

    % Vanilla unit-cost setup: identity is free, everything else is 1.
    sub_unit = ones(V) - eye(V);
    ins_unit = ones(V, 1);
    del_unit = ones(V, 1);

    % --- Group 1: Sanity vs reference Levenshtein with unit costs ---
    fprintf('[Sanity: unit costs match standard Levenshtein]\n');

    % Identical strings -> 0
    [nPass, nFail] = check(nPass, nFail, 'identical "한국어" -> 0', ...
        @() led.weighted_levenshtein( ...
            led.decompose("한국어"), led.decompose("한국어"), ...
            sub_unit, ins_unit, del_unit) == 0);

    % Single substitution: "가" vs "나"
    %   "가" = [4(ㄱ), 23(ㅏ), 3(no_final)]
    %   "나" = [6(ㄴ), 23(ㅏ), 3(no_final)]
    %   One substitution at position 1 -> distance 1.
    [nPass, nFail] = check(nPass, nFail, '"가" vs "나" (one cho substitution) -> 1', ...
        @() led.weighted_levenshtein( ...
            led.decompose("가"), led.decompose("나"), ...
            sub_unit, ins_unit, del_unit) == 1);

    % Pure insertion: "" vs "가" -> 3 (insert 3 symbols)
    [nPass, nFail] = check(nPass, nFail, '"" vs "가" -> 3 (insertion)', ...
        @() led.weighted_levenshtein( ...
            led.decompose(""), led.decompose("가"), ...
            sub_unit, ins_unit, del_unit) == 3);

    % Pure deletion: "가" vs "" -> 3 (delete 3 symbols)
    [nPass, nFail] = check(nPass, nFail, '"가" vs "" -> 3 (deletion)', ...
        @() led.weighted_levenshtein( ...
            led.decompose("가"), led.decompose(""), ...
            sub_unit, ins_unit, del_unit) == 3);

    % Both empty -> 0
    [nPass, nFail] = check(nPass, nFail, '"" vs "" -> 0', ...
        @() led.weighted_levenshtein( ...
            zeros(0,1,'int32'), zeros(0,1,'int32'), ...
            sub_unit, ins_unit, del_unit) == 0);

    % Cross-check: ASCII strings "kitten" vs "sitting"
    % Standard Levenshtein distance is 3 (k->s, e->i, +g).
    [nPass, nFail] = check(nPass, nFail, '"kitten" vs "sitting" -> 3 (classic)', ...
        @() led.weighted_levenshtein( ...
            led.decompose("kitten"), led.decompose("sitting"), ...
            sub_unit, ins_unit, del_unit) == 3);

    % "saturday" vs "sunday" -> 3 (classic)
    [nPass, nFail] = check(nPass, nFail, '"saturday" vs "sunday" -> 3 (classic)', ...
        @() led.weighted_levenshtein( ...
            led.decompose("saturday"), led.decompose("sunday"), ...
            sub_unit, ins_unit, del_unit) == 3);

    % --- Group 2: Symmetry under symmetric costs ---
    fprintf('\n[Symmetry under symmetric costs]\n');
    [nPass, nFail] = check(nPass, nFail, 'd(a,b) == d(b,a) under unit costs', ...
        @() led.weighted_levenshtein( ...
                led.decompose("한국어"), led.decompose("한어"), ...
                sub_unit, ins_unit, del_unit) ...
            == led.weighted_levenshtein( ...
                led.decompose("한어"), led.decompose("한국어"), ...
                sub_unit, ins_unit, del_unit));

    % --- Group 3: Weighted scenarios ---
    fprintf('\n[Custom weights change the result]\n');

    % Set every sub_cost to a uniform 0.5 (off-diagonal). Identity stays 0.
    sub_half = (ones(V) - eye(V)) * 0.5;
    [nPass, nFail] = check(nPass, nFail, 'half-cost substitution: "가" vs "나" -> 0.5', ...
        @() abs(led.weighted_levenshtein( ...
            led.decompose("가"), led.decompose("나"), ...
            sub_half, ins_unit, del_unit) - 0.5) < 1e-12);

    % Make insertion expensive (10), deletion cheap (1).
    % "가" vs "" -> 3 deletions = 3
    % "" vs "가" -> 3 insertions = 30
    ins_expensive = 10 * ones(V, 1);
    del_cheap = 1 * ones(V, 1);
    [nPass, nFail] = check(nPass, nFail, 'asymmetric costs: del 1 / ins 10, "가"->"" = 3', ...
        @() led.weighted_levenshtein( ...
            led.decompose("가"), led.decompose(""), ...
            sub_unit, ins_expensive, del_cheap) == 3);
    [nPass, nFail] = check(nPass, nFail, 'asymmetric costs: del 1 / ins 10, ""->"가" = 30', ...
        @() led.weighted_levenshtein( ...
            led.decompose(""), led.decompose("가"), ...
            sub_unit, ins_expensive, del_cheap) == 30);

    % Substitution preferred when its cost beats ins+del.
    % "가" vs "나" with sub_cost(ㄱ,ㄴ) = 0.1, ins/del = 1:
    %   substitute (cost 0.1) instead of delete-then-insert (cost 2).
    sub_custom = sub_unit;
    sub_custom(4, 6) = 0.1;       % ㄱ -> ㄴ very cheap
    sub_custom(6, 4) = 0.1;       % symmetric
    [nPass, nFail] = check(nPass, nFail, 'cheap (ㄱ->ㄴ)=0.1: "가" vs "나" -> 0.1', ...
        @() abs(led.weighted_levenshtein( ...
            led.decompose("가"), led.decompose("나"), ...
            sub_custom, ins_unit, del_unit) - 0.1) < 1e-12);

    % --- Group 4: Output type & shape ---
    fprintf('\n[Output type]\n');
    out = led.weighted_levenshtein( ...
        led.decompose("가"), led.decompose("나"), sub_unit, ins_unit, del_unit);
    [nPass, nFail] = check(nPass, nFail, 'output is scalar double', ...
        @() isa(out, 'double') && isscalar(out));

    % --- Summary ---
    fprintf('\n=== Result: %d passed, %d failed ===\n', nPass, nFail);
    if nFail > 0
        warning('test_weighted_levenshtein:Failures', '%d test(s) failed.', nFail);
    end
end

% =========================================================================
% Helpers
% =========================================================================

function [nPass, nFail] = check(nPass, nFail, label, predicate)
    try
        ok = predicate();
        if ok
            fprintf('  PASS  %s\n', label);
            nPass = nPass + 1;
        else
            fprintf('  FAIL  %s\n', label);
            nFail = nFail + 1;
        end
    catch ME
        fprintf('  FAIL  %s\n        (threw %s: %s)\n', label, ME.identifier, ME.message);
        nFail = nFail + 1;
    end
end