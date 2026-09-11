function [frame_data, pointcloudInfo] = GeneratePointCloudFrameRA(adcData, cfgOut, cfgDOA, IQFlag)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : GeneratePointCloudFrameRA.m
% Date & time         : Jun. 2026
% Version             : 1.0
% Purpose             : Generate one-frame point cloud from range-azimuth flow
% -------------------------------------------------------------------------
% frame_data: X, Y, Z, Range, Azimuth, Elevation, Doppler, SNR
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 4
    IQFlag = 1;
end
if nargin < 3
    cfgDOA = struct();
end

cfgDOA = fillRAConfig(cfgDOA);

%% define parameters
c = physconst('LightSpeed');                     % Speed of light (m/s)
fc = cfgOut.fc;                                  % Center frequency (Hz)
lambda = c / fc;                                 % Wave length (m)

ChirpNum = cfgOut.ChirpNum;                      % Number of chirps in one frame
numTx = cfgOut.numTx;                            % Number of Tx antennas
numRx = cfgOut.numRx;                            % Number of Rx antennas

validB = cfgOut.validB;                          % Valid bandwidth
range_res = c / (2 * validB);                    % Range resolution
TF = cfgOut.Tc * (numTx * ChirpNum);             % Frame duration for Doppler
doppler_res = lambda / (2 * TF);                 % Doppler resolution

%% range FFT and range-azimuth map
fftOut = rdFFT(adcData, IQFlag);
rangeFFTOut = fftOut.rangeFFT;
dopplerFFTOut = fftOut.dopplerFFT;

[RAM, angle_axis, ramInfo] = GenerateRangeAzimuthMap(rangeFFTOut, cfgOut, cfgDOA);

%% CFAR on range-azimuth map
Pfa = getFieldOrDefault(cfgDOA, 'Pfa', 1e-3);
TestCells = getFieldOrDefault(cfgDOA, 'TestCells', [8, 8]);
GuardCells = getFieldOrDefault(cfgDOA, 'GuardCells', [2, 2]);
cfarOut = CFAR_2D(RAM, Pfa, TestCells, GuardCells, cfgDOA);

cfarMap = cfarOut.cfarMap;
snrOut = cfarOut.snrOut;

%% peak focus
[range_idx, angle_idx] = find(cfarMap);
cfar_out_idx = [range_idx, angle_idx];
raPeakCfg = cfgDOA;
raPeakCfg.PeakFocusMode = getFieldOrDefault(cfgDOA, 'RAPeakFocusMode', 'legacy_4neighbor');
[ra_peak_list, ra_peak] = peakFocus(mag2db(abs(RAM) + eps), cfar_out_idx, raPeakCfg);
[ra_peak_list, ra_peak, ra_peak_snr_dB] = filterRAPeaks(ra_peak_list, ra_peak, snrOut, cfgDOA);

%% Doppler estimation after RA detection
targetPerFrame.rangeSet = [];
targetPerFrame.velocitySet = [];
targetPerFrame.snrSet = [];
targetPerFrame.azimuthSet = [];
targetPerFrame.elevationSet = [];
targetPerFrame.powerSet = [];

ra_doppler_idx = zeros(1, size(ra_peak_list, 2));
ra_doppler_spec = cell(1, size(ra_peak_list, 2));

for peak_idx = 1:size(ra_peak_list, 2)
    rangeIdx = ra_peak_list(1, peak_idx);
    angleIdx = ra_peak_list(2, peak_idx);

    rangeVal = (rangeIdx - 1) * range_res;
    aziVal = angle_axis(angleIdx);
    snrVal = mag2db(snrOut(rangeIdx, angleIdx));
    powerVal = ra_peak(rangeIdx, angleIdx);

    [speedVal, dopplerIdx, dopplerSpec] = estimateDopplerFromRAPeak( ...
        rangeFFTOut, rangeIdx, angleIdx, aziVal, cfgOut, cfgDOA, doppler_res);

    targetPerFrame.rangeSet = [targetPerFrame.rangeSet, rangeVal]; %#ok<AGROW>
    targetPerFrame.velocitySet = [targetPerFrame.velocitySet, speedVal]; %#ok<AGROW>
    targetPerFrame.snrSet = [targetPerFrame.snrSet, snrVal]; %#ok<AGROW>
    targetPerFrame.azimuthSet = [targetPerFrame.azimuthSet, aziVal]; %#ok<AGROW>
    targetPerFrame.elevationSet = [targetPerFrame.elevationSet, 0]; %#ok<AGROW>
    targetPerFrame.powerSet = [targetPerFrame.powerSet, powerVal]; %#ok<AGROW>

    ra_doppler_idx(peak_idx) = dopplerIdx;
    ra_doppler_spec{peak_idx} = dopplerSpec;
