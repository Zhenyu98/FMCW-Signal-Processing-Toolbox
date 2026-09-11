%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_tracking_assignment_solver.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Validate global GNN assignment solver
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% deterministic counterexample where greedy is not globally optimal
costMatrix = [1.0, 2.0;
              1.1, 100.0];

associationParams.Solver = 'global';
associationParams.MaxExactAssignmentSize = 8;
[assignGlobal, ~, ~, infoGlobal] = SolveGlobalAssignment(costMatrix, associationParams);

associationParams.Solver = 'greedy';
[assignGreedy, ~, ~, infoGreedy] = SolveGlobalAssignment(costMatrix, associationParams);
counterexampleGlobalCost = infoGlobal.TotalCost;
counterexampleGreedyCost = infoGreedy.TotalCost;

associationParams.Solver = 'hungarian';
[assignHungarian, ~, ~, infoHungarian] = SolveGlobalAssignment(costMatrix, associationParams);
counterexampleHungarianCost = infoHungarian.TotalCost;

expectedAssign = [1, 2; 2, 1];
if ~isequal(sortrows(assignGlobal, 1), expectedAssign)
    error('Global assignment failed on the deterministic counterexample.')
end
if ~isequal(sortrows(assignHungarian, 1), expectedAssign)
    error('Hungarian assignment failed on the deterministic counterexample.')
end
if infoGlobal.TotalCost >= infoGreedy.TotalCost
    error('Global assignment should be better than greedy on this counterexample.')
end

%% random small matrices compared with independent brute-force reference
rng(2026)
testtimes = 50;
for testIdex = 1:testtimes
    TrackNum = randi([2, 5]);
    DetectionNum = randi([2, 5]);
    costMatrix = 10 * rand(TrackNum, DetectionNum);

    invalidMask = rand(TrackNum, DetectionNum) < 0.20;
    costMatrix(invalidMask) = Inf;
    if all(~isfinite(costMatrix(:)))
        costMatrix(1,1) = 1;
    end

    associationParams.Solver = 'global';
    [assignGlobal, ~, ~, infoGlobal] = SolveGlobalAssignment(costMatrix, associationParams);
    associationParams.Solver = 'hungarian';
    [assignHungarian, ~, ~, infoHungarian] = SolveGlobalAssignment(costMatrix, associationParams);
    assignRef = bruteForceMaxCardinality(costMatrix);
    refCost = localAssignmentCost(costMatrix, assignRef);

    if size(assignGlobal, 1) ~= size(assignRef, 1)
        error('Global assignment cardinality mismatch.')
    end
    if abs(infoGlobal.TotalCost - refCost) > 1e-10
        error('Global assignment cost mismatch.')
    end
    if size(assignHungarian, 1) ~= size(assignRef, 1)
        error('Hungarian assignment cardinality mismatch.')
    end
    if abs(infoHungarian.TotalCost - refCost) > 1e-10
        error('Hungarian assignment cost mismatch.')
    end
end

%% Hungarian should support explicit non-assignment cost
costMatrix = [1, 100;
              100, 100];
associationParams.Solver = 'hungarian';
associationParams.CostOfNonAssignment = 10;
[assignHungarian, unassignedTracks, unassignedDetections, infoHungarian] = ...
    SolveGlobalAssignment(costMatrix, associationParams);

if ~isequal(assignHungarian, [1, 1])
    error('Hungarian non-assignment cost check failed.')
end
if ~isequal(unassignedTracks, 2) || ~isequal(unassignedDetections, 2)
    error('Hungarian unassigned output check failed.')
end

disp('===== validate_tracking_assignment_solver passed =====')
disp(['counterexample global cost = ', num2str(counterexampleGlobalCost)])
disp(['counterexample greedy cost = ', num2str(counterexampleGreedyCost)])
disp(['counterexample hungarian cost = ', num2str(counterexampleHungarianCost)])
disp(['random testtimes = ', num2str(testtimes)])

% -------------------------- Subfunctions -------------------------------
function bestAssign = bruteForceMaxCardinality(costMatrix)

TrackNum = size(costMatrix, 1);
DetectionNum = size(costMatrix, 2);
bestAssign = zeros(0, 2);
bestNum = -1;
bestCost = Inf;
currentAssign = zeros(0, 2);
usedDetection = false(1, DetectionNum);

searchTrack(1, 0, 0)

    function searchTrack(trackIdex, currentNum, currentCost)
        if trackIdex > TrackNum
            if currentNum > bestNum || ...
                    (currentNum == bestNum && currentCost < bestCost)
                bestNum = currentNum;
                bestCost = currentCost;
                bestAssign = currentAssign;
            end
            return
        end

        searchTrack(trackIdex + 1, currentNum, currentCost)
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
    end
end

function totalCost = localAssignmentCost(costMatrix, assignments)

totalCost = 0;
for ii = 1:size(assignments, 1)
    totalCost = totalCost + costMatrix(assignments(ii,1), assignments(ii,2));
end
end
