function [cfarOut] = CFAR_2D(RDM, Pfa, TestCells, GuardCells, cfarParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : CFAR_2D.m
% Date & time         : May. 2026
% Version             : 1.1
% Purpose             : 2D CFAR detection for range-Doppler map
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 5
    cfarParams = struct();
end

cfarMethod = getStructText(cfarParams, 'CFARMethod', 'phased_soca');

switch lower(cfarMethod)
    case {'phased_soca', 'soca', 'legacy'}
        cfarOut = phasedSOCA(RDM, Pfa, TestCells, GuardCells);
    case {'separable_ca', 'ca_separable', 'fast_ca'}
        cfarOut = separableCA(RDM, TestCells, GuardCells, cfarParams);
    otherwise
        error('Unknown CFARMethod: %s', cfarMethod)
end

end

function cfarOut = phasedSOCA(RDM, Pfa, TestCells, GuardCells)

detector = phased.CFARDetector2D('TrainingBandSize', TestCells, ...
    'ThresholdFactor', 'Auto', 'GuardBandSize', GuardCells, ...
    'ProbabilityFalseAlarm', Pfa, 'Method', 'SOCA', ...
    'ThresholdOutputPort', true, 'NoisePowerOutputPort', true);

N_x = size(RDM, 1);
N_y = size(RDM, 2);
Ngr = detector.GuardBandSize(1);
Ngc = detector.GuardBandSize(2);
Ntr = detector.TrainingBandSize(1);
Ntc = detector.TrainingBandSize(2);

cutidx = zeros(2, N_x * N_y);
cutIdex = 1;
colstart = Ntc + Ngc + 1;
colend = N_y + Ntc + Ngc;
rowstart = Ntr + Ngr + 1;
rowend = N_x + Ntr + Ngr;
for m = colstart:colend
    for n = rowstart:rowend
        cutidx(:, cutIdex) = [n; m];
        cutIdex = cutIdex + 1;
    end
end

rd_map_padding = repmat(RDM, 3, 3);
chosen_rd_map = rd_map_padding( ...
    N_x + 1 - Ntr - Ngr : 2 * N_x + Ntr + Ngr, ...
    N_y + 1 - Ntc - Ngc : 2 * N_y + Ntc + Ngc);

[dets, ~, noise] = detector(chosen_rd_map, cutidx);

cfar_out = false(size(chosen_rd_map));
noise_out = zeros(size(chosen_rd_map));
snr_out = zeros(size(chosen_rd_map));

detIdx = find(dets);
if ~isempty(detIdx)
    linIdx = sub2ind(size(chosen_rd_map), cutidx(1, detIdx), cutidx(2, detIdx));
    cfar_out(linIdx) = true;
    noise_out(linIdx) = noise(detIdx);
    snr_out(linIdx) = chosen_rd_map(linIdx);
end

rowIdx = Ntr + Ngr + 1 : Ntr + Ngr + N_x;
colIdx = Ntc + Ngc + 1 : Ntc + Ngc + N_y;

cfarOut.cfarMap = cfar_out(rowIdx, colIdx);
cfarOut.snrOut = snr_out(rowIdx, colIdx);
cfarOut.noiseOut = noise_out(rowIdx, colIdx);
cfarOut.snrOut = cfarOut.snrOut ./ (eps + cfarOut.noiseOut);
cfarOut.thresholdOut = [];
cfarOut.method = 'phased_soca';

end

function cfarOut = separableCA(RDM, TestCells, GuardCells, cfarParams)

noiseR = max(round(TestCells(1)), 1);
noiseD = max(round(TestCells(2)), 1);
guardR = max(round(GuardCells(1)), 0);
guardD = max(round(GuardCells(2)), 0);
lBound = getStructNumber(cfarParams, 'L_bound', 1.5);
lBoundRange = getStructNumber(cfarParams, 'L_bound_Range', lBound);
lBoundDoppler = getStructNumber(cfarParams, 'L_bound_Doppler', lBound);

noiseRMap = circularMean1D(RDM, guardR, noiseR, 1);
noiseDMap = circularMean1D(RDM, guardD, noiseD, 2);

thresholdR = noiseRMap + lBoundRange;
thresholdD = noiseDMap + lBoundDoppler;
cfarMap = (RDM > thresholdR) & (RDM > thresholdD);

% AND gate uses the larger directional noise estimate as SNR reference.
noiseOut = max(noiseRMap, noiseDMap);
snrOut = zeros(size(RDM));
snrOut(cfarMap) = RDM(cfarMap) ./ (eps + noiseOut(cfarMap));

cfarOut.cfarMap = cfarMap;
cfarOut.snrOut = snrOut;
cfarOut.noiseOut = noiseOut;
cfarOut.thresholdOut = cat(3, thresholdR, thresholdD);
cfarOut.noiseRMap = noiseRMap;
cfarOut.noiseDMap = noiseDMap;
cfarOut.method = 'separable_ca';
cfarOut.L_bound = lBound;
cfarOut.L_bound_Range = lBoundRange;
cfarOut.L_bound_Doppler = lBoundDoppler;

end

function noiseMap = circularMean1D(RDM, guardLen, noiseLen, dimIdex)

noiseMap = zeros(size(RDM));
offsets = [-guardLen-noiseLen : -guardLen-1, guardLen+1 : guardLen+noiseLen];

if dimIdex == 1
    rowNum = size(RDM, 1);
    rowBase = 1:rowNum;
    for offset = offsets
        rowIdx = mod(rowBase + offset - 1, rowNum) + 1;
        noiseMap = noiseMap + RDM(rowIdx, :);
    end
else
    colNum = size(RDM, 2);
    colBase = 1:colNum;
    for offset = offsets
        colIdx = mod(colBase + offset - 1, colNum) + 1;
        noiseMap = noiseMap + RDM(:, colIdx);
    end
end

noiseMap = noiseMap / max(length(offsets), 1);

end

function value = getStructText(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = char(string(s.(fieldName)));
else
    value = defaultValue;
end
end

function value = getStructNumber(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = double(s.(fieldName));
else
    value = defaultValue;
end
end