end

%% point cloud generation
XData = targetPerFrame.rangeSet .* cosd(targetPerFrame.elevationSet) .* sind(targetPerFrame.azimuthSet);
YData = targetPerFrame.rangeSet .* cosd(targetPerFrame.elevationSet) .* cosd(targetPerFrame.azimuthSet);
ZData = targetPerFrame.rangeSet .* sind(targetPerFrame.elevationSet);

% frame_data: X, Y, Z, Range, Azimuth, Elevation, Doppler, SNR
if isempty(XData)
    frame_data = zeros(0, 8);
else
    frame_data = [XData.', YData.', ZData.', targetPerFrame.rangeSet.', ...
        targetPerFrame.azimuthSet.', targetPerFrame.elevationSet.', ...
        targetPerFrame.velocitySet.', targetPerFrame.snrSet.'];
end

pointcloudInfo.pipeline = 'RA';
pointcloudInfo.rangeFFTOut = rangeFFTOut;
pointcloudInfo.dopplerFFTOut = dopplerFFTOut;
pointcloudInfo.RAM = RAM;
pointcloudInfo.angle_axis = angle_axis;
pointcloudInfo.ramInfo = ramInfo;
pointcloudInfo.cfarOut = cfarOut;
pointcloudInfo.ra_peak_list = ra_peak_list;
pointcloudInfo.ra_peak = ra_peak;
pointcloudInfo.ra_peak_snr_dB = ra_peak_snr_dB;
pointcloudInfo.ra_doppler_idx = ra_doppler_idx;
pointcloudInfo.ra_doppler_spec = ra_doppler_spec;
pointcloudInfo.targetPerFrame = targetPerFrame;
pointcloudInfo.range_res = range_res;
pointcloudInfo.doppler_res = doppler_res;

end

function [speedVal, dopplerIdx, dopplerSpec] = estimateDopplerFromRAPeak( ...
    rangeFFTOut, rangeIdx, angleIdx, angleVal, cfgOut, cfgDOA, doppler_res)

arrData = squeeze(rangeFFTOut(rangeIdx, :, :));          % ChirpNum x ArrayNum
if isvector(arrData)
    arrData = reshape(arrData, [], cfgOut.numRx * cfgOut.numTx);
end

aziData = mapToAzimuthSnapshots(arrData, cfgOut);        % ChirpNum x AziArrayNum
ChirpNum = size(aziData, 1);

aziMethod = getStructText(cfgDOA, 'AziMethod', 'FFT');
if strcmpi(aziMethod, 'FFT')
    winAzi = hanning(size(aziData, 2)).';
    angleFFT = fftshift(fft(aziData .* winAzi, cfgDOA.FFTNum, 2), 2) * 2 / cfgDOA.FFTNum;
    slowTimeSig = angleFFT(:, angleIdx);
else
    aziPos = 0:size(aziData, 2) - 1;
    steeringVec = exp(1j * 2 * pi * cfgOut.arrdx * aziPos(:) * sind(angleVal));
    slowTimeSig = aziData * conj(steeringVec) / max(length(steeringVec), 1);
end

if ChirpNum <= 1
    dopplerIdx = 1;
    dopplerSpec = slowTimeSig(:);
    speedVal = 0;
    return
end

dopplerWin = hanning(ChirpNum);
dopplerSpec = fftshift(fft(slowTimeSig(:) .* dopplerWin, [], 1), 1) * 2 * 2 / ChirpNum;
[~, dopplerIdx] = max(abs(dopplerSpec));
speedVal = (dopplerIdx - ChirpNum / 2 - 1) * doppler_res;

