function results = validate_ra_pointcloud_pipeline()
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_ra_pointcloud_pipeline.m
% Date & time         : Jun. 2026
% Version             : 1.0
% Purpose             : Validate range-azimuth point cloud generation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc

%% success criteria
% 1. RA pipeline returns frame_data with 8 columns:
%    X, Y, Z, Range, Azimuth, Elevation, Doppler, SNR.
% 2. On a two-target static ULA simulation, the RA detections match truth:
%    range error < 2 * range_res, azimuth error < 5 degree.
% 3. RAM / CFAR / peak list are exposed in pointcloudInfo for debugging.

rootDir = fileparts(fileparts(mfilename('fullpath')));
oldFolder = pwd;
cleanupObj = onCleanup(@() cd(oldFolder));
cd(rootDir)
startup

%% generate radar signal
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 19.988;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 64;
sensorParams.TxNum = 1;
sensorParams.RxNum = 8;
sensorParams.SNR_dB = 35;

targetParams.amplitude = [20, 18];              % Target amplitudes
targetParams.range = [5.0, 9.0];                % Target ranges (m)
targetParams.velocity = [0.0, 0.0];             % Static targets for RA sanity
targetParams.azimuth = [-15, 20];               % Target azimuth angles (degree)
targetParams.elevation = [0, 0];                % ULA, no elevation estimate

radarParams = RadarParameterGenerate(sensorParams, targetParams);
rng(2026)
[data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);
adcData = RadarCubeToPointCloudInput(data);

%% define point cloud parameters
cfgOut = ConfigurePointCloudParameter(sensorParams, radarParams);
IQFlag = 1;

cfgDOA.PointCloudPipeline = 'RA';
cfgDOA.FFTNum = 256;
cfgDOA.AziMethod = 'FFT';
cfgDOA.AzisigNum = 1;
cfgDOA.EleMethod = 'FFT';
cfgDOA.ElesigNum = 1;
cfgDOA.thetaGrids = linspace(-90, 90, cfgDOA.FFTNum);
cfgDOA.Pfa = 1e-3;
cfgDOA.TestCells = [8, 8];
cfgDOA.GuardCells = [2, 2];
cfgDOA.CFARMethod = 'separable_ca';
cfgDOA.L_bound = 0.2;
cfgDOA.MaxDetections = length(targetParams.range);

%% main method
[frame_data_direct, pointcloudInfo_direct] = GeneratePointCloudFrameRA(adcData, cfgOut, cfgDOA, IQFlag);
[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, IQFlag);

%% checks
assert(max(abs(frame_data_direct(:) - frame_data(:))) < 1e-12, ...
    'GeneratePointCloudFrame RA dispatcher must match direct RA entry.')
assert(isequal(pointcloudInfo_direct.ra_peak_list, pointcloudInfo.ra_peak_list), ...
    'GeneratePointCloudFrame RA dispatcher must preserve RA peak list.')
assert(size(frame_data, 2) == 8, 'frame_data must have 8 columns.')
assert(size(frame_data, 1) >= length(targetParams.range), 'RA pipeline missed target detections.')
assert(isfield(pointcloudInfo, 'RAM'), 'pointcloudInfo must expose RAM.')
assert(isfield(pointcloudInfo, 'ra_peak_list'), 'pointcloudInfo must expose ra_peak_list.')
assert(isfield(pointcloudInfo, 'angle_axis'), 'pointcloudInfo must expose angle_axis.')

truthRA = [targetParams.range(:), targetParams.azimuth(:)];
estRA = frame_data(:, [4, 5]);
[matchedEst, matchedTruth] = matchByRangeAzimuth(estRA, truthRA);

rangeErr = abs(matchedEst(:, 1) - matchedTruth(:, 1));
azimuthErr = abs(matchedEst(:, 2) - matchedTruth(:, 2));

rangeThreshold = 2 * radarParams.range_res;
azimuthThreshold = 5;

assert(all(rangeErr < rangeThreshold), 'RA range error exceeds threshold.')
assert(all(azimuthErr < azimuthThreshold), 'RA azimuth error exceeds threshold.')

results.frame_data = frame_data;
results.pointcloudInfo = pointcloudInfo;
results.noiseInfo = noiseInfo;
results.rangeErr = rangeErr;
results.azimuthErr = azimuthErr;
results.rangeThreshold = rangeThreshold;
results.azimuthThreshold = azimuthThreshold;
results.pointNum = size(frame_data, 1);

disp(' ')
disp('================ RA Pointcloud Pipeline Validation ================')
disp(['pointNum         = ', num2str(results.pointNum)])
disp(['rangeErr (m)     = ', mat2str(rangeErr.', 6)])
disp(['azimuthErr (deg) = ', mat2str(azimuthErr.', 6)])
disp(['range threshold  = ', num2str(rangeThreshold, 6), ' m'])
disp(['angle threshold  = ', num2str(azimuthThreshold, 6), ' deg'])
disp('RA pointcloud validation passed.')

end

function [matchedEst, matchedTruth] = matchByRangeAzimuth(estRA, truthRA)
matchedEst = zeros(size(truthRA));
matchedTruth = truthRA;
usedEst = false(size(estRA, 1), 1);

for targetIdex = 1:size(truthRA, 1)
    cost = abs(estRA(:, 1) - truthRA(targetIdex, 1)) + ...
        0.05 * abs(estRA(:, 2) - truthRA(targetIdex, 2));
    cost(usedEst) = Inf;
    [~, bestIdx] = min(cost);
    matchedEst(targetIdex, :) = estRA(bestIdx, :);
    usedEst(bestIdx) = true;
end
end
