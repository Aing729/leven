function test_decompose()
%TEST_DECOMPOSE  Run jamo.md v1.0 test cases against led.decompose.
%
%   Run from project root:
%       cd /MATLAB Drive/leven
%       test_decompose
%
%   Recompose tests are skipped here -- they need led.recompose, which is
%   the next step.

    fprintf('\n=== test_decompose ===\n\n');

    nPass = 0;
    nFail = 0;

    % --- Group 1: Pure Hangul. Check decomposed length and a few key indices. ---
    fprintf('[Pure Hangul]\n');
    [nPass, nFail] = check(nPass, nFail, '"가" -> length 3', ...
        @() numel(led.decompose("가")) == 3);
    [nPass, nFail] = check(nPass, nFail, '"각" -> length 3', ...
        @() numel(led.decompose("각")) == 3);
    [nPass, nFail] = check(nPass, nFail, '"한국어" -> length 9', ...
        @() numel(led.decompose("한국어")) == 9);
    [nPass, nFail] = check(nPass, nFail, '"읽다" -> length 6', ...
        @() numel(led.decompose("읽다")) == 6);
    [nPass, nFail] = check(nPass, nFail, '"꽃" -> length 3', ...
        @() numel(led.decompose("꽃")) == 3);

    % "가" = U+AC00. cho=ㄱ (idx 4), jng=ㅏ (idx 23), no_final (idx 3).
    [nPass, nFail] = check(nPass, nFail, '"가" -> [4; 23; 3]', ...
        @() isequal(led.decompose("가"), int32([4; 23; 3])));

    % "각" = U+AC01. cho=ㄱ (4), jng=ㅏ (23), jong=ㄱ (44).
    [nPass, nFail] = check(nPass, nFail, '"각" -> [4; 23; 44]', ...
        @() isequal(led.decompose("각"), int32([4; 23; 44])));

    % --- Group 2: Mixed content. ---
    % "Hello, 한국!" = H+e+l+l+o + , + space + (한:3) + (국:3) + ! = 5+1+1+3+3+1 = 14
    % "2024년 12월"   = 2+0+2+4 + (년:3) + space + 1+2 + (월:3)         = 4+3+1+2+3 = 13
    fprintf('\n[Mixed]\n');
    [nPass, nFail] = check(nPass, nFail, '"Hello, 한국!" -> length 14', ...
        @() numel(led.decompose("Hello, 한국!")) == 14);
    [nPass, nFail] = check(nPass, nFail, '"2024년 12월" -> length 13', ...
        @() numel(led.decompose("2024년 12월")) == 13);

    % --- Group 3: OOV behavior. ---
    fprintf('\n[OOV: strict mode raises]\n');
    [nPass, nFail] = check(nPass, nFail, 'strict "漢字" raises UnknownChar', ...
        @() raisesError(@() led.decompose("漢字"), "led:decompose:UnknownChar"));
    [nPass, nFail] = check(nPass, nFail, 'strict "café" raises', ...
        @() raisesError(@() led.decompose("café"), "led:decompose:UnknownChar"));
    [nPass, nFail] = check(nPass, nFail, 'strict tab raises', ...
        @() raisesError(@() led.decompose(sprintf("a\tb")), "led:decompose:UnknownChar"));

    fprintf('\n[OOV: lenient mode substitutes <unk>=2]\n');
    [nPass, nFail] = check(nPass, nFail, 'lenient "漢字" -> [2; 2]', ...
        @() isequal(led.decompose("漢字", Mode="lenient"), int32([2; 2])));
    % "café" -> c (lower idx 99) a(97) f(102) <unk>(2)
    %   c is the 3rd lowercase letter -> 97 + 2 = 99
    %   a is the 1st                  -> 97 + 0 = 97
    %   f is the 6th                  -> 97 + 5 = 102
    [nPass, nFail] = check(nPass, nFail, 'lenient "café" -> [99; 97; 102; 2]', ...
        @() isequal(led.decompose("café", Mode="lenient"), int32([99; 97; 102; 2])));

    % --- Group 4: Edge cases. ---
    fprintf('\n[Edge cases]\n');
    [nPass, nFail] = check(nPass, nFail, 'empty string -> empty int32 column', ...
        @() isequal(size(led.decompose("")), [0 1]) && ...
            isa(led.decompose(""), 'int32'));
    [nPass, nFail] = check(nPass, nFail, 'single space -> [133]', ...
        @() isequal(led.decompose(" "), int32(133)));
    [nPass, nFail] = check(nPass, nFail, 'output is column vector', ...
        @() iscolumn(led.decompose("한국어")));
    [nPass, nFail] = check(nPass, nFail, 'output is int32', ...
        @() isa(led.decompose("가"), 'int32'));

    % Standalone compatibility jamo "ㄱㅏ" (U+3131 U+314F).
    % ㄱ as compat -> mapped to choseong ㄱ (idx 4)
    % ㅏ as compat -> mapped to jungseong ㅏ (idx 23)
    [nPass, nFail] = check(nPass, nFail, '"ㄱㅏ" (compat jamo) -> length 2, [4; 23]', ...
        @() isequal(led.decompose("ㄱㅏ"), int32([4; 23])));

    % --- Summary ---
    fprintf('\n=== Result: %d passed, %d failed ===\n', nPass, nFail);
    if nFail > 0
        warning('test_decompose:Failures', ...
            '%d test(s) failed. Inspect output above.', nFail);
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

function tf = raisesError(thunk, expectedId)
    tf = false;
    try
        thunk();
    catch ME
        tf = strcmp(ME.identifier, expectedId);
    end
end