end

function aziData = mapToAzimuthSnapshots(arrData, cfgOut)

ChirpNum = size(arrData, 1);
sig = reshape(arrData, ChirpNum, cfgOut.numRx, cfgOut.numTx);
virtual_array = cfgOut.virtual_array;

sig_space = zeros(ChirpNum, max(virtual_array.azi_arr) + 1, max(virtual_array.ele_arr) + 1);
for trx_id = 1:size(cfgOut.sigIdx, 2)
    sig_space(:, cfgOut.sigSpaceIdx(1, trx_id), cfgOut.sigSpaceIdx(2, trx_id)) = ...
        sig(:, cfgOut.sigIdx(1, trx_id), cfgOut.sigIdx(2, trx_id));
end

aziData = squeeze(sig_space(:, :, 1));
if isvector(aziData)
    aziData = reshape(aziData, ChirpNum, []);
end

end

function [ra_peak_list, ra_peak, ra_peak_snr_dB] = filterRAPeaks(ra_peak_list, ra_peak, snrOut, cfgDOA)

ra_peak_snr_dB = zeros(1, size(ra_peak_list, 2));
for peakIdex = 1:size(ra_peak_list, 2)
    rangeIdx = ra_peak_list(1, peakIdex);
    angleIdx = ra_peak_list(2, peakIdex);
    ra_peak_snr_dB(peakIdex) = mag2db(snrOut(rangeIdx, angleIdx));
end

if isempty(ra_peak_list)
    return
end

keepIdx = true(1, size(ra_peak_list, 2));

MinPeakSNR_dB = getFieldOrDefault(cfgDOA, 'MinPeakSNR_dB', []);
if ~isempty(MinPeakSNR_dB)
    keepIdx = keepIdx & (ra_peak_snr_dB >= MinPeakSNR_dB);
end

PeakRelativeThreshold_dB = getFieldOrDefault(cfgDOA, 'PeakRelativeThreshold_dB', []);
if ~isempty(PeakRelativeThreshold_dB)
    keepIdx = keepIdx & (ra_peak_snr_dB >= max(ra_peak_snr_dB) - PeakRelativeThreshold_dB);
end

ra_peak_list = ra_peak_list(:, keepIdx);
ra_peak_snr_dB = ra_peak_snr_dB(keepIdx);

MaxDetections = getFieldOrDefault(cfgDOA, 'MaxDetections', []);
if ~isempty(MaxDetections) && size(ra_peak_list, 2) > MaxDetections
    [~, sortIdx] = sort(ra_peak_snr_dB, 'descend');
    chooseIdx = sortIdx(1:MaxDetections);
    ra_peak_list = ra_peak_list(:, chooseIdx);
    ra_peak_snr_dB = ra_peak_snr_dB(chooseIdx);
end

new_ra_peak = zeros(size(ra_peak));
for peakIdex = 1:size(ra_peak_list, 2)
    rangeIdx = ra_peak_list(1, peakIdex);
    angleIdx = ra_peak_list(2, peakIdex);
    new_ra_peak(rangeIdx, angleIdx) = ra_peak(rangeIdx, angleIdx);
end
ra_peak = new_ra_peak;

end

function cfgDOA = fillRAConfig(cfgDOA)

if ~isfield(cfgDOA, 'AziMethod') || isempty(cfgDOA.AziMethod)
    cfgDOA.AziMethod = 'FFT';
end
if ~isfield(cfgDOA, 'AzisigNum') || isempty(cfgDOA.AzisigNum)
    cfgDOA.AzisigNum = 1;
end
if ~isfield(cfgDOA, 'FFTNum') || isempty(cfgDOA.FFTNum)
    cfgDOA.FFTNum = 180;
end
if ~isfield(cfgDOA, 'thetaGrids') || isempty(cfgDOA.thetaGrids)
    cfgDOA.thetaGrids = linspace(-90, 90, cfgDOA.FFTNum);
end

end

function value = getFieldOrDefault(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName)
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end

function value = getStructText(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = char(string(s.(fieldName)));
else
    value = defaultValue;
end
end
