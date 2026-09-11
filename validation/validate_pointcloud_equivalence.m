function results = validate_pointcloud_equivalence(maxRealFrames)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_pointcloud_equivalence.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Validate pointcloud toolbox against reference projects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1
    maxRealFrames = 5;
end

rootDir = fileparts(fileparts(mfilename('fullpath')));
oldFolder = pwd;
cleanupObj = onCleanup(@() cd(oldFolder));
set(0, 'DefaultFigureVisible', 'off');

results.tdm = validateTdmMimoProject(rootDir);
results.real = validateRealDataProject(rootDir, maxRealFrames);

disp(' ')
disp('================ Pointcloud Equivalence Summary ================')
printCaseSummary('TDMA-MIMO simulation project', results.tdm)
printCaseSummary('Real-data pointcloud project', results.real)

end

function result = validateTdmMimoProject(rootDir)
refDir = fullfile(rootDir, '0_refer_code', 'TDMA-MIMO 点云生成');
IQFlag = 1;

if ~exist(refDir, 'dir')
    result = makeSkippedResult(refDir, 'reference project folder not found');
    return
end

addReferencePath(refDir)
cd(refDir)

rng(2026)
tarOut = ConfigureTarget;
cfgOut = ConfigureParameter;
cfgOut.Frame = 1;                             % one frame is enough for equivalence
RawData = GenerateAdcData(tarOut, cfgOut, IQFlag, 0, fullfile(tempdir, 'ignore_adc.mat'));
RawData = reshape(RawData, cfgOut.ADCNum, cfgOut.ChirpNum, [], cfgOut.numTx * cfgOut.numRx);
adcData = squeeze(RawData(:, :, 1, :));

cfgDOA = defaultDOAConfig('MUSIC');
refOut = runReferenceFrame(adcData, cfgOut, cfgDOA, IQFlag);

removeReferencePath(refDir)
cd(rootDir)
addToolboxPath(rootDir)

curOut = runToolboxFrame(adcData, cfgOut, cfgDOA, IQFlag);
result = comparePointcloudOutput(refOut, curOut);
result.inputSize = size(adcData);
result.referenceProject = refDir;

end

function result = validateRealDataProject(rootDir, maxRealFrames)
refDir = fullfile(rootDir, '0_refer_code', '点云生成实际数据');
binFile = fullfile(refDir, 'adc_data.bin');

ADC_samples = 256;
frameChirpNum = 64;                           % Same setting as MyPointclouds.m
numTx = 3;
numRx = 4;
IQFlag = 1;

if ~exist(refDir, 'dir')
    result = makeSkippedResult(refDir, 'reference project folder not found');
    return
end
if ~exist(binFile, 'file')
    result = makeSkippedResult(binFile, 'reference bin file not found');
    return
end

addReferencePath(refDir)
cd(refDir)

cfgOut = ConfigureParameter;
cfgDOA = defaultDOAConfig('FFT');
radarDataRef = readDCA1000(binFile, ADC_samples, numRx);

frameNum = min(maxRealFrames, floor(size(radarDataRef, 2) / (ADC_samples * frameChirpNum)));
refFrames = cell(1, frameNum);
refAdcFrames = cell(1, frameNum);
for frameIdex = 1:frameNum
    chirpStart = (frameIdex - 1) * ADC_samples * frameChirpNum + 1;
    chirpEnd = frameIdex * ADC_samples * frameChirpNum;
    datain = radarDataRef(:, chirpStart:chirpEnd).';
    adcData = reshape(datain, [ADC_samples, frameChirpNum, numRx * numTx]);
    refAdcFrames{frameIdex} = adcData;
    refFrames{frameIdex} = runReferenceFrame(adcData, cfgOut, cfgDOA, IQFlag);
end

removeReferencePath(refDir)
cd(rootDir)
addToolboxPath(rootDir)

[radarDataNew, adcCubeAll, readerInfo] = readDCA1000Raw(binFile, ADC_samples, numRx, numTx);
result.readerMaxAbsErr = max(abs(radarDataRef(:) - radarDataNew(:)));
result.readerNmse = calcNmse(radarDataRef, radarDataNew);

frameResults = cell(1, frameNum);
adcFrameMaxAbsErr = zeros(1, frameNum);
for frameIdex = 1:frameNum
    chirpStart = (frameIdex - 1) * frameChirpNum + 1;
    chirpEnd = frameIdex * frameChirpNum;
    adcData = adcCubeAll(:, chirpStart:chirpEnd, :);
    adcFrameMaxAbsErr(frameIdex) = max(abs(refAdcFrames{frameIdex}(:) - adcData(:)));
    curOut = runToolboxFrame(adcData, cfgOut, cfgDOA, IQFlag);
    frameResults{frameIdex} = comparePointcloudOutput(refFrames{frameIdex}, curOut);
