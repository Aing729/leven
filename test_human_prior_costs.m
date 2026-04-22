function test_human_prior_costs()
%TEST_HUMAN_PRIOR_COSTS  Verify the hand-specified baseline.
%
%   Run from project root:
%       cd /MATLAB Drive/leven
%       test_human_prior_costs

    fprintf('\n=== test_human_prior_costs ===\n\n');

    nPass = 0;
    nFail = 0;

    [sub_cost, ins_cost, del_cost] = led.human_prior_costs();

    % --- Group 1: Shape and basic invariants ---
    fprintf('[Shape & invariants]\n');
    [nPass, nFail] = check(nPass, nFail, 'sub_cost is 145x145 double', ...
        @() isequal(size(sub_cost), [145 145]) && isa(sub_cost, 'double'));
    [nPass, nFail] = check(nPass, nFail, 'ins_cost is 145x1 double', ...
        @() isequal(size(ins_cost), [145 1]) && isa(ins_cost, 'double'));
    [nPass, nFail] = check(nPass, nFail, 'del_cost is 145x1 double', ...
        @() isequal(size(del_cost), [145 1]) && isa(del_cost, 'double'));
    [nPass, nFail] = check(nPass, nFail, 'sub_cost has zero diagonal', ...
        @() all(diag(sub_cost) == 0));
    [nPass, nFail] = check(nPass, nFail, 'sub_cost is non-negative', ...
        @() all(sub_cost(:) >= 0));
    [nPass, nFail] = check(nPass, nFail, 'ins_cost is non-negative', ...
        @() all(ins_cost >= 0));
    [nPass, nFail] = check(nPass, nFail, 'del_cost is non-negative', ...
        @() all(del_cost >= 0));

    % --- Group 2: Group default lookups ---
    fprintf('\n[Group defaults]\n');
    % Random within-cho pair (not in override list): ㅋ (19) ↔ ㅌ (20) -> 0.5
    [nPass, nFail] = check(nPass, nFail, 'cho ↔ cho default = 0.5 (ㅋ↔ㅌ)', ...
        @() sub_cost(19, 20) == 0.5);
    % cho ↔ jng: ㄱ (4) ↔ ㅏ (23) -> 1.5
    [nPass, nFail] = check(nPass, nFail, 'cho ↔ jng default = 1.5 (ㄱ↔ㅏ)', ...
        @() sub_cost(4, 23) == 1.5);
    % cho ↔ jong: ㅋ (19) ↔ ㅋ-jong (67) -> 1.0
    %   (we use ㅋ here because the same-glyph version is the clearest sanity)
    [nPass, nFail] = check(nPass, nFail, 'cho ↔ jong default = 1.0 (ㅋ↔ㅋ-jong)', ...
        @() sub_cost(19, 67) == 1.0);
    % cho ↔ upper: ㅋ (19) ↔ A (71) -> 2.0
    [nPass, nFail] = check(nPass, nFail, 'cho ↔ upper default = 2.0 (ㅋ↔A)', ...
        @() sub_cost(19, 71) == 2.0);
    % upper ↔ lower: A (71) ↔ a (97) -> 0.5
    [nPass, nFail] = check(nPass, nFail, 'upper ↔ lower default = 0.5 (A↔a)', ...
        @() sub_cost(71, 97) == 0.5);
    % upper ↔ upper (not override): A (71) ↔ Z (96) -> 1.0
    [nPass, nFail] = check(nPass, nFail, 'upper ↔ upper default = 1.0 (A↔Z)', ...
        @() sub_cost(71, 96) == 1.0);
    % digit ↔ digit (not override): 2 (125) ↔ 7 (130) -> 1.0
    [nPass, nFail] = check(nPass, nFail, 'digit ↔ digit default = 1.0 (2↔7)', ...
        @() sub_cost(125, 130) == 1.0);
    % punct ↔ punct: . (134) ↔ , (135) -> 1.0
    [nPass, nFail] = check(nPass, nFail, 'punct ↔ punct default = 1.0 (.↔,)', ...
        @() sub_cost(134, 135) == 1.0);

    % --- Group 3: Override values (and symmetry) ---
    fprintf('\n[Visual confusion overrides]\n');
    % Choseong overrides
    [nPass, nFail] = check(nPass, nFail, 'cho ㅁ↔ㅇ override = 0.2', ...
        @() sub_cost(10, 15) == 0.2 && sub_cost(15, 10) == 0.2);
    [nPass, nFail] = check(nPass, nFail, 'cho ㄷ↔ㄹ override = 0.3', ...
        @() sub_cost(7, 9) == 0.3 && sub_cost(9, 7) == 0.3);
    [nPass, nFail] = check(nPass, nFail, 'cho ㅈ↔ㅊ override = 0.3', ...
        @() sub_cost(16, 18) == 0.3);
    % Jungseong overrides
    [nPass, nFail] = check(nPass, nFail, 'jng ㅏ↔ㅑ override = 0.3', ...
        @() sub_cost(23, 25) == 0.3);
    [nPass, nFail] = check(nPass, nFail, 'jng ㅗ↔ㅛ override = 0.3', ...
        @() sub_cost(31, 35) == 0.3);
    % Jongseong overrides
    [nPass, nFail] = check(nPass, nFail, 'jong ㅁ↔ㅇ override = 0.2', ...
        @() sub_cost(59, 64) == 0.2 && sub_cost(64, 59) == 0.2);
    % ASCII overrides
    [nPass, nFail] = check(nPass, nFail, 'O↔0 override = 0.2', ...
        @() sub_cost(85, 123) == 0.2 && sub_cost(123, 85) == 0.2);
    [nPass, nFail] = check(nPass, nFail, 'l↔1 override = 0.3', ...
        @() sub_cost(108, 124) == 0.3);
    [nPass, nFail] = check(nPass, nFail, 'I↔l override = 0.3', ...
        @() sub_cost(79, 108) == 0.3);
    [nPass, nFail] = check(nPass, nFail, 'I↔1 override = 0.3', ...
        @() sub_cost(79, 124) == 0.3);
    [nPass, nFail] = check(nPass, nFail, 'S↔5 override = 0.4', ...
        @() sub_cost(89, 128) == 0.4);
    [nPass, nFail] = check(nPass, nFail, 'B↔8 override = 0.4', ...
        @() sub_cost(72, 131) == 0.4);

    % --- Group 4: Symmetry ---
    fprintf('\n[Symmetry]\n');
    [nPass, nFail] = check(nPass, nFail, 'sub_cost is fully symmetric', ...
        @() isequal(sub_cost, sub_cost'));

    % --- Group 5: ins/del specifics ---
    fprintf('\n[ins/del]\n');
    [nPass, nFail] = check(nPass, nFail, 'all ins_cost = 1', ...
        @() all(ins_cost == 1));
    [nPass, nFail] = check(nPass, nFail, 'all del_cost = 1 except <no_final>', ...
        @() all(del_cost([1:2, 4:end]) == 1));
    [nPass, nFail] = check(nPass, nFail, 'del_cost(<no_final>) = 0.5', ...
        @() del_cost(3) == 0.5);

    % --- Group 6: Behavior under weighted_levenshtein ---
    fprintf('\n[Behavior with weighted_levenshtein]\n');

    % "가" (ㄱ ㅏ <no_final>) vs "나" (ㄴ ㅏ <no_final>):
    %   one cho substitution ㄱ↔ㄴ. Both in cho group, no override -> 0.5.
    d1 = led.weighted_levenshtein( ...
        led.decompose("가"), led.decompose("나"), sub_cost, ins_cost, del_cost);
    [nPass, nFail] = check(nPass, nFail, '"가" vs "나" under prior = 0.5', ...
        @() abs(d1 - 0.5) < 1e-12);

    % "마" (ㅁ ㅏ <no_final>) vs "아" (ㅇ ㅏ <no_final>):
    %   ㅁ↔ㅇ override -> 0.2.
    d2 = led.weighted_levenshtein( ...
        led.decompose("마"), led.decompose("아"), sub_cost, ins_cost, del_cost);
    [nPass, nFail] = check(nPass, nFail, '"마" vs "아" under prior = 0.2 (override)', ...
        @() abs(d2 - 0.2) < 1e-12);

    % "각" (ㄱ ㅏ ㄱ) vs "가" (ㄱ ㅏ <no_final>):
    %   one substitution at jongseong slot: ㄱ-jong (44) ↔ <no_final> (3).
    %   grp(44)=4 (jong), grp(3)=1 (special) -> default = 1.0.
    %   Hmm, but conceptually "deleting the batchim" feels like del. Let's
    %   verify the actual computed value.
    %
    %   Alternative path: del a(3)=ㄱ-jong + ins b(3)=<no_final>
    %     = del_cost(44) + ins_cost(3) = 1.0 + 1.0 = 2.0
    %   Sub path: sub_cost(44, 3) = 1.0.
    %   So the DP picks sub at cost 1.0. Confirm:
    d3 = led.weighted_levenshtein( ...
        led.decompose("각"), led.decompose("가"), sub_cost, ins_cost, del_cost);
    [nPass, nFail] = check(nPass, nFail, '"각" vs "가" under prior = 1.0', ...
        @() abs(d3 - 1.0) < 1e-12);

    % "O" (ASCII 85) vs "0" (digit 123):
    %   single substitution with override -> 0.2
    d4 = led.weighted_levenshtein( ...
        led.decompose("O"), led.decompose("0"), sub_cost, ins_cost, del_cost);
    [nPass, nFail] = check(nPass, nFail, '"O" vs "0" under prior = 0.2 (override)', ...
        @() abs(d4 - 0.2) < 1e-12);

    % --- Summary ---
    fprintf('\n=== Result: %d passed, %d failed ===\n', nPass, nFail);
    if nFail > 0
        warning('test_human_prior_costs:Failures', '%d test(s) failed.', nFail);
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