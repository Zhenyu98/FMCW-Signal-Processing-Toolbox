%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_tracking_pointcloud_integration.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Validate signal -> pointcloud -> tracking workflow
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% generate radar signal / point cloud sequence
sensorParams.Start_Freq_GHz = 76.5;
sensorParams.Slope_MHzperus = 46.397;
sensorParams.Sampling_Rate_ksps = 6874;
sensorParams.Samples_per_Chirp = 128;
sensorParams.Frame = 32;                         % TDM cycles in one radar frame
sensorParams.Frame_Repetition_Period_ms = 80;    % Tracking frame interval
sensorParams.TxNum = 3;
sensorParams.RxNum = 4;
sensorParams.ArrayType = 'TI_xWRx843';
sensorParams.SNR_dB = 26;

FrameNum = 24;
TargetNum = 2;
TF = sensorParams.Frame_Repetition_Period_ms / 1000;

targetPosition0 = [-0.8,  5.5, 0.2;
                    1.2,  8.2, 0.4];
targetVelocity_mps = [0.45, 0.20, 0.00;
                     -0.25, -0.10, 0.00];
targetAmplitude = [30; 24];

targetParams.position_m = targetPosition0;
targetParams.velocity_mps = targetVelocity_mps;
targetParams.amplitude = targetAmplitude;
radarParams = RadarParameterGenerate(sensorParams, targetParams);

cfgOut = ConfigurePointCloudParameter(sensorParams, radarParams);
cfgDOA.FFTNum = 180;
cfgDOA.AziMethod = 'FFT';
cfgDOA.EleMethod = 'FFT';
cfgDOA.thetaGrids = linspace(-90, 90, cfgDOA.FFTNum);
cfgDOA.AzisigNum = 1;
cfgDOA.ElesigNum = 1;
cfgDOA.Pfa = 1e-3;
cfgDOA.TestCells = [8, 8];
cfgDOA.GuardCells = [2, 2];
cfgDOA.MinPeakSNR_dB = 12;
cfgDOA.MaxDetections = 12;
cfgDOA.PeakRelativeThreshold_dB = 25;

frameDataSeq = cell(FrameNum, 1);
truePosition = zeros(TargetNum, 3, FrameNum);
rng(2026)

for tIdex = 1:FrameNum
    targetParams.position_m = targetPosition0 + targetVelocity_mps * TF * (tIdex - 1);
    targetParams.velocity_mps = targetVelocity_mps;
    truePosition(:,:,tIdex) = targetParams.position_m;

    [data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);
    adcData = RadarCubeToPointCloudInput(data);
    [frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, 1);
    frameDataSeq{tIdex} = frame_data;

    disp(['frame ', num2str(tIdex), '/', num2str(FrameNum), ...
        ', point num = ', num2str(size(frame_data, 1))])
end

%% define tracking parameters
[trackingParams, ekfParams] = ConfigureTrackingParameter(sensorParams, radarParams);
trackingParams.Cluster.DBSCAN_epsilon = 0.90;
trackingParams.Cluster.DBSCAN_MinPts = 1;
trackingParams.Track.MaxNewTracksPerFrame = TargetNum;
trackingParams.Track.MaxTrackNum = 6;
trackingParams.Track.MaxCoast = 4;
trackingParams.Track.MinConfirmHits = 2;

ekfParams.RMode = 'clusterVar';

disp(['tracking SNR = ', num2str(noiseInfo.SNR_dB), ' dB'])
disp(['GNN gate threshold = ', ...
    num2str(trackingParams.Association.GateThreshold, '%.4f')])

%% main method
[trackResult, measurementSeq] = TrackPointCloudSequence(frameDataSeq, trackingParams, ekfParams);

%% validation checks
tracksAll = [trackResult.finishedTracks, trackResult.tracks];
visibleCount = [tracksAll.totalVisibleCount];
confirmedMask = visibleCount >= trackingParams.Track.MinConfirmHits;
longTrackMask = visibleCount >= round(0.80 * FrameNum);

if sum(confirmedMask) < TargetNum
    error('Integration validation failed: confirmed track num is too small.')
end
if sum(longTrackMask) < TargetNum
    error('Integration validation failed: long visible tracks were not maintained.')
end
if mean(measurementSeq.CandidateNum) < TargetNum
    error('Integration validation failed: pointcloud centroid candidates are missing.')
end

%% plotting and comparison
fig = VisualizeTrackingResult(trackResult, measurementSeq);

figure(fig)
axList = findobj(fig, 'Type', 'axes');
ax = axList(end);
hold(ax, 'on')
for targetIdex = 1:TargetNum
    xyTrue = squeeze(truePosition(targetIdex, 1:2, :)).';
    plot(ax, xyTrue(:,1), xyTrue(:,2), 'k--', 'LineWidth', 1.2)
end
legend(ax, 'raw point', 'centroid', 'track', 'track start', 'track end', ...
    'true trajectory', 'Location', 'best')

disp('===== tracking summary =====')
disp(['active track num = ', num2str(length(trackResult.tracks))])
disp(['finished track num = ', num2str(length(trackResult.finishedTracks))])
for trackIdex = 1:length(trackResult.tracks)
    disp(['track ', num2str(trackResult.tracks(trackIdex).id), ...
        ', state = ', trackResult.tracks(trackIdex).state, ...
        ', visible = ', num2str(trackResult.tracks(trackIdex).totalVisibleCount), ...
        ', coast = ', num2str(trackResult.tracks(trackIdex).consecutiveInvisibleCount)])
end

disp('===== validate_tracking_pointcloud_integration passed =====')