end

result.frames = frameResults;
result.frameNum = frameNum;
result.adcFrameMaxAbsErr = adcFrameMaxAbsErr;
result.readerInfo = readerInfo;
result.referenceProject = refDir;
result.binFile = binFile;
result.frameChirpNum = frameChirpNum;

end

function out = runReferenceFrame(adcData, cfgOut, cfgDOA, IQFlag)
c = physconst('LightSpeed');
lambda = c / cfgOut.fc;
ChirpNum = cfgOut.ChirpNum;
numTx = cfgOut.numTx;
numRx = cfgOut.numRx;
arrNum = numTx * numRx;
virtual_array = cfgOut.virtual_array;
range_res = c / (2 * cfgOut.validB);
TF = cfgOut.Tc * (numTx * ChirpNum);
doppler_res = lambda / (2 * TF);

fftOut = rdFFT(adcData, IQFlag);
rangeFFTOut = fftOut.rangeFFT;
dopplerFFTOut = fftOut.dopplerFFT;
accumulateRD = incoherent_accumulation(dopplerFFTOut);
cfarOut = CFAR_2D(accumulateRD, cfgDOA.Pfa, cfgDOA.TestCells, cfgDOA.GuardCells);

[range_idx, doppler_idx] = find(cfarOut.cfarMap);
cfar_out_idx = [range_idx, doppler_idx];
[rd_peak_list, rd_peak] = peakFocus(db(accumulateRD), cfar_out_idx);

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
    com_dopplerFFTOut = compensate_doppler(doaInput, cfgOut, rd_peak_list(2, :), speedVal, rangeVal);

    for peak_idx = 1:size(rd_peak_list, 2)
        snrVal = mag2db(cfarOut.snrOut(rd_peak_list(1, peak_idx), rd_peak_list(2, peak_idx)));
        tarData = squeeze(com_dopplerFFTOut(peak_idx, :, :));
        sig_space = zeros(max(virtual_array.azi_arr) + 1, max(virtual_array.ele_arr) + 1);
        for trx_id = 1:size(cfgOut.sigIdx, 2)
            sig_space(cfgOut.sigSpaceIdx(1, trx_id), cfgOut.sigSpaceIdx(2, trx_id)) = ...
                tarData(cfgOut.sigIdx(1, trx_id), cfgOut.sigIdx(2, trx_id));
        end

        eleArrData = zeros(cfgDOA.FFTNum, size(sig_space, 2));
        for ele_idx = 1:size(sig_space, 2)
            azidoaOut = referenceAzimuthDOA(sig_space(:, ele_idx), cfgDOA);
            eleArrData(:, ele_idx) = azidoaOut.spectrum(:);
        end

        if ~isfield(azidoaOut, 'angleVal') || isempty(azidoaOut.angleVal)
            continue
        end

        for azi_peak_idx = 1:length(azidoaOut.angleVal)
            tmpEleData = eleArrData(azidoaOut.angleIdx(azi_peak_idx), :).';
            eledoaOut = referenceElevationDOA(tmpEleData, cfgDOA);
            if ~isfield(eledoaOut, 'angleVal') || isempty(eledoaOut.angleVal)
                continue
            end

            targetPerFrame.rangeSet = [targetPerFrame.rangeSet, rangeVal(peak_idx)];
            targetPerFrame.velocitySet = [targetPerFrame.velocitySet, speedVal(peak_idx)];
            targetPerFrame.snrSet = [targetPerFrame.snrSet, snrVal];
            targetPerFrame.azimuthSet = [targetPerFrame.azimuthSet, azidoaOut.angleVal(azi_peak_idx)];
            targetPerFrame.elevationSet = [targetPerFrame.elevationSet, eledoaOut.angleVal(1)];
            targetPerFrame.powerSet = [targetPerFrame.powerSet, powerVal(peak_idx)];
        end
    end
end

out.frame_data = buildFrameData(targetPerFrame);
out.rangeFFTOut = rangeFFTOut;
out.dopplerFFTOut = dopplerFFTOut;
out.accumulateRD = accumulateRD;
out.cfarMap = cfarOut.cfarMap;
out.rd_peak_list = rd_peak_list;
out.targetPerFrame = targetPerFrame;

end

function doaOut = referenceAzimuthDOA(arrData, cfgDOA)
doaOut = referenceDOA(arrData, cfgDOA, cfgDOA.AziMethod, cfgDOA.AzisigNum);
end

function doaOut = referenceElevationDOA(arrData, cfgDOA)
doaOut = referenceDOA(arrData, cfgDOA, cfgDOA.EleMethod, cfgDOA.ElesigNum);
end

