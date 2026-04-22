function d = weighted_levenshtein(a, b, sub_cost, ins_cost, del_cost)
%WEIGHTED_LEVENSHTEIN  Edit distance with custom symbol-pair costs.
%
%   d = led.weighted_levenshtein(a, b, sub_cost, ins_cost, del_cost)
%
%   Inputs:
%       a, b      : int32 column vectors of V indices.
%       sub_cost  : |V| x |V| double matrix. sub_cost(i, j) is the cost of
%                   substituting symbol j for symbol i. By convention
%                   sub_cost(i, i) should be 0 (identity is free).
%       ins_cost  : |V| x 1 double vector. ins_cost(j) is the cost of
%                   inserting symbol j.
%       del_cost  : |V| x 1 double vector. del_cost(i) is the cost of
%                   deleting symbol i.
%
%   Output:
%       d         : scalar double. Total edit distance.
%
%   Algorithm:
%       Standard O(mn) Levenshtein DP. Implemented as a straightforward
%       double loop. For typical Korean OCR strings (length <= a few
%       hundred), this runs in well under a millisecond per pair.
%       Anti-diagonal vectorization is deferred until profiling shows it
%       matters in the training inner loop (see references/levenshtein.md
%       when written).
%
%   Edge cases:
%       length(a) == 0 -> d = sum of ins_cost over b
%       length(b) == 0 -> d = sum of del_cost over a
%       both empty     -> d = 0
%
%   Cost negativity is NOT checked here per call (would dominate runtime).
%   Negative costs would break the shortest-path assumption of the DP and
%   yield garbage. Validate cost matrices once at load time
%   (led.load_costs is responsible).
%
%   See also led.align (returns the alignment path in addition to d).

    arguments
        a (:,1) int32
        b (:,1) int32
        sub_cost (:,:) double
        ins_cost (:,1) double
        del_cost (:,1) double
    end

    m = numel(a);
    n = numel(b);

    % --- Empty-input shortcuts ---
    if m == 0 && n == 0
        d = 0;
        return
    end
    if m == 0
        d = sum(ins_cost(b));
        return
    end
    if n == 0
        d = sum(del_cost(a));
        return
    end

    % --- DP table: D(i, j) = edit distance between a(1:i-1) and b(1:j-1) ---
    % We use 1-based indexing where D(1, 1) corresponds to (empty, empty).
    D = zeros(m + 1, n + 1);

    % First column: deleting a(1..i)
    for i = 1:m
        D(i + 1, 1) = D(i, 1) + del_cost(a(i));
    end

    % First row: inserting b(1..j)
    for j = 1:n
        D(1, j + 1) = D(1, j) + ins_cost(b(j));
    end

    % Body
    for i = 1:m
        ai = a(i);
        for j = 1:n
            bj = b(j);
            costSub = D(i,     j)     + sub_cost(ai, bj);
            costDel = D(i,     j + 1) + del_cost(ai);
            costIns = D(i + 1, j)     + ins_cost(bj);
            D(i + 1, j + 1) = min([costSub, costDel, costIns]);
        end
    end

    d = D(m + 1, n + 1);
end