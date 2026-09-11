%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_mathworks_ideal_point_target_source.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Validate an ideal MathWorks waveform-level point
%                       target source against the local analytic source
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% success criteria
% This checkpoint validates clean static point-target signal generation. It
% does not validate TI hardware fidelity, Doppler compensation, clutter,
% multipath, or tracking.
%
% 1. Both sources must return one ADC vector with nSample entries.
% 2. Their dominant range FFT bins must match for each tested range.
% 3. After removing the irrelevant complex gain difference, waveform NMSE
%    must be below -18 dB for each tested range.
% 4. For a TI xWR1642-style 2Tx4Rx TDM cube, both sources must keep the
%    same data dimensions, range FFT bins and virtual-array phase response
%    at broadside and at a non-zero azimuth angle.
% 5. For a TI xWR1843-style 3Tx4Rx TDM cube, both sources must also agree
%    for a target with non-zero azimuth and elevation.

%% toolbox path
toolboxRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(toolboxRoot, 'startup.m'));

%% define common radar parameters
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 3.04;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 1;
sensorParams.TxNum = 1;
sensorParams.RxNum = 1;

targetParams.amplitude = 1;
targetParams.velocity = 0;
targetParams.azimuth = 0;
targetParams.elevation = 0;

testRange_m = [3, 7, 12];
alignedNmseThreshold_dB = -18;

% radarTransceiver simulates the wideband chirp before dechirping. A high
% internal sampling rate is required; otherwise fractional-delay error can
% move the range peak by one ADC bin in this short-range experiment.
sourceOptions.InternalOversampling = 128;

%% compare local analytic source and MathWorks waveform-level source
results = table('Size', [length(testRange_m), 5], ...
    'VariableTypes', {'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'TrueRange_m', 'LocalPeakBin', 'MathWorksPeakBin', ...
    'PeakBinError', 'AlignedNmse_dB'});