function doaOut = referenceDOA(arrData, cfgDOA, doaMethod, sigNum)
doaOut = struct('peakVal', [], 'angleVal', [], 'angleIdx', [], 'spectrum', []);

if strcmp(doaMethod, 'FFT')
    Pout = DOA_FFT(arrData, cfgDOA);
    doaOut.spectrum = Pout;
    if sum(abs(Pout)) == 0
        return
    end

    [peakVal, peakIdx] = findpeaks(abs(Pout));
    if isempty(peakVal)
        return
    end

    [sortVal, sortIdx] = sort(peakVal);
    chooseNum = min(sigNum, length(sortIdx));
    chooseIdx = sortIdx(end - chooseNum + 1:end);
    Idx = peakIdx(chooseIdx);
    ampVal = sortVal(end - chooseNum + 1:end);

    % FFT bin 在空间频率(sinθ)上等间距，与 fftshift 对齐 → asin 映射（与 pointcloud/azimuthDOA 同步）
    sinGrid = ((0:cfgDOA.FFTNum - 1) - floor(cfgDOA.FFTNum / 2)) / cfgDOA.FFTNum * 2;
    angleVal = asind(max(min(sinGrid(Idx), 1), -1));

elseif strcmp(doaMethod, 'MUSIC')
    thetaGrids = cfgDOA.thetaGrids;
    Pout = DOA_MUSIC(arrData, sigNum, thetaGrids);
    doaOut.spectrum = Pout;
    if sum(abs(Pout)) == 0
        return
    end

    [peakVal, peakIdx] = findpeaks(abs(Pout));
    if isempty(peakVal)
        return
    end

    [sortVal, sortIdx] = sort(peakVal);
    chooseNum = min(sigNum, length(sortIdx));
    chooseIdx = sortIdx(end - chooseNum + 1:end);
    Idx = peakIdx(chooseIdx);
    ampVal = sortVal(end - chooseNum + 1:end);
    angleVal = thetaGrids(Idx);
else
    return
end

doaOut.peakVal = ampVal;
doaOut.angleVal = angleVal;
doaOut.angleIdx = Idx;
doaOut.spectrum = Pout;
end

function out = runToolboxFrame(adcData, cfgOut, cfgDOA, IQFlag)
[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, IQFlag);
out.frame_data = frame_data;
out.rangeFFTOut = pointcloudInfo.rangeFFTOut;
out.dopplerFFTOut = pointcloudInfo.dopplerFFTOut;
out.accumulateRD = pointcloudInfo.accumulateRD;
out.cfarMap = pointcloudInfo.cfarOut.cfarMap;
out.rd_peak_list = pointcloudInfo.rd_peak_list;
out.targetPerFrame = pointcloudInfo.targetPerFrame;
end

function frame_data = buildFrameData(targetPerFrame)
XData = targetPerFrame.rangeSet .* cosd(targetPerFrame.elevationSet) .* sind(targetPerFrame.azimuthSet);
YData = targetPerFrame.rangeSet .* cosd(targetPerFrame.elevationSet) .* cosd(targetPerFrame.azimuthSet);
ZData = targetPerFrame.rangeSet .* sind(targetPerFrame.elevationSet);

if isempty(XData)
    frame_data = zeros(0, 8);
else
    frame_data = [XData.', YData.', ZData.', targetPerFrame.rangeSet.', ...
        targetPerFrame.azimuthSet.', targetPerFrame.elevationSet.', ...
        targetPerFrame.velocitySet.', targetPerFrame.snrSet.'];
end
end

function cfgDOA = defaultDOAConfig(eleMethod)
cfgDOA.FFTNum = 180;
cfgDOA.AziMethod = 'FFT';
cfgDOA.EleMethod = eleMethod;
cfgDOA.thetaGrids = linspace(-90, 90, cfgDOA.FFTNum);
cfgDOA.AzisigNum = 1;
cfgDOA.ElesigNum = 1;
cfgDOA.Pfa = 1e-3;
cfgDOA.TestCells = [8, 8];
cfgDOA.GuardCells = [2, 2];
end

function metrics = comparePointcloudOutput(refOut, curOut)
metrics.rangeFFT_nmse = calcNmse(refOut.rangeFFTOut, curOut.rangeFFTOut);
metrics.dopplerFFT_nmse = calcNmse(refOut.dopplerFFTOut, curOut.dopplerFFTOut);
metrics.accumulateRD_nmse = calcNmse(refOut.accumulateRD, curOut.accumulateRD);
metrics.cfarMap_equal = isequal(refOut.cfarMap, curOut.cfarMap);
metrics.rdPeakList_equal = isequal(refOut.rd_peak_list, curOut.rd_peak_list);
metrics.refPointNum = size(refOut.frame_data, 1);
metrics.curPointNum = size(curOut.frame_data, 1);

