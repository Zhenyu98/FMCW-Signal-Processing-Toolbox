function [trackResult, measurementSeq] = TrackPointCloudSequence(frameDataSeq, trackingParams, ekfParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : TrackPointCloudSequence.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Track point-cloud sequence with centroid + GNN + EKF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 2 || isempty(trackingParams)
    trackingParams = ConfigureTrackingParameter();
end
if nargin < 3 || isempty(ekfParams)
    [~, ekfParams] = ConfigureTrackingParameter();
end

FrameNum = length(frameDataSeq);
trackParams = getSubStruct(trackingParams, 'Track');
coordinateParams = getSubStruct(trackingParams, 'Coordinate');
associationParams = getSubStruct(trackingParams, 'Association');

tracks = emptyTrackStruct();
finishedTracks = emptyTrackStruct();
nextId = 1;

measurementSeq.frame_data = cell(FrameNum, 1);
measurementSeq.centroidList = cell(FrameNum, 1);
measurementSeq.centroidInfo = cell(FrameNum, 1);
measurementSeq.CandidateNum = zeros(FrameNum, 1);
measurementSeq.centroidXY = NaN(FrameNum, 2);
measurementSeq.isDetected = false(FrameNum, 1);
measurementSeq.rawXYAll = [];

frameTracks = cell(FrameNum, 1);
associationInfoSeq = cell(FrameNum, 1);
assignmentSeq = cell(FrameNum, 1);

for tIdex = 1:FrameNum
    frame_data = frameDataSeq{tIdex};
    frame_data = TransformPointCloudFrame(frame_data, coordinateParams);
    [centroidList, centroidInfo] = GenerateCentroidMeasurement(frame_data, trackingParams);

    measurementSeq.frame_data{tIdex} = frame_data;
    measurementSeq.centroidList{tIdex} = centroidList;
    measurementSeq.centroidInfo{tIdex} = centroidInfo;
    measurementSeq.CandidateNum(tIdex) = length(centroidList);
    if ~isempty(centroidList)
        measurementSeq.centroidXY(tIdex,:) = centroidList(1).centroid(1:2);
        measurementSeq.isDetected(tIdex) = true;
    end
    if ~isempty(frame_data)
        measurementSeq.rawXYAll = [measurementSeq.rawXYAll; frame_data(:,1:2)]; %#ok<AGROW>
    end

    for trackIdex = 1:length(tracks)
        [tracks(trackIdex).x_pred, tracks(trackIdex).P_pred] = ...
            EKFPredict(tracks(trackIdex).x_cart, tracks(trackIdex).P_cart, ekfParams);
    end

    [assignments, unassignedTracks, unassignedDetections, associationInfo] = ...
        AssociateGNN(tracks, centroidList, ekfParams, associationParams);

    assignmentSeq{tIdex} = assignments;
    associationInfoSeq{tIdex} = associationInfo;

    assignedTrackMask = false(1, length(tracks));
    for assignIdex = 1:size(assignments, 1)
        trackIdex = assignments(assignIdex, 1);
        detectionIdex = assignments(assignIdex, 2);
        [z, R] = BuildMeasurementNoise(centroidList(detectionIdex), ekfParams);
        [xUpdate, PUpdate, updateInfo] = EKFUpdateSphere4( ...
            tracks(trackIdex).x_pred, tracks(trackIdex).P_pred, z, R);

        tracks(trackIdex).x_cart = xUpdate;
        tracks(trackIdex).P_cart = PUpdate;
        tracks(trackIdex).age = tracks(trackIdex).age + 1;
        tracks(trackIdex).totalVisibleCount = tracks(trackIdex).totalVisibleCount + 1;
        tracks(trackIdex).consecutiveInvisibleCount = 0;
        tracks(trackIdex).lastFrame = tIdex;
        tracks(trackIdex).lastAssociatedPointNum = centroidList(detectionIdex).numPoints;
        tracks(trackIdex) = appendTrackHistory(tracks(trackIdex), tIdex, ...
            xUpdate, true, detectionIdex, updateInfo.NIS, ...
            associationInfo.gateDistance(trackIdex, detectionIdex), ...
            centroidList(detectionIdex).points);
        assignedTrackMask(trackIdex) = true;
    end

    for kk = 1:length(unassignedTracks)
        trackIdex = unassignedTracks(kk);
        if trackIdex > length(tracks) || assignedTrackMask(trackIdex)
            continue
        end
        tracks(trackIdex).x_cart = tracks(trackIdex).x_pred;
        tracks(trackIdex).P_cart = tracks(trackIdex).P_pred;
        tracks(trackIdex).age = tracks(trackIdex).age + 1;
        tracks(trackIdex).consecutiveInvisibleCount = ...
            tracks(trackIdex).consecutiveInvisibleCount + 1;
        tracks(trackIdex).lastFrame = tIdex;
        tracks(trackIdex).lastAssociatedPointNum = 0;
        tracks(trackIdex) = appendTrackHistory(tracks(trackIdex), tIdex, ...
            tracks(trackIdex).x_cart, false, NaN, NaN, NaN, []);
    end

    if getStructLogical(trackParams, 'CreateNewTracks', true)
        [tracks, nextId] = createTracksFromDetections(tracks, centroidList, ...
            unassignedDetections, ekfParams, trackParams, nextId, tIdex);
    end

    [tracks, finishedTracks] = UpdateTrackLifecycle(tracks, finishedTracks, trackParams);
    frameTracks{tIdex} = tracks;
end

trackResult.tracks = tracks;
trackResult.finishedTracks = finishedTracks;
trackResult.frameTracks = frameTracks;
trackResult.assignmentSeq = assignmentSeq;
trackResult.associationInfo = associationInfoSeq;
trackResult.time_axis = (0:FrameNum-1).' * getStructNumber(ekfParams, 'TF', 1);

end

function [tracks, nextId] = createTracksFromDetections(tracks, centroidList, ...
    unassignedDetections, ekfParams, trackParams, nextId, tIdex)

if isempty(unassignedDetections) || isempty(centroidList)
    return
end

maxTrackNum = round(getStructNumber(trackParams, 'MaxTrackNum', 20));
maxNew = round(getStructNumber(trackParams, 'MaxNewTracksPerFrame', 3));
remainTrackNum = max(maxTrackNum - length(tracks), 0);
maxNew = min(maxNew, remainTrackNum);
if maxNew <= 0
    return
end

objPower = [centroidList(unassignedDetections).obj_power];
[~, order] = sort(objPower, 'descend');
chooseDetection = unassignedDetections(order(1:min(maxNew, length(order))));

for kk = 1:length(chooseDetection)
    detectionIdex = chooseDetection(kk);
    [z, ~] = BuildMeasurementNoise(centroidList(detectionIdex), ekfParams);
    x0 = Sphere4ToCart6(z);
    P0 = ekfParams.P0;

    newTrack = emptyTrackStruct();
    newTrack(1).id = nextId;
    newTrack(1).state = 'tentative';
    newTrack(1).x_cart = x0;
    newTrack(1).P_cart = P0;
    newTrack(1).x_pred = x0;
    newTrack(1).P_pred = P0;
    newTrack(1).age = 1;
    newTrack(1).totalVisibleCount = 1;
    newTrack(1).consecutiveInvisibleCount = 0;
    newTrack(1).firstFrame = tIdex;
    newTrack(1).lastFrame = tIdex;
    newTrack(1).detect2activeCount = 0;
    newTrack(1).detect2freeCount = 0;
    newTrack(1).active2freeCount = 0;
    newTrack(1).lastAssociatedPointNum = centroidList(detectionIdex).numPoints;
    newTrack(1).visibility = 1;
    newTrack(1).lifecycleReason = 'created';
    newTrack(1).points = cell(0, 1);
    newTrack(1) = appendTrackHistory(newTrack(1), tIdex, x0, true, ...
        detectionIdex, 0, 0, centroidList(detectionIdex).points);

    tracks = [tracks, newTrack]; %#ok<AGROW>
    nextId = nextId + 1;
end
end

function trackNow = appendTrackHistory(trackNow, tIdex, xNow, isUpdated, ...
    detectionIdex, NIS, gateDistance, points)

trackNow.historyFrame = [trackNow.historyFrame; tIdex];
trackNow.historyState = [trackNow.historyState; xNow(:).'];
trackNow.historyUpdated = [trackNow.historyUpdated; logical(isUpdated)];
trackNow.historyDetectionIdex = [trackNow.historyDetectionIdex; detectionIdex];
trackNow.historyNIS = [trackNow.historyNIS; NIS];
trackNow.historyGateDistance = [trackNow.historyGateDistance; gateDistance];
if ~iscell(trackNow.points)
    trackNow.points = cell(0, 1);
end
trackNow.points{end+1, 1} = points;
end

function tracks = emptyTrackStruct()
tracks = struct( ...
    'id', {}, ...
    'state', {}, ...
    'x_cart', {}, ...
    'P_cart', {}, ...
    'x_pred', {}, ...
    'P_pred', {}, ...
    'age', {}, ...
    'totalVisibleCount', {}, ...
    'consecutiveInvisibleCount', {}, ...
    'firstFrame', {}, ...
    'lastFrame', {}, ...
    'detect2activeCount', {}, ...
    'detect2freeCount', {}, ...
    'active2freeCount', {}, ...
    'lastAssociatedPointNum', {}, ...
    'visibility', {}, ...
    'lifecycleReason', {}, ...
    'historyFrame', {}, ...
    'historyState', {}, ...
    'historyUpdated', {}, ...
    'historyDetectionIdex', {}, ...
    'historyNIS', {}, ...
    'historyGateDistance', {}, ...
    'points', {});
end

function sOut = getSubStruct(sIn, fieldName)
if isstruct(sIn) && isfield(sIn, fieldName) && isstruct(sIn.(fieldName))
    sOut = sIn.(fieldName);
else
    sOut = struct();
end
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
