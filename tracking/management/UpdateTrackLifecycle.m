function [tracks, finishedTracks, lifecycleInfo] = UpdateTrackLifecycle(tracks, finishedTracks, trackParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : UpdateTrackLifecycle.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : TI-GTRACK style track lifecycle management
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 2 || isempty(finishedTracks)
    finishedTracks = tracks([]);
end
if nargin < 3
    trackParams = struct();
end

lifecycleInfo.deletedTrackIds = [];
lifecycleInfo.deletedReason = {};
lifecycleInfo.stateList = strings(0, 1);

if isempty(tracks)
    return
end

tracks = ensureLifecycleFields(tracks);

det2activeThreshold = round(getStructNumber(trackParams, 'Detect2ActiveThreshold', ...
    getStructNumber(trackParams, 'MinConfirmHits', 2)));
det2freeThreshold = round(getStructNumber(trackParams, 'Detect2FreeThreshold', 2));
active2freeThreshold = round(getStructNumber(trackParams, 'Active2FreeThreshold', ...
    getStructNumber(trackParams, 'MaxCoast', 5)));
minAssociatedPoints = round(getStructNumber(trackParams, 'MinAssociatedPoints', 1));

useVisibilityDelete = getStructLogical(trackParams, 'UseVisibilityDelete', true);
ageThreshold = round(getStructNumber(trackParams, 'AgeThreshold', 5));
minTentativeVisibility = getStructNumber(trackParams, 'MinTentativeVisibility', 0.34);
minConfirmedVisibility = getStructNumber(trackParams, 'MinConfirmedVisibility', 0.20);

det2activeThreshold = max(det2activeThreshold, 1);
det2freeThreshold = max(det2freeThreshold, 1);
active2freeThreshold = max(active2freeThreshold, 1);
minAssociatedPoints = max(minAssociatedPoints, 1);

deleteMask = false(1, length(tracks));
deleteReason = strings(1, length(tracks));

for trackIdex = 1:length(tracks)
    stateName = lower(char(string(tracks(trackIdex).state)));
    isUpdated = getLastUpdated(tracks(trackIdex));
    pointNum = getStructNumber(tracks(trackIdex), 'lastAssociatedPointNum', double(isUpdated));
    hasStrongDetection = isUpdated && pointNum >= minAssociatedPoints;

    age = max(getStructNumber(tracks(trackIdex), 'age', 1), 1);
    totalVisibleCount = getStructNumber(tracks(trackIdex), 'totalVisibleCount', 0);
    visibility = totalVisibleCount / age;
    tracks(trackIdex).visibility = visibility;

    switch stateName
        case {'tentative', 'detection', 'init'}
            tracks(trackIdex).state = 'tentative';
            if hasStrongDetection
                tracks(trackIdex).detect2activeCount = tracks(trackIdex).detect2activeCount + 1;
                tracks(trackIdex).detect2freeCount = 0;
                if tracks(trackIdex).detect2activeCount >= det2activeThreshold
                    tracks(trackIdex).state = 'confirmed';
                    tracks(trackIdex).lifecycleReason = 'detect2active';
                else
                    tracks(trackIdex).lifecycleReason = 'tentative_hit';
                end
            else
                tracks(trackIdex).detect2freeCount = tracks(trackIdex).detect2freeCount + 1;
                tracks(trackIdex).detect2activeCount = max(tracks(trackIdex).detect2activeCount - 1, 0);
                tracks(trackIdex).lifecycleReason = 'tentative_miss';
                if tracks(trackIdex).detect2freeCount >= det2freeThreshold
                    deleteMask(trackIdex) = true;
                    deleteReason(trackIdex) = "detect2free";
                end
            end

            % Early low-visibility tentative tracks are usually false alarms.
            if useVisibilityDelete && age >= ageThreshold && visibility < minTentativeVisibility
                deleteMask(trackIdex) = true;
                deleteReason(trackIdex) = "tentative_low_visibility";
            end

        case {'confirmed', 'active', 'normal'}
            tracks(trackIdex).state = 'confirmed';
            if hasStrongDetection
                tracks(trackIdex).active2freeCount = 0;
                tracks(trackIdex).lifecycleReason = 'active_hit';
            else
                tracks(trackIdex).active2freeCount = tracks(trackIdex).active2freeCount + 1;
                tracks(trackIdex).lifecycleReason = 'active_miss';
                if tracks(trackIdex).active2freeCount >= active2freeThreshold
                    deleteMask(trackIdex) = true;
                    deleteReason(trackIdex) = "active2free";
                end
            end

            if useVisibilityDelete && age >= ageThreshold && visibility < minConfirmedVisibility
                deleteMask(trackIdex) = true;
                deleteReason(trackIdex) = "confirmed_low_visibility";
            end

        otherwise
            tracks(trackIdex).state = 'tentative';
            tracks(trackIdex).lifecycleReason = 'state_reset';
    end
end

if any(deleteMask)
    deletedTracks = tracks(deleteMask);
    deletedIdex = find(deleteMask);
    for ii = 1:length(deletedTracks)
        deletedTracks(ii).state = 'deleted';
        deletedTracks(ii).lifecycleReason = char(deleteReason(deletedIdex(ii)));
    end
    lifecycleInfo.deletedTrackIds = [deletedTracks.id];
    lifecycleInfo.deletedReason = cellstr(deleteReason(deleteMask));
    finishedTracks = [finishedTracks, deletedTracks]; %#ok<AGROW>
    tracks = tracks(~deleteMask);
end

if ~isempty(tracks)
    lifecycleInfo.stateList = string({tracks.state}).';
end

end

function tracks = ensureLifecycleFields(tracks)
tracks = addFieldIfMissing(tracks, 'detect2activeCount', 0);
tracks = addFieldIfMissing(tracks, 'detect2freeCount', 0);
tracks = addFieldIfMissing(tracks, 'active2freeCount', 0);
tracks = addFieldIfMissing(tracks, 'lastAssociatedPointNum', 0);
tracks = addFieldIfMissing(tracks, 'visibility', 0);
tracks = addFieldIfMissing(tracks, 'lifecycleReason', '');
end

function tracks = addFieldIfMissing(tracks, fieldName, defaultValue)
if ~isfield(tracks, fieldName)
    [tracks.(fieldName)] = deal(defaultValue);
end
end

function isUpdated = getLastUpdated(trackNow)
if isfield(trackNow, 'historyUpdated') && ~isempty(trackNow.historyUpdated)
    isUpdated = logical(trackNow.historyUpdated(end));
else
    isUpdated = getStructLogical(trackNow, 'isUpdated', false);
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
