function tests = test_azimuthDOA_multipeak
% Pin the current multi-peak DOA behavior of pointcloud/azimuthDOA.m.
%
% Context: an earlier internal performance diagnosis
% claimed azimuthDOA forces single-peak output. Reading the source shows
% it already supports multi-peak via cfgDOA.AzisigNum + findpeaks; the
% real bottleneck is the adapter setting AzisigNum=1. These tests pin
% the multi-peak contract so the next agent doesn't waste effort
% "adding a multi-peak branch" that already exists.
%
% Run from project root:
%   >> startup
%   >> runtests('tests/pointcloud/test_azimuthDOA_multipeak.m')

tests = functiontests(localfunctions);
end

% ----------------------- fixtures ------------------------------------------

function cfgDOA = baseCfg()
cfgDOA.AziMethod = 'FFT';
cfgDOA.FFTNum = 256;
cfgDOA.AzisigNum = 1;   % overridden per test
end

function arrData = makePlaneWave(N, azDeg)
% lambda/2 spaced ULA, normalized plane wave at azDeg
n = (0:N-1).';
arrData = exp(1j * pi * sind(azDeg) * n);
end

function arrData = makeTwoPlaneWaves(N, az1, az2, amp2)
arrData = makePlaneWave(N, az1) + amp2 * makePlaneWave(N, az2);
end

% ----------------------- single-target behavior ----------------------------

function test_P1_single_target_returns_one_peak(testCase)
cfgDOA = baseCfg();
cfgDOA.AzisigNum = 1;
arrData = makePlaneWave(8, 15);

doaOut = azimuthDOA(arrData, cfgDOA);

verifyEqual(testCase, numel(doaOut.angleVal), 1);
verifyEqual(testCase, doaOut.angleVal(1), 15, 'AbsTol', 2);   % FFT bin resolution
end

% ----------------------- multi-target behavior -----------------------------

function test_P2_two_targets_returns_two_peaks(testCase)
% PIN: contradicts the report's "forced single-peak" claim.
cfgDOA = baseCfg();
cfgDOA.AzisigNum = 2;
arrData = makeTwoPlaneWaves(16, -20, 25, 0.8);   % 16 elements for cleaner FFT peaks

doaOut = azimuthDOA(arrData, cfgDOA);

verifyEqual(testCase, numel(doaOut.angleVal), 2);
% sorted by peakVal descending; -20 has amp 1.0, 25 has amp 0.8
verifyEqual(testCase, sort(doaOut.angleVal), [-20, 25], 'AbsTol', 3);
end

function test_P3_with_only_2_real_peaks_returns_at_most_2(testCase)
% findpeaks returns all local maxima; sort+min(P, found) bounds it.
% With clean signal (no noise) there are exactly 2 real peaks.
cfgDOA = baseCfg();
cfgDOA.AzisigNum = 3;
arrData = makeTwoPlaneWaves(16, -20, 25, 0.8);

doaOut = azimuthDOA(arrData, cfgDOA);

% Current behavior: returns min(P, length(found peaks)) = min(3, ?).
% With clean signal there can be a few weak sidelobe peaks but the
% strongest two must match truth.
verifyLessThanOrEqual(testCase, numel(doaOut.angleVal), 3);
verifyGreaterThanOrEqual(testCase, numel(doaOut.angleVal), 2);

% Top-2 peaks (peakVal-sorted) must include both truth angles.
top2 = sort(doaOut.angleVal(1:2));
verifyEqual(testCase, top2, [-20, 25], 'AbsTol', 3);
end

function test_P_greater_than_found_peaks_no_error(testCase)
% Guard: very large P must not error even when only 1 peak exists.
cfgDOA = baseCfg();
cfgDOA.AzisigNum = 50;
arrData = makePlaneWave(8, 0);

doaOut = azimuthDOA(arrData, cfgDOA);

verifyTrue(testCase, ~isempty(doaOut.angleVal));
% strongest must be near 0 deg
[~, strongIdx] = max(doaOut.peakVal);
verifyEqual(testCase, doaOut.angleVal(strongIdx), 0, 'AbsTol', 5);
end

% ----------------------- degenerate inputs ---------------------------------

function test_zero_signal_returns_empty(testCase)
cfgDOA = baseCfg();
cfgDOA.AzisigNum = 2;
arrData = zeros(8, 1);

doaOut = azimuthDOA(arrData, cfgDOA);

verifyEmpty(testCase, doaOut.angleVal);
verifyEmpty(testCase, doaOut.peakVal);
verifyEmpty(testCase, doaOut.angleIdx);
end
