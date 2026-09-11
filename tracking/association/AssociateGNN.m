function [assignments, unassignedTracks, unassignedDetections, associationInfo] = ...
    AssociateGNN(tracks, centroidList, ekfParams, associationParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : AssociateGNN.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : GNN-style gated detection-to-track association
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 4
    associationParams = struct();
end

TrackNum = length(tracks);
DetectionNum = length(centroidList);
assignments = zeros(0, 2);
unassignedTracks = (1:TrackNum).';
unassignedDetections = (1:DetectionNum).';

associationInfo.costMatrix = Inf(TrackNum, DetectionNum);
associationInfo.gateDistance = Inf(TrackNum, DetectionNum);
associationInfo.zPred = cell(TrackNum, 1);
associationInfo.zDetection = cell(DetectionNum, 1);
associationInfo.solverInfo = struct();

if TrackNum == 0 || DetectionNum == 0
    return
end

gateProbability = getStructNumber(associationParams, 'GateProbability', 0.99);
gateDim = round(getStructNumber(associationParams, 'GateDim', 4));
gateThreshold = getStructNumber(associationParams, 'GateThreshold', ...
    ChiSquareGate(gateProbability, gateDim));
useGNN = getStructLogical(associationParams, 'UseGNN', true);

for trackIdex = 1:TrackNum
    xPred = tracks(trackIdex).x_pred;
    PPred = tracks(trackIdex).P_pred;
    [zPred, H] = Cart6ToSphere4AndJacobian(xPred);
    associationInfo.zPred{trackIdex} = zPred;

    for detectionIdex = 1:DetectionNum
        [z, R] = BuildMeasurementNoise(centroidList(detectionIdex), ekfParams);
        innovation = z - zPred;
        innovation(2) = WrapAngle(innovation(2));
        innovation(3) = WrapAngle(innovation(3));

        S = H * PPred * H' + R;
        S = (S + S') / 2;
        d2 = innovation' / S * innovation;
        associationInfo.gateDistance(trackIdex, detectionIdex) = d2;
        associationInfo.zDetection{detectionIdex} = z;

        if ~useGNN || d2 <= gateThreshold
            associationInfo.costMatrix(trackIdex, detectionIdex) = ...
                d2 + log(max(det(S), eps));
        end
    end
end

[assignments, unassignedTracks, unassignedDetections, solverInfo] = ...
    SolveGlobalAssignment(associationInfo.costMatrix, associationParams);
associationInfo.solverInfo = solverInfo;

end

function value = getStructNumber(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = double(s.(fieldName));
else
    value = defaultValue;
end
end

function value = getStructLogical(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = logical(s.(fieldName));
else
    value = defaultValue;
end
end
