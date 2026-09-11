%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : profile_pointcloud_cfar_diagnosis.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Profile point-cloud CFAR modes on a fixed RDM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% generate fixed range-Doppler map
rng(2026)
RangeBin = 256;
DopplerBin = 64;
RDM = abs(1 + 0.25 * randn(RangeBin, DopplerBin)).^2;

targetBins = [42, 29;
              96, 34;
              160, 41;
              210, 22];
for targetIdex = 1:size(targetBins, 1)
    rangeIdex = targetBins(targetIdex, 1);
    dopplerIdex = targetBins(targetIdex, 2);
    RDM(rangeIdex, dopplerIdex) = RDM(rangeIdex, dopplerIdex) + 80;
    RDM(rangeIdex + (-1:1), dopplerIdex) = RDM(rangeIdex + (-1:1), dopplerIdex) + [10; 25; 10];
    RDM(rangeIdex, dopplerIdex + (-1:1)) = RDM(rangeIdex, dopplerIdex + (-1:1)) + [8, 20, 8];
end

%% define parameters
cfgDOA.Pfa = 1e-3;
cfgDOA.TestCells = [8, 8];
cfgDOA.GuardCells = [2, 2];
cfgDOA.L_bound = 1.5;
RepeatNum = 5;

%% profile separable CA-CFAR
cfgDOA.CFARMethod = 'separable_ca';
[fastTime, fastPointNum, fastPeakNum] = runOneMode(RDM, cfgDOA, RepeatNum);

%% profile legacy phased SOCA-CFAR when available
legacyTime = NaN;
legacyPointNum = NaN;
legacyPeakNum = NaN;
try
    cfgDOA.CFARMethod = 'phased_soca';
    [legacyTime, legacyPointNum, legacyPeakNum] = runOneMode(RDM, cfgDOA, RepeatNum);
catch ME
    disp(['legacy phased_soca skipped: ', ME.message])
end

%% report
disp('===== profile_pointcloud_cfar_diagnosis =====')
disp(['RDM size = ', num2str(RangeBin), ' x ', num2str(DopplerBin)])
disp(['repeat num = ', num2str(RepeatNum)])
disp(['separable_ca mean time = ', num2str(fastTime), ' s'])
disp(['separable_ca CFAR count = ', num2str(fastPointNum), ...
    ', peak count = ', num2str(fastPeakNum)])

if ~isnan(legacyTime)
    disp(['phased_soca mean time = ', num2str(legacyTime), ' s'])
    disp(['phased_soca CFAR count = ', num2str(legacyPointNum), ...
        ', peak count = ', num2str(legacyPeakNum)])
    disp(['speedup phased_soca / separable_ca = ', num2str(legacyTime / fastTime)])
end

if fastTime <= 0 || fastPointNum == 0
    error('CFAR profiling failed: separable_ca output is invalid.')
end

% -------------------------- Subfunctions -------------------------------
function [meanTime, pointNum, peakNum] = runOneMode(RDM, cfgDOA, RepeatNum)

elapsedTime = zeros(RepeatNum, 1);
for testIdex = 1:RepeatNum
    tic
    cfarOut = CFAR_2D(RDM, cfgDOA.Pfa, cfgDOA.TestCells, cfgDOA.GuardCells, cfgDOA);
    elapsedTime(testIdex) = toc;
end

[range_idx, doppler_idx] = find(cfarOut.cfarMap);
cfar_out_idx = [range_idx, doppler_idx];
[rd_peak_list, ~] = peakFocus(10 * log10(RDM + eps), cfar_out_idx);

meanTime = mean(elapsedTime);
pointNum = size(cfar_out_idx, 1);
peakNum = size(rd_peak_list, 2);

end
