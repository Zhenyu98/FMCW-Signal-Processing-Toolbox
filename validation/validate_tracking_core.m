%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_tracking_core.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Validate tracking core with synthetic point clouds
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% generate point cloud sequence
FrameNum = 30;
ScatterPerTarget = 8;
TargetNum = 2;
TF = 0.08;

targetPosition0 = [-0.8,  5.0, 0.2;
                    1.2,  8.0, 0.3];
targetVelocity = [0.45, 0.20, 0.00;
                 -0.20, -0.12, 0.00];

frameDataSeq = cell(FrameNum, 1);
rng(2026)

for tIdex = 1:FrameNum
    frame_data = zeros(0, 8);
    for targetIdex = 1:TargetNum
        targetPos = targetPosition0(targetIdex,:) + ...
            targetVelocity(targetIdex,:) * TF * (tIdex - 1);
        targetVel = targetVelocity(targetIdex,:);

        pointXYZ = targetPos + 0.08 * randn(ScatterPerTarget, 3);
        range = sqrt(sum(pointXYZ.^2, 2));
        azimuth = atan2d(pointXYZ(:,1), pointXYZ(:,2));
        elevation = atan2d(pointXYZ(:,3), sqrt(pointXYZ(:,1).^2 + pointXYZ(:,2).^2));
        doppler = (pointXYZ * targetVel(:)) ./ max(range, eps) + 0.03 * randn(ScatterPerTarget, 1);
        snr = 18 + 4 * rand(ScatterPerTarget, 1);

        frame_obj = [pointXYZ, range, azimuth, elevation, doppler, snr];
        frame_data = [frame_data; frame_obj]; %#ok<AGROW>
    end
    frameDataSeq{tIdex} = frame_data;
end

%% define parameters
sensorParams.Frame_Repetition_Period_ms = TF * 1000;
radarParams.range_res = 0.05;
radarParams.doppler_res = 0.05;

[trackingParams, ekfParams] = ConfigureTrackingParameter(sensorParams, radarParams);
trackingParams.Cluster.DBSCAN_epsilon = 0.55;
trackingParams.Cluster.DBSCAN_MinPts = 3;
trackingParams.Track.MaxNewTracksPerFrame = TargetNum;
trackingParams.Track.MaxTrackNum = 6;
trackingParams.Track.MaxCoast = 3;
ekfParams.RMode = 'clusterVar';

%% main method
[trackResult, measurementSeq] = TrackPointCloudSequence(frameDataSeq, trackingParams, ekfParams);

confirmedNum = 0;
tracksAll = [trackResult.finishedTracks, trackResult.tracks];
for trackIdex = 1:length(tracksAll)
    if strcmp(tracksAll(trackIdex).state, 'confirmed') || ...
            tracksAll(trackIdex).totalVisibleCount >= trackingParams.Track.MinConfirmHits
        confirmedNum = confirmedNum + 1;
    end
end

if confirmedNum < TargetNum
    error('Tracking validation failed: confirmed track num is too small.')
end
if mean(measurementSeq.CandidateNum) < TargetNum
    error('Tracking validation failed: centroid candidates were not generated.')
end

disp('===== validate_tracking_core passed =====')
disp(['confirmed track num = ', num2str(confirmedNum)])
disp(['mean candidate num = ', num2str(mean(measurementSeq.CandidateNum))])