for rangeIdex = 1:length(testRange_m)
    targetParams.range = testRange_m(rangeIdex);
    radarParams = RadarParameterGenerate(sensorParams, targetParams);

    localData = RadarCubeGenerate(targetParams, radarParams);
    [mathWorksData, sourceInfo] = RadarCubeGenerateMathWorksIdeal( ...
        targetParams, radarParams, sourceOptions);

    assert(numel(localData) == radarParams.nSample);
    assert(numel(mathWorksData) == radarParams.nSample);

    localVector = localData(:);
    mathWorksVector = mathWorksData(:);
    [~, localPeakBin] = max(abs(fft(localVector)));
    [~, mathWorksPeakBin] = max(abs(fft(mathWorksVector)));

    alpha = (mathWorksVector' * localVector) / ...
        (mathWorksVector' * mathWorksVector + eps);
    alignedNmse = norm(localVector - alpha * mathWorksVector)^2 / ...
        (norm(localVector)^2 + eps);
    alignedNmse_dB = 10 * log10(alignedNmse + eps);

    results.TrueRange_m(rangeIdex) = testRange_m(rangeIdex);
    results.LocalPeakBin(rangeIdex) = localPeakBin;
    results.MathWorksPeakBin(rangeIdex) = mathWorksPeakBin;
    results.PeakBinError(rangeIdex) = abs(localPeakBin - mathWorksPeakBin);
    results.AlignedNmse_dB(rangeIdex) = alignedNmse_dB;
end

disp(results)
fprintf('MathWorks model level       : %s\n', sourceInfo.ModelLevel)
fprintf('Internal oversampling       : %d\n', sourceInfo.InternalOversampling)
fprintf('Internal sample rate        : %.3f MHz\n', sourceInfo.InternalSampleRate_Hz / 1e6)
fprintf('Local bandwidth convention  : %.3f MHz\n', radarParams.B / 1e6)
fprintf('MathWorks sweep bandwidth   : %.3f MHz\n', sourceInfo.SweepBandwidth_Hz / 1e6)

assert(all(results.PeakBinError == 0), ...
    'Range FFT peak bins differ between local and MathWorks point-target sources.');
assert(all(results.AlignedNmse_dB < alignedNmseThreshold_dB), ...
    'Aligned waveform NMSE does not meet the point-target source threshold.');

disp('MathWorks ideal point-target signal source validation passed.')

%% validate TDM-MIMO cube and virtual-array phase contract
sensorParams = rmfield(sensorParams, {'TxNum', 'RxNum'});
sensorParams.Frame = 2;
sensorParams.ArrayType = 'TI_xWRx642';

targetParams.range = 7;
targetParams.velocity = 0;
testAzimuth_deg = [0, 15];

tdmResults = table('Size', [length(testAzimuth_deg), 3], ...
    'VariableTypes', {'double', 'double', 'double'}, ...
    'VariableNames', {'Azimuth_deg', 'MaxPeakBinError', 'AlignedNmse_dB'});

for angleIdex = 1:length(testAzimuth_deg)
    targetParams.azimuth = testAzimuth_deg(angleIdex);
    radarParams = RadarParameterGenerate(sensorParams, targetParams);
    localData = RadarCubeGenerate(targetParams, radarParams);
    mathWorksData = RadarCubeGenerateMathWorksIdeal(targetParams, radarParams, sourceOptions);

    assert(isequal(size(localData), size(mathWorksData)), ...
        'TDM-MIMO output size differs between local and MathWorks sources.');

    [~, localPeakBin] = max(abs(fft(localData, [], 1)), [], 1);
    [~, mathWorksPeakBin] = max(abs(fft(mathWorksData, [], 1)), [], 1);
    maxPeakBinError = max(abs(localPeakBin(:) - mathWorksPeakBin(:)));

    alpha = (mathWorksData(:)' * localData(:)) / ...
        (mathWorksData(:)' * mathWorksData(:) + eps);
    alignedNmse = norm(localData(:) - alpha * mathWorksData(:))^2 / ...
        (norm(localData(:))^2 + eps);
    alignedNmse_dB = 10 * log10(alignedNmse + eps);

    tdmResults.Azimuth_deg(angleIdex) = targetParams.azimuth;
    tdmResults.MaxPeakBinError(angleIdex) = maxPeakBinError;
    tdmResults.AlignedNmse_dB(angleIdex) = alignedNmse_dB;
end

disp(tdmResults)
assert(all(tdmResults.MaxPeakBinError == 0), ...
    'TDM-MIMO range FFT peak bins differ between local and MathWorks sources.');
assert(all(tdmResults.AlignedNmse_dB < alignedNmseThreshold_dB), ...
    'TDM-MIMO array-phase contract does not meet the aligned NMSE threshold.');

disp('MathWorks TDM-MIMO point-target cube validation passed.')

%% validate TI xWR1843-style 3Tx4Rx cube with elevation content
sensorParams.ArrayType = 'TI_xWRx843';
targetParams.azimuth = 15;
targetParams.elevation = 5;

radarParams = RadarParameterGenerate(sensorParams, targetParams);
localData = RadarCubeGenerate(targetParams, radarParams);
mathWorksData = RadarCubeGenerateMathWorksIdeal(targetParams, radarParams, sourceOptions);

assert(isequal(size(localData), size(mathWorksData)), ...
    'TI_xWRx843 output size differs between local and MathWorks sources.');

[~, localPeakBin] = max(abs(fft(localData, [], 1)), [], 1);
[~, mathWorksPeakBin] = max(abs(fft(mathWorksData, [], 1)), [], 1);
xWR1843PeakBinError = max(abs(localPeakBin(:) - mathWorksPeakBin(:)));

alpha = (mathWorksData(:)' * localData(:)) / ...
    (mathWorksData(:)' * mathWorksData(:) + eps);
alignedNmse = norm(localData(:) - alpha * mathWorksData(:))^2 / ...
    (norm(localData(:))^2 + eps);
xWR1843AlignedNmse_dB = 10 * log10(alignedNmse + eps);

fprintf('TI_xWRx843 output size      : %s\n', mat2str(size(mathWorksData)))
fprintf('TI_xWRx843 peak bin error   : %d\n', xWR1843PeakBinError)
fprintf('TI_xWRx843 aligned NMSE     : %.3f dB\n', xWR1843AlignedNmse_dB)

assert(xWR1843PeakBinError == 0, ...
    'TI_xWRx843 range FFT peak bins differ between local and MathWorks sources.');
assert(xWR1843AlignedNmse_dB < alignedNmseThreshold_dB, ...
    'TI_xWRx843 array-phase contract does not meet the aligned NMSE threshold.');

disp('MathWorks TI_xWRx843 point-target cube validation passed.')
