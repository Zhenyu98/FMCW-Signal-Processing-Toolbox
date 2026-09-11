function tests = test_elevationDOA_multipeak
% Symmetric pin for pointcloud/elevationDOA.m. Same multi-peak contract
% as test_azimuthDOA_multipeak; this guards against asymmetric edits
% breaking the (az multi-peak, el single-peak) consistency.

tests = functiontests(localfunctions);
end

function cfgDOA = baseCfg()
cfgDOA.EleMethod = 'FFT';
cfgDOA.FFTNum = 256;
cfgDOA.ElesigNum = 1;
end

function arrData = makePlaneWave(N, elDeg)
n = (0:N-1).';
arrData = exp(1j * pi * sind(elDeg) * n);
end

function arrData = makeTwoPlaneWaves(N, e1, e2, amp2)
arrData = makePlaneWave(N, e1) + amp2 * makePlaneWave(N, e2);
end

function test_P1_single_target_returns_one_peak(testCase)
cfgDOA = baseCfg();
cfgDOA.ElesigNum = 1;
arrData = makePlaneWave(8, 10);

doaOut = elevationDOA(arrData, cfgDOA);

verifyEqual(testCase, numel(doaOut.angleVal), 1);
verifyEqual(testCase, doaOut.angleVal(1), 10, 'AbsTol', 2);
end

function test_P2_two_targets_returns_two_peaks(testCase)
cfgDOA = baseCfg();
cfgDOA.ElesigNum = 2;
arrData = makeTwoPlaneWaves(16, -15, 20, 0.8);

doaOut = elevationDOA(arrData, cfgDOA);

verifyEqual(testCase, numel(doaOut.angleVal), 2);
verifyEqual(testCase, sort(doaOut.angleVal), [-15, 20], 'AbsTol', 3);
end

function test_zero_signal_returns_empty(testCase)
cfgDOA = baseCfg();
cfgDOA.ElesigNum = 2;
arrData = zeros(8, 1);

doaOut = elevationDOA(arrData, cfgDOA);

verifyEmpty(testCase, doaOut.angleVal);
end
