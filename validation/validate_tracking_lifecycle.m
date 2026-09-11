%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_tracking_lifecycle.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Validate TI-GTRACK style track lifecycle management
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% define parameters
[trackingParams, ~] = ConfigureTrackingParameter();
trackParams = trackingParams.Track;
trackParams.Detect2ActiveThreshold = 2;
trackParams.Detect2FreeThreshold = 2;
trackParams.Active2FreeThreshold = 3;
trackParams.MinAssociatedPoints = 1;
trackParams.UseVisibilityDelete = true;

%% detection state should become confirmed after enough hits
tracks = makeTrack(1, 'tentative', 1, 1, 0, true, 6);
finishedTracks = tracks([]);

[tracks, finishedTracks] = UpdateTrackLifecycle(tracks, finishedTracks, trackParams);
assert(strcmp(tracks(1).state, 'tentative'))
assert(tracks(1).detect2activeCount == 1)

tracks(1) = appendEvent(tracks(1), 2, true, 6);
[tracks, finishedTracks] = UpdateTrackLifecycle(tracks, finishedTracks, trackParams);
assert(strcmp(tracks(1).state, 'confirmed'))
assert(isempty(finishedTracks))

%% tentative track should be deleted after repeated misses
tracks = makeTrack(2, 'tentative', 1, 1, 0, true, 6);
finishedTracks = tracks([]);
[tracks, finishedTracks] = UpdateTrackLifecycle(tracks, finishedTracks, trackParams);

tracks(1) = appendEvent(tracks(1), 2, false, 0);
[tracks, finishedTracks] = UpdateTrackLifecycle(tracks, finishedTracks, trackParams);
assert(~isempty(tracks))

tracks(1) = appendEvent(tracks(1), 3, false, 0);
[tracks, finishedTracks] = UpdateTrackLifecycle(tracks, finishedTracks, trackParams);
assert(isempty(tracks))
assert(strcmp(finishedTracks(1).state, 'deleted'))
assert(strcmp(finishedTracks(1).lifecycleReason, 'detect2free'))

%% confirmed track should coast and then be deleted
tracks = makeTrack(3, 'confirmed', 5, 5, 0, true, 6);
finishedTracks = tracks([]);

for tIdex = 6:8
    tracks(1) = appendEvent(tracks(1), tIdex, false, 0);
    [tracks, finishedTracks] = UpdateTrackLifecycle(tracks, finishedTracks, trackParams);
end

assert(isempty(tracks))
assert(strcmp(finishedTracks(1).lifecycleReason, 'active2free'))

%% low visibility confirmed track can be removed by visibility rule
tracks = makeTrack(4, 'confirmed', 10, 1, 0, false, 0);
finishedTracks = tracks([]);
[tracks, finishedTracks] = UpdateTrackLifecycle(tracks, finishedTracks, trackParams);
assert(isempty(tracks))
assert(strcmp(finishedTracks(1).lifecycleReason, 'confirmed_low_visibility'))

disp('===== validate_tracking_lifecycle passed =====')
disp('det2active / det2free / active2free / visibility checks passed')

% -------------------------- Subfunctions -------------------------------
function trackNow = makeTrack(id, stateName, age, visibleCount, invisibleCount, isUpdated, pointNum)
trackNow.id = id;
trackNow.state = stateName;
trackNow.x_cart = zeros(6, 1);
trackNow.P_cart = eye(6);
trackNow.x_pred = zeros(6, 1);
trackNow.P_pred = eye(6);
trackNow.age = age;
trackNow.totalVisibleCount = visibleCount;
trackNow.consecutiveInvisibleCount = invisibleCount;
trackNow.firstFrame = 1;
trackNow.lastFrame = age;
trackNow.detect2activeCount = 0;
trackNow.detect2freeCount = 0;
trackNow.active2freeCount = 0;
trackNow.lastAssociatedPointNum = pointNum;
trackNow.visibility = visibleCount / max(age, 1);
trackNow.lifecycleReason = '';
trackNow.historyFrame = age;
trackNow.historyState = zeros(1, 6);
trackNow.historyUpdated = logical(isUpdated);
trackNow.historyDetectionIdex = 1;
trackNow.historyNIS = 0;
trackNow.historyGateDistance = 0;
trackNow.points = cell(0, 1);
end

function trackNow = appendEvent(trackNow, frameIdex, isUpdated, pointNum)
trackNow.age = trackNow.age + 1;
trackNow.lastFrame = frameIdex;
if isUpdated
    trackNow.totalVisibleCount = trackNow.totalVisibleCount + 1;
    trackNow.consecutiveInvisibleCount = 0;
else
    trackNow.consecutiveInvisibleCount = trackNow.consecutiveInvisibleCount + 1;
end
trackNow.lastAssociatedPointNum = pointNum;
trackNow.historyFrame = [trackNow.historyFrame; frameIdex];
trackNow.historyState = [trackNow.historyState; zeros(1, 6)];
trackNow.historyUpdated = [trackNow.historyUpdated; logical(isUpdated)];
trackNow.historyDetectionIdex = [trackNow.historyDetectionIdex; double(isUpdated)];
trackNow.historyNIS = [trackNow.historyNIS; NaN];
trackNow.historyGateDistance = [trackNow.historyGateDistance; NaN];
end
