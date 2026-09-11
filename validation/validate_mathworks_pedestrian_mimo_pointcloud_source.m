%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_mathworks_pedestrian_mimo_pointcloud_source.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Validate official pedestrian TDM-MIMO cube input
%                       for the local pointcloud processing route
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% success criteria
% This checkpoint validates interface and spatial content, not hardware
% calibration or equivalence to the local hand-written human model.
%
% 1. The official reflect output must be linearly decomposable into its
%    16 body-segment incident columns for MIMO path propagation.
% 2. The official pedestrian source must return the TI_xWRx843 cube
%    contract: SampleNum x PulseNum x RxNum x TxNum.
% 3. Every virtual channel must contain finite, non-zero official body echo.
% 4. A non-broadside pedestrian must produce non-identical array channels.
% 5. The cube must enter the local pointcloud route and retain the standard
%    eight-column frame_data output.
% 6. At least one detected point must lie within the official 16-segment
%    body range/angle envelope, allowing one processing-bin tolerance.

%% toolbox path
toolboxRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(toolboxRoot, 'startup.m'));

%% define TI xWR1843-style pedestrian scenario
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 6.08;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Samples_per_Chirp = 128;
sensorParams.Frame = 16;
sensorParams.ArrayType = 'TI_xWRx843';

radarParams = RadarParameterGenerate(sensorParams);

pedestrianParams.Initial_Position_m = [2, 8, 0];
pedestrianParams.Height_m = 1.70;
pedestrianParams.WalkingSpeed_mps = 1.20;
pedestrianParams.Heading_deg = 0;

sourceOptions.InternalOversampling = 32;

%% verify the official per-segment reflection decomposition used by MIMO
decompositionPedestrian = backscatterPedestrian( ...
    'Height', pedestrianParams.Height_m, ...
    'WalkingSpeed', pedestrianParams.WalkingSpeed_mps, ...
    'PropagationSpeed', radarParams.c, ...
    'OperatingFrequency', radarParams.fc, ...
    'InitialPosition', pedestrianParams.Initial_Position_m(:), ...
    'InitialHeading', pedestrianParams.Heading_deg);
[bodyPosition, ~, bodyAxes] = move( ...
    decompositionPedestrian, radarParams.Ta, pedestrianParams.Heading_deg);
rng(2026)
incidentProbe = complex(randn(32, 16), randn(32, 16));
[~, incidentAngle] = rangeangle([0; 0; 0], bodyPosition, bodyAxes);
combinedReflection = reflect(decompositionPedestrian, incidentProbe, incidentAngle);
separateReflection = zeros(size(incidentProbe));
for bodyIdex = 1:size(bodyPosition, 2)
    isolatedProbe = zeros(size(incidentProbe));
    isolatedProbe(:, bodyIdex) = incidentProbe(:, bodyIdex);
    separateReflection(:, bodyIdex) = reflect( ...
        decompositionPedestrian, isolatedProbe, incidentAngle);
end
reflectNmse = norm(combinedReflection - sum(separateReflection, 2))^2 / ...
    (norm(combinedReflection)^2 + eps);
reflectNmse_dB = 10 * log10(reflectNmse + eps);

fprintf('Reflect decomposition NMSE  : %.3f dB\n', reflectNmse_dB)
assert(reflectNmse_dB < -120, ...
    'Official pedestrian reflect output is not segment-linearly decomposable.');

%% generate official pedestrian echo for the virtual array
[data, sourceInfo, pedestrianInfo] = RadarCubeGenerateMathWorksPedestrian( ...
    pedestrianParams, radarParams, sourceOptions);

expectedSize = [radarParams.nSample, radarParams.PulseNum, ...
    radarParams.RxNum, radarParams.TxNum];
assert(isequal(size(data), expectedSize), ...
    'MathWorks pedestrian source does not preserve the TI_xWRx843 cube contract.');
assert(pedestrianInfo.BodySegmentNum == 16, ...
    'Official pedestrian source must retain the 16-segment body model.');

channelPower = squeeze(mean(mean(abs(data).^2, 1), 2));
assert(all(isfinite(channelPower(:))) && all(channelPower(:) > 0), ...
    'MathWorks pedestrian MIMO cube contains an invalid or empty virtual channel.');