refFrame = sortFrameData(refOut.frame_data);
curFrame = sortFrameData(curOut.frame_data);
if isequal(size(refFrame), size(curFrame))
    metrics.frameData_maxAbsErr = maxAbsDiff(refFrame, curFrame);
    metrics.frameData_nmse = calcNmse(refFrame, curFrame);
    if ~isempty(refFrame)
        metrics.frameData_colMaxAbsErr = max(abs(refFrame - curFrame), [], 1);
    else
        metrics.frameData_colMaxAbsErr = zeros(1, 8);
    end
else
    metrics.frameData_maxAbsErr = Inf;
    metrics.frameData_nmse = Inf;
    metrics.frameData_colMaxAbsErr = Inf(1, 8);
end

function result = makeSkippedResult(pathName, reason)
result.Skipped = true;
result.Path = pathName;
result.Reason = reason;
end
end

function frameData = sortFrameData(frameData)
if isempty(frameData)
    return
end
frameData = sortrows(frameData, [4, 7, 5, 6]);
end

function value = calcNmse(refData, curData)
den = norm(refData(:))^2;
if den == 0
    value = norm(curData(:))^2;
else
    value = norm(refData(:) - curData(:))^2 / den;
end
end

function value = maxAbsDiff(refData, curData)
if isempty(refData) && isempty(curData)
    value = 0;
else
    value = max(abs(refData(:) - curData(:)));
end
end

function addReferencePath(refDir)
addpath(fullfile(refDir, 'DOA_FUNC'), '-begin')
addpath(refDir, '-begin')
clearPointcloudFunctionCache()
end

function removeReferencePath(refDir)
rmpath(refDir)
if exist(fullfile(refDir, 'DOA_FUNC'), 'dir')
    rmpath(fullfile(refDir, 'DOA_FUNC'))
end
clearPointcloudFunctionCache()
end

function addToolboxPath(rootDir)
addpath(fullfile(rootDir, 'utils'), '-begin')
addpath(fullfile(rootDir, 'doa'), '-begin')
addpath(fullfile(rootDir, 'pointcloud'), '-begin')
clearPointcloudFunctionCache()
end

function clearPointcloudFunctionCache()
clear('ConfigureParameter', 'ConfigureTarget', 'GenerateAdcData', 'GenerateSigIQ', ...
    'GenerateSigI', 'rdFFT', 'rangeFFT', 'dopplerFFT', 'incoherent_accumulation', ...
    'CFAR_2D', 'peakFocus', 'compensate_doppler', 'azimuthDOA', 'elevationDOA', ...
    'DOA_FFT', 'DOA_MUSIC', 'DOA_IAA', 'DOA_ANM', 'DOA_L1SVD', ...
    'readDCA1000', 'readDCA1000Raw', 'GeneratePointCloudFrame')
end

function printCaseSummary(caseName, result)
disp(['--- ', caseName, ' ---'])
if isfield(result, 'Skipped') && result.Skipped
    disp(['skipped: ', result.Reason])
    disp(['path: ', result.Path])
    disp('`0_refer_code/` is local-only and ignored by git.')
    return
end
if isfield(result, 'readerMaxAbsErr')
    disp(['readerMaxAbsErr = ', num2str(result.readerMaxAbsErr, 16)])
    disp(['readerNmse      = ', num2str(result.readerNmse, 16)])
    for frameIdex = 1:result.frameNum
        metrics = result.frames{frameIdex};
        disp(['frame ', num2str(frameIdex), ...
            ': points(ref/current)=', num2str(metrics.refPointNum), '/', num2str(metrics.curPointNum), ...
            ', frameMaxErr=', num2str(metrics.frameData_maxAbsErr, 16), ...
            ', rdPeakEqual=', num2str(metrics.rdPeakList_equal)])
    end
else
    disp(['inputSize       = ', mat2str(result.inputSize)])
    disp(['points(ref/current)=', num2str(result.refPointNum), '/', num2str(result.curPointNum)])
    disp(['rangeFFT_nmse   = ', num2str(result.rangeFFT_nmse, 16)])
    disp(['dopplerFFT_nmse = ', num2str(result.dopplerFFT_nmse, 16)])
    disp(['accumulate_nmse = ', num2str(result.accumulateRD_nmse, 16)])
    disp(['cfarMap_equal   = ', num2str(result.cfarMap_equal)])
    disp(['rdPeak_equal    = ', num2str(result.rdPeakList_equal)])
    disp(['frameMaxErr     = ', num2str(result.frameData_maxAbsErr, 16)])
    disp(['frameColMaxErr  = ', mat2str(result.frameData_colMaxAbsErr, 6)])
end
end
