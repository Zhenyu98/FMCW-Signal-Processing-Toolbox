function [assignments, unassignedTracks, unassignedDetections, solverInfo] = ...
    SolveGlobalAssignment(costMatrix, associationParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : SolveGlobalAssignment.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Solve gated track-detection assignment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 2
    associationParams = struct();
end

TrackNum = size(costMatrix, 1);
DetectionNum = size(costMatrix, 2);
assignments = zeros(0, 2);
unassignedTracks = (1:TrackNum).';
unassignedDetections = (1:DetectionNum).';

solverName = getStructText(associationParams, 'Solver', 'hungarian');
maxExactSize = round(getStructNumber(associationParams, 'MaxExactAssignmentSize', 8));

solverInfo.Solver = solverName;
solverInfo.UsedFallback = false;
solverInfo.TotalCost = 0;
solverInfo.AssignmentNum = 0;
solverInfo.CostOfNonAssignment = [];

if TrackNum == 0 || DetectionNum == 0
    return
end

switch lower(solverName)
    case {'greedy', 'nearest'}
        assignments = greedyAssign(costMatrix);
    case {'hungarian', 'munkres'}
        [assignments, solverInfo] = hungarianAssign(costMatrix, associationParams, solverInfo);
    case {'global', 'exact', 'gnn'}
        if max(TrackNum, DetectionNum) <= maxExactSize
            assignments = exactAssign(costMatrix);
        else
            % 目标数量太大时 exact search 会指数增长，退回 Hungarian。
            [assignments, solverInfo] = hungarianAssign(costMatrix, associationParams, solverInfo);
            solverInfo.UsedFallback = true;
            solverInfo.Solver = 'hungarian-fallback';
        end
    otherwise
        error('Unknown trackingParams.Association.Solver: %s', solverName)
end

if ~isempty(assignments)
    assignments = sortrows(assignments, 1);
    unassignedTracks = setdiff((1:TrackNum).', assignments(:,1));
    unassignedDetections = setdiff((1:DetectionNum).', assignments(:,2));
    solverInfo.TotalCost = assignmentCost(costMatrix, assignments);
    solverInfo.AssignmentNum = size(assignments, 1);
end

end

function [assignments, solverInfo] = hungarianAssign(costMatrix, associationParams, solverInfo)
TrackNum = size(costMatrix, 1);
DetectionNum = size(costMatrix, 2);
assignments = zeros(0, 2);

finiteCost = costMatrix(isfinite(costMatrix));
if isempty(finiteCost)
    return
end

costOfNonAssignment = getCostOfNonAssignment(associationParams, finiteCost);
solverInfo.CostOfNonAssignment = costOfNonAssignment;

[augCost, invalidCost] = buildAugmentedCost(costMatrix, costOfNonAssignment);
colForRow = hungarianSquare(augCost);

for trackIdex = 1:TrackNum
    detectionIdex = colForRow(trackIdex);
    if detectionIdex >= 1 && detectionIdex <= DetectionNum && ...
            isfinite(costMatrix(trackIdex, detectionIdex)) && ...
            augCost(trackIdex, detectionIdex) < invalidCost
        assignments = [assignments; trackIdex, detectionIdex]; %#ok<AGROW>
    end
end
end

function costOfNonAssignment = getCostOfNonAssignment(associationParams, finiteCost)
costOfNonAssignment = getStructNumber(associationParams, 'CostOfNonAssignment', NaN);
if ~isnan(costOfNonAssignment) && ~isempty(costOfNonAssignment)
    costOfNonAssignment = double(costOfNonAssignment);
    return
end

costMin = min(finiteCost);
costMax = max(finiteCost);
costScale = max([abs(costMin), abs(costMax), costMax - costMin, 1]);
% 默认让所有 gate 内有限匹配优先于不匹配，保持原 exact solver 的最大匹配数语义。
costOfNonAssignment = costMax + costScale + 1;
end

function [augCost, invalidCost] = buildAugmentedCost(costMatrix, costOfNonAssignment)
TrackNum = size(costMatrix, 1);
DetectionNum = size(costMatrix, 2);
AugNum = TrackNum + DetectionNum;

finiteCost = costMatrix(isfinite(costMatrix));
baseMax = max([finiteCost(:); costOfNonAssignment; 0]);
baseMin = min([finiteCost(:); costOfNonAssignment; 0]);
invalidCost = baseMax + (abs(baseMax - baseMin) + 1) * (AugNum + 1);

augCost = invalidCost * ones(AugNum, AugNum);

validCost = costMatrix;
validCost(~isfinite(validCost)) = invalidCost;
augCost(1:TrackNum, 1:DetectionNum) = validCost;

for trackIdex = 1:TrackNum
    augCost(trackIdex, DetectionNum + trackIdex) = costOfNonAssignment;
end

for detectionIdex = 1:DetectionNum
    augCost(TrackNum + detectionIdex, detectionIdex) = costOfNonAssignment;
end

% Dummy rows and dummy columns absorb unused tracks/detections.
augCost(TrackNum+1:end, DetectionNum+1:end) = 0;
end

function colForRow = hungarianSquare(costMatrix)
N = size(costMatrix, 1);
u = zeros(N + 1, 1);
v = zeros(N + 1, 1);
p = zeros(N + 1, 1);
way = zeros(N + 1, 1);

for rowIdex = 1:N
    p(1) = rowIdex;
    col0 = 1;
    minv = Inf(N + 1, 1);
    used = false(N + 1, 1);

    while true
        used(col0) = true;
        row0 = p(col0);
        delta = Inf;
        col1 = 1;

        for colIdex = 2:N+1
            if used(colIdex)
                continue
            end
            curCost = costMatrix(row0, colIdex - 1) - u(row0) - v(colIdex);
            if curCost < minv(colIdex)
                minv(colIdex) = curCost;
                way(colIdex) = col0;
            end
            if minv(colIdex) < delta
                delta = minv(colIdex);
                col1 = colIdex;
            end
        end

        for colIdex = 1:N+1
            if used(colIdex)
                u(p(colIdex)) = u(p(colIdex)) + delta;
                v(colIdex) = v(colIdex) - delta;
            else
                minv(colIdex) = minv(colIdex) - delta;
            end
        end

        col0 = col1;
        if p(col0) == 0
            break
        end
    end

    while true
        col1 = way(col0);
        p(col0) = p(col1);
        col0 = col1;
        if col0 == 1
            break
        end
    end
end

colForRow = zeros(N, 1);
for colIdex = 2:N+1
    if p(colIdex) > 0
        colForRow(p(colIdex)) = colIdex - 1;
    end
end
end

function assignments = exactAssign(costMatrix)
TrackNum = size(costMatrix, 1);
DetectionNum = size(costMatrix, 2);

bestAssign = zeros(0, 2);
bestNum = -1;
bestCost = Inf;
currentAssign = zeros(0, 2);
usedDetection = false(1, DetectionNum);

searchTrack(1, 0, 0)
assignments = bestAssign;

    function searchTrack(trackIdex, currentNum, currentCost)
        if trackIdex > TrackNum
            updateBest()
            return
        end

        remainingTrack = TrackNum - trackIdex + 1;
        remainingDetection = DetectionNum - sum(usedDetection);
        upperNum = currentNum + min(remainingTrack, remainingDetection);
        if upperNum < bestNum
            return
        end
        if upperNum == bestNum && currentCost >= bestCost
            return
        end

        % Option 1: this track is not assigned.
        searchTrack(trackIdex + 1, currentNum, currentCost)

        % Option 2: assign this track to one unused detection inside gate.
        for detectionIdex = 1:DetectionNum
            if usedDetection(detectionIdex) || ~isfinite(costMatrix(trackIdex, detectionIdex))
                continue
            end

            usedDetection(detectionIdex) = true;
            currentAssign = [currentAssign; trackIdex, detectionIdex]; %#ok<AGROW>
            searchTrack(trackIdex + 1, currentNum + 1, ...
                currentCost + costMatrix(trackIdex, detectionIdex))
            currentAssign(end,:) = [];
            usedDetection(detectionIdex) = false;
        end

        function updateBest()
            if currentNum > bestNum || ...
                    (currentNum == bestNum && currentCost < bestCost)
                bestNum = currentNum;
                bestCost = currentCost;
                bestAssign = currentAssign;
            end
        end
    end
end

function assignments = greedyAssign(costMatrix)
assignments = zeros(0, 2);
workCost = costMatrix;
while true
    [costMin, linearIdex] = min(workCost(:));
    if ~isfinite(costMin)
        break
    end
    [trackIdex, detectionIdex] = ind2sub(size(workCost), linearIdex);
    assignments = [assignments; trackIdex, detectionIdex]; %#ok<AGROW>
    workCost(trackIdex, :) = Inf;
    workCost(:, detectionIdex) = Inf;
end
end

function totalCost = assignmentCost(costMatrix, assignments)
totalCost = 0;
for ii = 1:size(assignments, 1)
    totalCost = totalCost + costMatrix(assignments(ii,1), assignments(ii,2));
end
end

function value = getStructText(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = char(string(s.(fieldName)));
else
    value = defaultValue;
end
end

function value = getStructNumber(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = double(s.(fieldName));
else
    value = defaultValue;
end
end
