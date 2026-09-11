%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_mathworks_pedestrian_signal_source.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Validate MathWorks official pedestrian signal input
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% success criteria
% 1. Official backscatterPedestrian must produce the local radar cube
%    contract: SampleNum x PulseNum x 1 x 1.
% 2. The generated signal power must be finite and non-zero.
% 3. Walking motion must produce finite, non-zero slow-time variation after
%    range FFT, so the cube can be used for micro-Doppler processing.

%% toolbox path
toolboxRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(toolboxRoot, 'startup.m'));

%% define a lightweight waveform-level pedestrian scenario
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 0.2;
sensorParams.Sampling_Rate_ksps = 1000;
sensorParams.Samples_per_Chirp = 64;
sensorParams.Frame = 64;
sensorParams.TxNum = 1;
sensorParams.RxNum = 1;

radarParams = RadarParameterGenerate(sensorParams);

pedestrianParams.Initial_Position_m = [0, 8, 0];
pedestrianParams.Height_m = 1.70;
pedestrianParams.WalkingSpeed_mps = 1.20;
pedestrianParams.Heading_deg = 0;

sourceOptions.InternalOversampling = 16;

%% generate official pedestrian echo
[data, sourceInfo, pedestrianInfo] = RadarCubeGenerateMathWorksPedestrian( ...
    pedestrianParams, radarParams, sourceOptions);

%% validate output contract and slow-time content
assert(size(data, 1) == radarParams.nSample);
assert(size(data, 2) == radarParams.PulseNum);
assert(size(data, 3) == 1 && size(data, 4) == 1);

signalPower = mean(abs(data(:)).^2);
rangeFFTOut = fft(squeeze(data(:, :, 1, 1)), [], 1);
slowSignal = sum(rangeFFTOut, 1);
slowSignal = slowSignal - mean(slowSignal);
slowTimeEnergy = sum(abs(fft(slowSignal)).^2);

fprintf('MathWorks source type       : %s\n', sourceInfo.SourceType)
fprintf('Body segment count          : %d\n', pedestrianInfo.BodySegmentNum)
fprintf('Output cube size            : %s\n', mat2str(size(data)))
fprintf('Signal power                : %.3e\n', signalPower)
fprintf('Slow-time variation energy  : %.3e\n', slowTimeEnergy)

assert(isfinite(signalPower) && signalPower > 0, ...
    'MathWorks pedestrian signal has invalid power.');
assert(isfinite(slowTimeEnergy) && slowTimeEnergy > eps, ...
    'MathWorks pedestrian signal has no usable slow-time motion content.');

disp('MathWorks official pedestrian signal source validation passed.')