spatialDifference = norm(data(:, :, 1, 1) - data(:, :, end, end), 'fro');
assert(isfinite(spatialDifference) && spatialDifference > eps, ...
    'Non-broadside pedestrian does not produce usable array spatial content.');

fprintf('MathWorks source type       : %s\n', sourceInfo.SourceType)
fprintf('Output cube size            : %s\n', mat2str(size(data)))
fprintf('Virtual-channel power range : [%.3e, %.3e]\n', ...
    min(channelPower(:)), max(channelPower(:)))
fprintf('Array spatial difference    : %.3e\n', spatialDifference)

%% connect official pedestrian cube to the local pointcloud pipeline
cfgOut = ConfigurePointCloudParameter(sensorParams, radarParams);
cfgDOA.FFTNum = 180;
cfgDOA.AziMethod = 'FFT';
cfgDOA.EleMethod = 'FFT';
cfgDOA.thetaGrids = linspace(-90, 90, cfgDOA.FFTNum);
cfgDOA.AzisigNum = 1;
cfgDOA.ElesigNum = 1;
cfgDOA.Pfa = 1e-3;
cfgDOA.TestCells = [4, 2];
cfgDOA.GuardCells = [1, 1];
cfgDOA.PeakRelativeThreshold_dB = 30;
cfgDOA.MaxDetections = 20;

[frame_data, pointcloudInfo] = GeneratePointCloudFrame( ...
    RadarCubeToPointCloudInput(data), cfgOut, cfgDOA, 1);

assert(size(frame_data, 2) == 8, ...
    'Pointcloud route must keep frame_data = [X,Y,Z,Range,Azimuth,Elevation,Doppler,SNR].');
assert(~isempty(frame_data), ...
    'Official pedestrian MIMO cube produced no local pointcloud detections.');

bodyPosition_m = pedestrianInfo.BodyPosition_m;
bodyRange_m = squeeze(sqrt(sum(bodyPosition_m.^2, 1)));
bodyX_m = squeeze(bodyPosition_m(1, :, :, :));
bodyY_m = squeeze(bodyPosition_m(2, :, :, :));
bodyZ_m = squeeze(bodyPosition_m(3, :, :, :));
bodyAzimuth_deg = atan2d(bodyX_m, bodyY_m);
bodyHorizontalRange_m = sqrt(bodyX_m.^2 + bodyY_m.^2);
bodyElevation_deg = atan2d(bodyZ_m, bodyHorizontalRange_m);

angleGridStep_deg = abs(cfgDOA.thetaGrids(2) - cfgDOA.thetaGrids(1));
rangeInEnvelope = frame_data(:, 4) >= min(bodyRange_m(:)) - radarParams.range_res & ...
    frame_data(:, 4) <= max(bodyRange_m(:)) + radarParams.range_res;
azimuthInEnvelope = frame_data(:, 5) >= min(bodyAzimuth_deg(:)) - angleGridStep_deg & ...
    frame_data(:, 5) <= max(bodyAzimuth_deg(:)) + angleGridStep_deg;
elevationInEnvelope = frame_data(:, 6) >= min(bodyElevation_deg(:)) - angleGridStep_deg & ...
    frame_data(:, 6) <= max(bodyElevation_deg(:)) + angleGridStep_deg;
bodyDetectionMask = rangeInEnvelope & azimuthInEnvelope & elevationInEnvelope;

fprintf('Pointcloud detection count  : %d\n', size(frame_data, 1))
fprintf('Body range envelope         : [%.3f, %.3f] m\n', ...
    min(bodyRange_m(:)), max(bodyRange_m(:)))
fprintf('Body azimuth envelope       : [%.3f, %.3f] deg\n', ...
    min(bodyAzimuth_deg(:)), max(bodyAzimuth_deg(:)))
fprintf('Body elevation envelope     : [%.3f, %.3f] deg\n', ...
    min(bodyElevation_deg(:)), max(bodyElevation_deg(:)))

assert(any(bodyDetectionMask), ...
    'No pointcloud detection lies within the official pedestrian body envelope.');
assert(isfield(pointcloudInfo, 'dopplerFFTOut') && ~isempty(pointcloudInfo.dopplerFFTOut), ...
    'Pointcloud processing did not retain the pedestrian Doppler cube.');

disp('MathWorks official pedestrian TDM-MIMO pointcloud source validation passed.')
