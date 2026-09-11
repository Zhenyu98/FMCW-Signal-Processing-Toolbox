%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_mathworks_two_ray_mimo_pointcloud_source.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Validate official two-ray TDM-MIMO cube input for
%                       the local pointcloud processing route
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% success criteria
% This checkpoint extends the official wideband two-ray source from its
% validated SISO range-spectrum route to the TI_xWRx843 MIMO contract.
%
% 1. Output must keep SampleNum x PulseNum x RxNum x TxNum.
% 2. Every virtual channel must contain finite, non-zero two-ray echo.
% 3. In a deliberately resolvable geometry, all virtual channels must have
%    peaks near the expected direct/direct, mixed and reflected/reflected
%    apparent ranges within one FFT bin.
% 4. A non-broadside target must produce usable array spatial differences.
% 5. The MIMO cube must enter the existing pointcloud route and preserve
%    the standard eight-column frame_data contract.

%% toolbox path
toolboxRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(toolboxRoot, 'startup.m'));

%% define TI xWR1843-style resolvable two-ray scenario
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 3.04;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 16;
sensorParams.ArrayType = 'TI_xWRx843';

radarParams = RadarParameterGenerate(sensorParams);

targetParams.amplitude = 20;

multipathParams.RadarPosition_m = [0; 0; 5];
multipathParams.TargetPosition_m = [3; 10; 20];
multipathParams.TargetVelocity_mps = [0; 0; 0];
multipathParams.GroundReflectionCoefficient = -0.8;

sourceOptions.InternalOversampling = 128;

%% generate official TDM-MIMO two-ray echo
[data, sourceInfo, multipathInfo] = RadarCubeGenerateMathWorksTwoRay( ...
    targetParams, radarParams, multipathParams, sourceOptions);

expectedSize = [radarParams.nSample, radarParams.PulseNum, ...
    radarParams.RxNum, radarParams.TxNum];
assert(isequal(size(data), expectedSize), ...
    'MathWorks two-ray source does not preserve the TI_xWRx843 cube contract.');

channelPower = squeeze(mean(mean(abs(data).^2, 1), 2));
assert(all(isfinite(channelPower(:))) && all(channelPower(:) > 0), ...
    'MathWorks two-ray MIMO cube contains an invalid or empty virtual channel.');

expectedBins = round(multipathInfo.ExpectedApparentRange_m / radarParams.range_res) + 1;
maxBinError = 0;
for txIdex = 1:radarParams.TxNum
    for rxIdex = 1:radarParams.RxNum
        rangeProfile = abs(fft(squeeze(data(:, 1, rxIdex, txIdex))));
        [~, peakBins] = findpeaks(rangeProfile, ...
            'MinPeakDistance', 2, ...
            'MinPeakProminence', max(rangeProfile) * 0.05);
        assert(length(peakBins) >= 3, ...
            'One MIMO virtual channel does not expose the three two-ray range components.');
        for pathIdex = 1:length(expectedBins)
            maxBinError = max(maxBinError, min(abs(peakBins - expectedBins(pathIdex))));
        end
    end
end

spatialDifference = norm(data(:, :, 1, 1) - data(:, :, end, end), 'fro');
assert(isfinite(spatialDifference) && spatialDifference > eps, ...
    'Non-broadside two-ray target does not produce usable array spatial content.');

fprintf('MathWorks source type       : %s\n', sourceInfo.SourceType)
fprintf('Output cube size            : %s\n', mat2str(size(data)))
fprintf('Expected apparent ranges    : %s m\n', mat2str(multipathInfo.ExpectedApparentRange_m, 4))
fprintf('Expected range bins         : %s\n', mat2str(expectedBins))
fprintf('Max virtual-channel bin err : %d\n', maxBinError)
fprintf('Virtual-channel power range : [%.3e, %.3e]\n', ...
    min(channelPower(:)), max(channelPower(:)))
fprintf('Array spatial difference    : %.3e\n', spatialDifference)

assert(maxBinError <= 1, ...
    'Two-ray MIMO range peaks do not agree with expected path geometry.');

%% connect official two-ray MIMO cube to the local pointcloud route
cfgOut = ConfigurePointCloudParameter(sensorParams, radarParams);
cfgDOA.FFTNum = 180;
cfgDOA.AziMethod = 'FFT';
cfgDOA.EleMethod = 'FFT';
cfgDOA.thetaGrids = linspace(-90, 90, cfgDOA.FFTNum);
cfgDOA.AzisigNum = 1;
cfgDOA.ElesigNum = 1;
cfgDOA.Pfa = 1e-3;
cfgDOA.TestCells = [8, 2];
cfgDOA.GuardCells = [2, 1];
cfgDOA.PeakRelativeThreshold_dB = 35;
cfgDOA.MaxDetections = 20;

[frame_data, pointcloudInfo] = GeneratePointCloudFrame( ...
    RadarCubeToPointCloudInput(data), cfgOut, cfgDOA, 1);

assert(size(frame_data, 2) == 8, ...
    'Pointcloud route must keep frame_data = [X,Y,Z,Range,Azimuth,Elevation,Doppler,SNR].');
assert(~isempty(frame_data), ...
    'Official two-ray MIMO cube produced no local pointcloud detections.');
assert(isfield(pointcloudInfo, 'dopplerFFTOut') && ~isempty(pointcloudInfo.dopplerFFTOut), ...
    'Pointcloud processing did not retain the two-ray Doppler cube.');

fprintf('Pointcloud detection count  : %d\n', size(frame_data, 1))
disp('MathWorks official two-ray TDM-MIMO pointcloud source validation passed.')
