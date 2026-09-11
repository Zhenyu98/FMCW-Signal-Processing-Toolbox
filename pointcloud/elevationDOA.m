function [doaOut] = elevationDOA(arrData, cfgDOA)
%% elevation DOA/AOA estimation
% arrData: elevation array data
% cfgDOA: DOA configuration

ensureDOAPath()

doaMethod = cfgDOA.EleMethod;
doaOut = struct('peakVal', [], 'angleVal', [], 'angleIdx', [], 'spectrum', []);

if strcmp(doaMethod, 'FFT')
    P = cfgDOA.ElesigNum;
    [Pout] = DOA_FFT(arrData, cfgDOA);
    doaOut.spectrum = Pout;

    if sum(abs(Pout)) == 0
        return
    end

    [ampVal, Idx] = SelectDOAPeaks(Pout, P, cfgDOA);
    if isempty(ampVal)
        return
    end

    % FFT bin 在空间频率(sinθ)上等间距，与 fftshift 对齐 → asin 映射 (d = λ/2，*2 = 1/(d/λ))
    sinGrid = ((0:cfgDOA.FFTNum - 1) - floor(cfgDOA.FFTNum / 2)) / cfgDOA.FFTNum * 2;
    angleVal = asind(max(min(sinGrid(Idx), 1), -1));

    doaOut.peakVal = ampVal;
    doaOut.angleVal = angleVal;
    doaOut.angleIdx = Idx;

elseif strcmp(doaMethod, 'MUSIC')
    P = cfgDOA.ElesigNum;
    thetaGrids = cfgDOA.thetaGrids;
    [Pout] = DOA_MUSIC(arrData, P, thetaGrids);
    doaOut.spectrum = Pout;

    if sum(abs(Pout)) == 0
        return
    end

    [ampVal, Idx] = SelectDOAPeaks(Pout, P, cfgDOA);
    if isempty(ampVal)
        return
    end

    angleVal = thetaGrids(Idx);

    doaOut.peakVal = ampVal;
    doaOut.angleVal = angleVal;
    doaOut.angleIdx = Idx;
end

end

function ensureDOAPath()

persistent isReady
if ~isempty(isReady) && isReady
    return
end

currentFolder = fileparts(mfilename('fullpath'));
doaFolder = fullfile(currentFolder, '..', 'doa');
pathCell = strsplit(path, pathsep);
if ~any(strcmpi(pathCell, doaFolder))
    addpath(doaFolder, '-end')
end
isReady = true;

end
