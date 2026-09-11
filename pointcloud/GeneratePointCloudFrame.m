function [frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, IQFlag)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : GeneratePointCloudFrame.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Generate one-frame point cloud from ADC data
% -------------------------------------------------------------------------
% frame_data: X, Y, Z, Range, Azimuth, Elevation, Doppler, SNR
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 4
    IQFlag = 1;
end
if nargin < 3
    cfgDOA = struct();
end

pipelineMode = getFieldOrDefault(cfgDOA, 'PointCloudPipeline', 'RD');
if strcmpi(char(string(pipelineMode)), 'RA')
    [frame_data, pointcloudInfo] = GeneratePointCloudFrameRA(adcData, cfgOut, cfgDOA, IQFlag);
    return
end

%% define parameters
c = physconst('LightSpeed');                     % Speed of light (m/s)
fc = cfgOut.fc;                                  % Center frequency (Hz)
lambda = c / fc;                                 % Wave length (m)

ChirpNum = cfgOut.ChirpNum;                      % Number of chirps in one frame
numTx = cfgOut.numTx;                            % Number of Tx antennas
numRx = cfgOut.numRx;                            % Number of Rx antennas
arrNum = numTx * numRx;                          % Number of virtual antennas

virtual_array = cfgOut.virtual_array;            % Virtual array structure
validB = cfgOut.validB;                          % Valid bandwidth
range_res = c / (2 * validB);                    % Range resolution
TF = cfgOut.Tc * (numTx * ChirpNum);             % Frame duration for Doppler
doppler_res = lambda / (2 * TF);                 % Doppler resolution

%% range FFT and doppler FFT
fftOut = rdFFT(adcData, IQFlag);
rangeFFTOut = fftOut.rangeFFT;
dopplerFFTOut = fftOut.dopplerFFT;

%% incoherent accumulation and CFAR
RDM = dopplerFFTOut;
accumulateRD = incoherent_accumulation(RDM);

Pfa = getFieldOrDefault(cfgDOA, 'Pfa', 1e-3);
TestCells = getFieldOrDefault(cfgDOA, 'TestCells', [8, 8]);
GuardCells = getFieldOrDefault(cfgDOA, 'GuardCells', [2, 2]);
[cfarOut] = CFAR_2D(accumulateRD, Pfa, TestCells, GuardCells, cfgDOA);

cfarMap = cfarOut.cfarMap;
snrOut = cfarOut.snrOut;

%% peak focus
[range_idx, doppler_idx] = find(cfarMap);
cfar_out_idx = [range_idx, doppler_idx];
[rd_peak_list, rd_peak] = peakFocus(db(accumulateRD), cfar_out_idx, cfgDOA);
[rd_peak_list, rd_peak, rd_peak_snr_dB] = filterRDPeaks(rd_peak_list, rd_peak, snrOut, cfgDOA);

%% DOA/AOA estimation
targetPerFrame.rangeSet = [];
targetPerFrame.velocitySet = [];
targetPerFrame.snrSet = [];
targetPerFrame.azimuthSet = [];
targetPerFrame.elevationSet = [];
targetPerFrame.powerSet = [];

