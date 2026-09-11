%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_mathworks_moving_point_target_source.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Validate MathWorks moving point-target TDM-MIMO
%                       source against the local analytic source
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% success criteria
% This checkpoint isolates the moving-point interface before introducing
% an official pedestrian into TDM-MIMO pointcloud generation.
%
% 1. Both clean sources must return the same TI_xWRx843 3Tx4Rx cube size.
% 2. Dominant range-Doppler bins must match in every virtual channel.
% 3. The detected Doppler sign and bin must agree with the configured
%    radial velocity to within one Doppler bin.
% 4. After one global complex gain alignment, cube NMSE must be below
%    -18 dB; this checks the motion/TDM phase convention.
% 5. Both cubes must enter the existing pointcloud route, keep the
%    eight-column frame_data contract, and give the same strongest target
%    range, velocity, azimuth and elevation within one processing bin.

%% toolbox path
toolboxRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(toolboxRoot, 'startup.m'));

%% define clean moving target and TI xWR1843-style radar
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 3.04;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 32;
sensorParams.ArrayType = 'TI_xWRx843';

targetParams.amplitude = 20;
targetParams.range = 7;
targetParams.velocity = 0.8;
targetParams.azimuth = 15;
targetParams.elevation = 5;

sourceOptions.InternalOversampling = 128;
alignedNmseThreshold_dB = -18;

radarParams = RadarParameterGenerate(sensorParams, targetParams);

%% compare local and MathWorks data cubes
localData = RadarCubeGenerate(targetParams, radarParams);
mathWorksData = RadarCubeGenerateMathWorksIdeal(targetParams, radarParams, sourceOptions);

assert(isequal(size(localData), size(mathWorksData)), ...
    'Moving TI_xWRx843 cube sizes differ between local and MathWorks sources.');
assert(isequal(size(mathWorksData), [radarParams.nSample, radarParams.PulseNum, ...
    radarParams.RxNum, radarParams.TxNum]), ...
    'Moving MathWorks point-target source does not preserve the local cube contract.');

localRDM = fftshift(fft(fft(localData, [], 1), [], 2), 2);
mathWorksRDM = fftshift(fft(fft(mathWorksData, [], 1), [], 2), 2);

localPeakIndex = zeros(radarParams.RxNum, radarParams.TxNum, 2);
mathWorksPeakIndex = zeros(radarParams.RxNum, radarParams.TxNum, 2);
for txIdex = 1:radarParams.TxNum
    for rxIdex = 1:radarParams.RxNum
        [~, peakIdex] = max(abs(localRDM(:, :, rxIdex, txIdex)), [], 'all');
        [rangeBin, dopplerBin] = ind2sub([radarParams.nSample, radarParams.PulseNum], peakIdex);
        localPeakIndex(rxIdex, txIdex, :) = [rangeBin, dopplerBin];

        [~, peakIdex] = max(abs(mathWorksRDM(:, :, rxIdex, txIdex)), [], 'all');
        [rangeBin, dopplerBin] = ind2sub([radarParams.nSample, radarParams.PulseNum], peakIdex);
        mathWorksPeakIndex(rxIdex, txIdex, :) = [rangeBin, dopplerBin];
    end
end

maxPeakBinError = max(abs(localPeakIndex(:) - mathWorksPeakIndex(:)));
dopplerBin = localPeakIndex(1, 1, 2);
estimatedVelocity_mps = radarParams.doppler_axis(dopplerBin);
velocityError_mps = abs(estimatedVelocity_mps - targetParams.velocity);

alpha = (mathWorksData(:)' * localData(:)) / ...
    (mathWorksData(:)' * mathWorksData(:) + eps);
alignedNmse = norm(localData(:) - alpha * mathWorksData(:))^2 / ...
    (norm(localData(:))^2 + eps);
alignedNmse_dB = 10 * log10(alignedNmse + eps);

fprintf('Moving TI_xWRx843 cube size : %s\n', mat2str(size(mathWorksData)))
fprintf('Range-Doppler bin error     : %d\n', maxPeakBinError)
fprintf('Truth velocity              : %.4f m/s\n', targetParams.velocity)
fprintf('Estimated velocity          : %.4f m/s\n', estimatedVelocity_mps)
fprintf('Velocity error / resolution : %.4f / %.4f m/s\n', ...
    velocityError_mps, radarParams.doppler_res)
fprintf('Moving cube aligned NMSE    : %.3f dB\n', alignedNmse_dB)

assert(maxPeakBinError == 0, ...
    'Moving range-Doppler peak bins differ between local and MathWorks sources.');
assert(sign(estimatedVelocity_mps) == sign(targetParams.velocity) && ...
    velocityError_mps <= radarParams.doppler_res, ...
    'Local moving target probe does not preserve the configured Doppler sign/bin.');
assert(alignedNmse_dB < alignedNmseThreshold_dB, ...
    'Moving TDM-MIMO phase contract does not meet the aligned NMSE threshold.');

%% run both sources through the current pointcloud processing route
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
cfgDOA.MaxDetections = 1;       % Compare only the dominant clean target.

[localFrame, ~] = GeneratePointCloudFrame( ...
    RadarCubeToPointCloudInput(localData), cfgOut, cfgDOA, 1);
[mathWorksFrame, ~] = GeneratePointCloudFrame( ...
    RadarCubeToPointCloudInput(mathWorksData), cfgOut, cfgDOA, 1);

assert(size(localFrame, 2) == 8 && size(mathWorksFrame, 2) == 8, ...
    'Pointcloud route must keep frame_data = [X,Y,Z,Range,Azimuth,Elevation,Doppler,SNR].');
assert(size(localFrame, 1) == 1 && size(mathWorksFrame, 1) == 1, ...
    'Clean moving point-target validation expects one dominant point from both sources.');

rangeError_m = abs(localFrame(1, 4) - mathWorksFrame(1, 4));
azimuthError_deg = abs(localFrame(1, 5) - mathWorksFrame(1, 5));
elevationError_deg = abs(localFrame(1, 6) - mathWorksFrame(1, 6));
dopplerError_mps = abs(localFrame(1, 7) - mathWorksFrame(1, 7));
angleGridStep_deg = abs(cfgDOA.thetaGrids(2) - cfgDOA.thetaGrids(1));

fprintf('Pointcloud local result      : [R %.3f, Az %.3f, El %.3f, V %.3f]\n', ...
    localFrame(1, 4), localFrame(1, 5), localFrame(1, 6), localFrame(1, 7))
fprintf('Pointcloud MathWorks result  : [R %.3f, Az %.3f, El %.3f, V %.3f]\n', ...
    mathWorksFrame(1, 4), mathWorksFrame(1, 5), mathWorksFrame(1, 6), mathWorksFrame(1, 7))

assert(rangeError_m <= radarParams.range_res && ...
    dopplerError_mps <= radarParams.doppler_res && ...
    azimuthError_deg <= angleGridStep_deg && ...
    elevationError_deg <= angleGridStep_deg, ...
    'Moving point-target pointcloud estimates differ beyond one processing bin.');

disp('MathWorks moving point-target TDM-MIMO source validation passed.')
