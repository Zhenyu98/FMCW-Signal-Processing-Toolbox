function [peakVal, peakIdx] = SelectDOAPeaks(spectrum, maxPeakNum, cfgDOA)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Code name           : SelectDOAPeaks.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Select DOA spectrum peaks for point cloud generation
% -------------------------------------------------------------------------
% py_full_variance is adapted from OpenRadar
% mmwave/dsp/angle_estimation.py::peak_search_full_variance.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 3
    cfgDOA = struct();
end

peakVal = [];
peakIdx = [];

if isempty(spectrum) || maxPeakNum <= 0
    return
end

spec = abs(spectrum(:)).';
if sum(spec) == 0
    return
end

peakSearch = getStructText(cfgDOA, 'DOAPeakSearch', 'legacy_findpeaks');

switch lower(peakSearch)
    case {'legacy_findpeaks', 'legacy', 'findpeaks'}
        [peakVal, peakIdx] = legacyFindpeaks(spec, maxPeakNum);
    case {'py_full_variance', 'full_variance', 'py'}
        gamma = getStructNumber(cfgDOA, 'DOAGamma', 1.2);
        sidelobeLevel = getStructNumber(cfgDOA, 'DOASidelobeLevel', 0.251188643150958);
        [peakVal, peakIdx] = pyFullVariancePeaks(spec, maxPeakNum, gamma, sidelobeLevel);
    otherwise
        error('Unknown DOAPeakSearch: %s', peakSearch)
end

end

function [peakVal, peakIdx] = legacyFindpeaks(spec, maxPeakNum)

[peakCandVal, peakCandIdx] = findpeaks(spec);
if isempty(peakCandVal)
    peakVal = [];
    peakIdx = [];
    return
end

[sortVal, sortIdx] = sort(peakCandVal, 'descend');
chooseNum = min(maxPeakNum, length(sortIdx));
peakIdx = peakCandIdx(sortIdx(1:chooseNum));
peakVal = sortVal(1:chooseNum);

end

function [peakVal, peakIdx] = pyFullVariancePeaks(spec, maxPeakNum, gamma, sidelobeLevel)

N = length(spec);
peakThreshold = max(spec) * sidelobeLevel;

runningIndex = 0;                              % zero-based, follows PY code
extendLoc = 0;
initStage = true;
maxVal = 0;
maxLoc = 1;
minVal = Inf;
locateMax = false;

peakCandVal = [];
peakCandIdx = [];

while runningIndex < N + extendLoc
    localIndex = mod(runningIndex, N) + 1;
    currentVal = spec(localIndex);

    if currentVal > maxVal
        maxVal = currentVal;
        maxLoc = localIndex;
    end
    if currentVal < minVal
        minVal = currentVal;
    end

    if locateMax
        if currentVal < maxVal / gamma
            if maxVal >= peakThreshold
                peakCandVal = [peakCandVal, maxVal]; %#ok<AGROW>
                peakCandIdx = [peakCandIdx, maxLoc]; %#ok<AGROW>
            end
            minVal = currentVal;
            locateMax = false;
        end
    else
        if currentVal > minVal * gamma
            locateMax = true;
            maxVal = currentVal;
            maxLoc = localIndex;
            if initStage
                extendLoc = runningIndex;
                initStage = false;
            end
        end
    end

    runningIndex = runningIndex + 1;
end

if isempty(peakCandVal)
    peakVal = [];
    peakIdx = [];
    return
end

[sortVal, sortIdx] = sort(peakCandVal, 'descend');
chooseNum = min(maxPeakNum, length(sortIdx));
peakVal = sortVal(1:chooseNum);
peakIdx = peakCandIdx(sortIdx(1:chooseNum));

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