if ~isempty(rd_peak_list)
    rangeVal = (rd_peak_list(1, :) - 1) * range_res;
    speedVal = (rd_peak_list(2, :) - ChirpNum / 2 - 1) * doppler_res;

    doaInput = zeros(size(rd_peak_list, 2), arrNum);
    powerVal = zeros(1, size(rd_peak_list, 2));
    for tar_idx = 1:size(rd_peak_list, 2)
        doaInput(tar_idx, :) = squeeze(dopplerFFTOut(rd_peak_list(1, tar_idx), rd_peak_list(2, tar_idx), :));
        powerVal(tar_idx) = rd_peak(rd_peak_list(1, tar_idx), rd_peak_list(2, tar_idx));
    end
    doaInput = reshape(doaInput, [], numRx, numTx);

    % 方位角估计前要补偿 TDM-MIMO 的多普勒相位，否则虚拟阵列相位会被速度污染。
    [com_dopplerFFTOut] = compensate_doppler(doaInput, cfgOut, rd_peak_list(2, :), speedVal, rangeVal);

    for peak_idx = 1:size(rd_peak_list, 2)
        snrVal = mag2db(snrOut(rd_peak_list(1, peak_idx), rd_peak_list(2, peak_idx)));
        tarData = squeeze(com_dopplerFFTOut(peak_idx, :, :));

        sig = tarData;
        sig_space = zeros(max(virtual_array.azi_arr) + 1, max(virtual_array.ele_arr) + 1);
        for trx_id = 1:size(cfgOut.sigIdx, 2)
            sig_space(cfgOut.sigSpaceIdx(1, trx_id), cfgOut.sigSpaceIdx(2, trx_id)) = ...
                sig(cfgOut.sigIdx(1, trx_id), cfgOut.sigIdx(2, trx_id));
        end

        eleArrData = zeros(cfgDOA.FFTNum, size(sig_space, 2));
        for ele_idx = 1:size(sig_space, 2)
            tmpAziData = sig_space(:, ele_idx);
            [azidoaOut] = azimuthDOA(tmpAziData, cfgDOA);
            eleArrData(:, ele_idx) = azidoaOut.spectrum(:);
        end

        if ~isfield(azidoaOut, 'angleVal') || isempty(azidoaOut.angleVal)
            continue
        end

        for azi_peak_idx = 1:length(azidoaOut.angleVal)
            tmpEleData = eleArrData(azidoaOut.angleIdx(azi_peak_idx), :).';
            [eledoaOut] = elevationDOA(tmpEleData, cfgDOA);
            if ~isfield(eledoaOut, 'angleVal') || isempty(eledoaOut.angleVal)
                continue
            end

            aziVal = azidoaOut.angleVal(azi_peak_idx);
            eleVal = eledoaOut.angleVal(1);
            targetPerFrame.rangeSet = [targetPerFrame.rangeSet, rangeVal(peak_idx)];
            targetPerFrame.velocitySet = [targetPerFrame.velocitySet, speedVal(peak_idx)];
            targetPerFrame.snrSet = [targetPerFrame.snrSet, snrVal];
            targetPerFrame.azimuthSet = [targetPerFrame.azimuthSet, aziVal];
            targetPerFrame.elevationSet = [targetPerFrame.elevationSet, eleVal];
            targetPerFrame.powerSet = [targetPerFrame.powerSet, powerVal(peak_idx)];
        end
    end
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

pointcloudInfo.rangeFFTOut = rangeFFTOut;
pointcloudInfo.dopplerFFTOut = dopplerFFTOut;
pointcloudInfo.accumulateRD = accumulateRD;
pointcloudInfo.cfarOut = cfarOut;
pointcloudInfo.rd_peak_list = rd_peak_list;
pointcloudInfo.rd_peak = rd_peak;
pointcloudInfo.rd_peak_snr_dB = rd_peak_snr_dB;
pointcloudInfo.targetPerFrame = targetPerFrame;
pointcloudInfo.range_res = range_res;
pointcloudInfo.doppler_res = doppler_res;

end

function [rd_peak_list, rd_peak, rd_peak_snr_dB] = filterRDPeaks(rd_peak_list, rd_peak, snrOut, cfgDOA)
rd_peak_snr_dB = zeros(1, size(rd_peak_list, 2));
for peakIdex = 1:size(rd_peak_list, 2)
    range_idx = rd_peak_list(1, peakIdex);
    doppler_idx = rd_peak_list(2, peakIdex);
    rd_peak_snr_dB(peakIdex) = mag2db(snrOut(range_idx, doppler_idx));
end

if isempty(rd_peak_list)
    return
end

keepIdx = true(1, size(rd_peak_list, 2));

MinPeakSNR_dB = getFieldOrDefault(cfgDOA, 'MinPeakSNR_dB', []);
if ~isempty(MinPeakSNR_dB)
    keepIdx = keepIdx & (rd_peak_snr_dB >= MinPeakSNR_dB);
end

PeakRelativeThreshold_dB = getFieldOrDefault(cfgDOA, 'PeakRelativeThreshold_dB', []);
if ~isempty(PeakRelativeThreshold_dB)
    keepIdx = keepIdx & (rd_peak_snr_dB >= max(rd_peak_snr_dB) - PeakRelativeThreshold_dB);
end

rd_peak_list = rd_peak_list(:, keepIdx);
rd_peak_snr_dB = rd_peak_snr_dB(keepIdx);

MaxDetections = getFieldOrDefault(cfgDOA, 'MaxDetections', []);
if ~isempty(MaxDetections) && size(rd_peak_list, 2) > MaxDetections
    [~, sortIdx] = sort(rd_peak_snr_dB, 'descend');
    chooseIdx = sortIdx(1:MaxDetections);
    rd_peak_list = rd_peak_list(:, chooseIdx);
    rd_peak_snr_dB = rd_peak_snr_dB(chooseIdx);
end

new_rd_peak = zeros(size(rd_peak));
for peakIdex = 1:size(rd_peak_list, 2)
    range_idx = rd_peak_list(1, peakIdex);
    doppler_idx = rd_peak_list(2, peakIdex);
    new_rd_peak(range_idx, doppler_idx) = rd_peak(range_idx, doppler_idx);
end
rd_peak = new_rd_peak;
end

function value = getFieldOrDefault(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName)
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end
