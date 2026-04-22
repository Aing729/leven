function test_recompose()
%TEST_RECOMPOSE  Test led.recompose and round-trip with led.decompose.
%
%   Run from project root:
%       cd /MATLAB Drive/leven
%       test_recompose

    fprintf('\n=== test_recompose ===\n\n');

    nPass = 0;
    nFail = 0;

    % --- Group 1: Direct recompose tests ---
    fprintf('[Direct recompose]\n');
    [nPass, nFail] = check(nPass, nFail, '[4; 23; 3] -> "가"', ...
        @() led.recompose(int32([4; 23; 3])) == "가");
    [nPass, nFail] = check(nPass, nFail, '[4; 23; 44] -> "각"', ...
        @() led.recompose(int32([4; 23; 44])) == "각");
    [nPass, nFail] = check(nPass, nFail, 'empty input -> ""', ...
        @() led.recompose(zeros(0, 1, 'int32')) == "");
    [nPass, nFail] = check(nPass, nFail, '[133] -> " "', ...
        @() led.recompose(int32(133)) == " ");

    % Standalone choseong ㄱ (idx 4, no following jng) -> compat ㄱ (U+3131)
    [nPass, nFail] = check(nPass, nFail, '[4] (lone choseong) -> "ㄱ" (U+3131)', ...
        @() led.recompose(int32(4)) == string(char(hex2dec('3131'))));

    % --- Group 2: Round-trip (decompose -> recompose -> identity) ---
    fprintf('\n[Round-trip: decompose then recompose]\n');
    roundTripCases = [ ...
        "가", "각", "한국어", "읽다", "꽃", ...
        "Hello, 한국!", "2024년 12월", ...
        "", " ", "ABC xyz 123", "."];
    for i = 1:numel(roundTripCases)
        s = roundTripCases(i);
        label = sprintf('round-trip "%s"', s);
        [nPass, nFail] = check(nPass, nFail, label, ...
            @() led.recompose(led.decompose(s)) == s);
    end

    % Compat jamo round-trip: "ㄱㅏ" -> [4; 23] -> "ㄱㅏ" (NOT "가")
    % Note: standalone jamo render via compat block, so "ㄱㅏ" comes back
    % as the same compat sequence.
    [nPass, nFail] = check(nPass, nFail, 'round-trip "ㄱㅏ" stays as compat jamo (not "가")', ...
        @() led.recompose(led.decompose("ㄱㅏ")) == "ㄱㅏ");

    % --- Group 3: Error cases ---
    fprintf('\n[Errors]\n');
    [nPass, nFail] = check(nPass, nFail, '<eps> raises NonRenderableSymbol', ...
        @() raisesError(@() led.recompose(int32(1)), "led:recompose:NonRenderableSymbol"));
    [nPass, nFail] = check(nPass, nFail, '<unk> raises NonRenderableSymbol', ...
        @() raisesError(@() led.recompose(int32(2)), "led:recompose:NonRenderableSymbol"));
    [nPass, nFail] = check(nPass, nFail, 'idx 0 raises InvalidIndex', ...
        @() raisesError(@() led.recompose(int32(0)), "led:recompose:InvalidIndex"));
    [nPass, nFail] = check(nPass, nFail, 'idx 146 raises InvalidIndex', ...
        @() raisesError(@() led.recompose(int32(146)), "led:recompose:InvalidIndex"));
    [nPass, nFail] = check(nPass, nFail, 'idx -1 raises InvalidIndex', ...
        @() raisesError(@() led.recompose(int32(-1)), "led:recompose:InvalidIndex"));

    % Lone <no_final> (not part of a triple) is also non-renderable.
    [nPass, nFail] = check(nPass, nFail, 'lone <no_final> raises NonRenderableSymbol', ...
        @() raisesError(@() led.recompose(int32(3)), "led:recompose:NonRenderableSymbol"));

    % --- Group 4: Mixed sequences with jamo + non-jamo ---
    fprintf('\n[Mixed sequences]\n');
    % "각A" -> [4; 23; 44; 71] -> back to "각A"
    [nPass, nFail] = check(nPass, nFail, 'round-trip "각A"', ...
        @() led.recompose(led.decompose("각A")) == "각A");
    % "A각" -> [71; 4; 23; 44] -> "A각"
    [nPass, nFail] = check(nPass, nFail, 'round-trip "A각"', ...
        @() led.recompose(led.decompose("A각")) == "A각");

    % --- Summary ---
    fprintf('\n=== Result: %d passed, %d failed ===\n', nPass, nFail);
    if nFail > 0
        warning('test_recompose:Failures', '%d test(s) failed.', nFail);
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