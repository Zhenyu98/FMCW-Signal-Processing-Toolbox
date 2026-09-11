function [RAM, angle_axis, ramInfo] = GenerateRangeAzimuthMap(rangeFFTOut, cfgOut, cfgDOA)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : GenerateRangeAzimuthMap.m
% Date & time         : Jun. 2026
% Version             : 1.0
% Purpose             : Generate range-azimuth map from range FFT output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 3
    cfgDOA = struct();
end
cfgDOA = fillRAMConfig(cfgDOA);

%% define parameters
rangeNum = size(rangeFFTOut, 1);                 % Number of range bins
ChirpNum = size(rangeFFTOut, 2);                 % Number of chirps
angle_axis = getAngleAxis(cfgDOA);
virtual_array = cfgOut.virtual_array;            % Virtual array structure

RAM = zeros(rangeNum, length(angle_axis));

%% range-azimuth spectrum
for rangeIdx = 1:rangeNum
    arrData = squeeze(rangeFFTOut(rangeIdx, :, :));   % ChirpNum x ArrayNum
    if isvector(arrData)
        arrData = reshape(arrData, ChirpNum, cfgOut.numRx * cfgOut.numTx);
    end

    sig = reshape(arrData, ChirpNum, cfgOut.numRx, cfgOut.numTx);
    sig_space = zeros(ChirpNum, max(virtual_array.azi_arr) + 1, max(virtual_array.ele_arr) + 1);
    for trx_id = 1:size(cfgOut.sigIdx, 2)
        sig_space(:, cfgOut.sigSpaceIdx(1, trx_id), cfgOut.sigSpaceIdx(2, trx_id)) = ...
            sig(:, cfgOut.sigIdx(1, trx_id), cfgOut.sigIdx(2, trx_id));
    end

    aziData = squeeze(sig_space(:, :, 1));       % ChirpNum x AziArrayNum
    if isvector(aziData)
        aziData = reshape(aziData, ChirpNum, []);
    end

    RAM(rangeIdx, :) = estimateRASpectrum(aziData, cfgDOA, length(angle_axis));
end

ramInfo.method = cfgDOA.AziMethod;
ramInfo.angle_axis = angle_axis;
ramInfo.ChirpNum = ChirpNum;
ramInfo.rangeNum = rangeNum;

end

function spectrumRow = estimateRASpectrum(aziData, cfgDOA, angleNum)

aziMethod = getStructText(cfgDOA, 'AziMethod', 'FFT');
if strcmpi(aziMethod, 'FFT')
    winAzi = hanning(size(aziData, 2)).';
    angleFFT = fftshift(fft(aziData .* winAzi, cfgDOA.FFTNum, 2), 2) * 2 / cfgDOA.FFTNum;
    spectrumRow = sum(abs(angleFFT), 1) / sqrt(size(angleFFT, 1));
    return
end

doaOut = azimuthDOA(aziData.', cfgDOA);
if isempty(doaOut.spectrum)
    spectrumRow = zeros(1, angleNum);
    return
end

spec = abs(doaOut.spectrum);
if isvector(spec)
    spectrumRow = spec(:).';
elseif size(spec, 1) == angleNum
    spectrumRow = sum(spec, 2).' / sqrt(size(spec, 2));
elseif size(spec, 2) == angleNum
    spectrumRow = sum(spec, 1) / sqrt(size(spec, 1));
else
    error('DOA spectrum size does not match the RA angle axis.')
end

end

function angle_axis = getAngleAxis(cfgDOA)

aziMethod = getStructText(cfgDOA, 'AziMethod', 'FFT');
if strcmpi(aziMethod, 'FFT')
    FFTNum = cfgDOA.FFTNum;
    sinGrid = ((0:FFTNum - 1) - floor(FFTNum / 2)) / FFTNum * 2;
    angle_axis = asind(max(min(sinGrid, 1), -1));
else
    angle_axis = cfgDOA.thetaGrids(:).';
end

end

function cfgDOA = fillRAMConfig(cfgDOA)

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

function value = getStructText(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = char(string(s.(fieldName)));
else
    value = defaultValue;
end
end
