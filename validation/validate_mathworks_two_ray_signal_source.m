%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_mathworks_two_ray_signal_source.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Validate official MathWorks two-ray signal input
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% success criteria
% 1. The official widebandTwoRayChannel path must produce the local SISO cube
%    contract: SampleNum x PulseNum x 1 x 1.
% 2. In a deliberately resolvable height geometry, the range spectrum must
%    contain peaks at the expected direct/direct, direct/reflected and
%    reflected/reflected apparent ranges within one FFT bin.
% 3. This validates multipath signal generation only. It does not represent
%    a calibrated indoor environment.

%% toolbox path
toolboxRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(toolboxRoot, 'startup.m'));

%% define FMCW waveform and resolvable two-ray geometry
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 3.04;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 1;
sensorParams.TxNum = 1;
sensorParams.RxNum = 1;

radarParams = RadarParameterGenerate(sensorParams);

targetParams.amplitude = 1;

multipathParams.RadarPosition_m = [0; 0; 5];
multipathParams.TargetPosition_m = [0; 10; 20];
multipathParams.TargetVelocity_mps = [0; 0; 0];
multipathParams.GroundReflectionCoefficient = -0.8;

sourceOptions.InternalOversampling = 128;

%% generate official two-ray signal
[data, sourceInfo, multipathInfo] = RadarCubeGenerateMathWorksTwoRay( ...
    targetParams, radarParams, multipathParams, sourceOptions);

%% compare detected peaks with two-ray geometry
assert(size(data, 1) == radarParams.nSample);
assert(size(data, 2) == radarParams.PulseNum);
assert(size(data, 3) == 1 && size(data, 4) == 1);

rangeProfile = abs(fft(squeeze(data(:, 1, 1, 1))));
[~, peakBins] = findpeaks(rangeProfile, ...
    'MinPeakDistance', 2, ...
    'MinPeakProminence', max(rangeProfile) * 0.05);

expectedBins = round(multipathInfo.ExpectedApparentRange_m / radarParams.range_res) + 1;
binError = zeros(size(expectedBins));
for pathIdex = 1:length(expectedBins)
    binError(pathIdex) = min(abs(peakBins - expectedBins(pathIdex)));
end

fprintf('MathWorks source type       : %s\n', sourceInfo.SourceType)
fprintf('Expected apparent ranges    : %s m\n', mat2str(multipathInfo.ExpectedApparentRange_m, 4))
fprintf('Expected range bins         : %s\n', mat2str(expectedBins))
fprintf('Detected peak bins          : %s\n', mat2str(peakBins.'))
fprintf('Nearest-bin errors          : %s\n', mat2str(binError))

assert(length(peakBins) >= 3, 'Two-ray output does not expose three resolvable range peaks.');
assert(all(binError <= 1), 'Two-ray peaks do not agree with expected path geometry.');

disp('MathWorks official two-ray signal source validation passed.')
