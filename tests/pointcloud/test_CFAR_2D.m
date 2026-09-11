function tests = test_CFAR_2D
% Unit tests for pointcloud/CFAR_2D.m (both phased_soca and separable_ca branches).
% Pinned behavior on a canonical 4-target range-Doppler map.
%
% Run from project root:
%   >> startup
%   >> runtests('tests/pointcloud/test_CFAR_2D.m')

tests = functiontests(localfunctions);
end

% --------------------------- fixtures ---------------------------------------

function fixture = canonicalRDM()
% Same 4-target synthetic RDM as profile_pointcloud_cfar_diagnosis.m so the
% pinned numbers track the diagnostic script.
rng(2026)
RangeBin = 256;
DopplerBin = 64;
RDM = abs(1 + 0.25 * randn(RangeBin, DopplerBin)).^2;

targetBins = [42, 29;
              96, 34;
              160, 41;
              210, 22];
for tIdex = 1:size(targetBins, 1)
    rIdex = targetBins(tIdex, 1);
    dIdex = targetBins(tIdex, 2);
    RDM(rIdex, dIdex) = RDM(rIdex, dIdex) + 80;
    RDM(rIdex + (-1:1), dIdex) = RDM(rIdex + (-1:1), dIdex) + [10; 25; 10];
    RDM(rIdex, dIdex + (-1:1)) = RDM(rIdex, dIdex + (-1:1)) + [8, 20, 8];
end

fixture.RDM = RDM;
fixture.targetBins = targetBins;
fixture.Pfa = 1e-3;
fixture.TestCells = [8, 8];
fixture.GuardCells = [2, 2];
end

% --------------------- separable_ca branch tests ---------------------------

function test_separable_ca_detects_all_4_targets(testCase)
f = canonicalRDM();
cfgDOA.CFARMethod = 'separable_ca';
cfgDOA.L_bound = 1.5;

cfarOut = CFAR_2D(f.RDM, f.Pfa, f.TestCells, f.GuardCells, cfgDOA);

% every truth bin must be flagged as detection
for tIdex = 1:size(f.targetBins, 1)
    rIdex = f.targetBins(tIdex, 1);
    dIdex = f.targetBins(tIdex, 2);
    verifyTrue(testCase, cfarOut.cfarMap(rIdex, dIdex), ...
        sprintf('target bin (%d, %d) missed by separable_ca', rIdex, dIdex));
end
end

function test_separable_ca_output_struct_fields(testCase)
f = canonicalRDM();
cfgDOA.CFARMethod = 'separable_ca';
cfgDOA.L_bound = 1.5;

cfarOut = CFAR_2D(f.RDM, f.Pfa, f.TestCells, f.GuardCells, cfgDOA);

verifyTrue(testCase, isfield(cfarOut, 'cfarMap'));
verifyTrue(testCase, isfield(cfarOut, 'snrOut'));
verifyTrue(testCase, isfield(cfarOut, 'noiseOut'));
verifyTrue(testCase, isfield(cfarOut, 'thresholdOut'));
verifyEqual(testCase, cfarOut.method, 'separable_ca');
verifyTrue(testCase, islogical(cfarOut.cfarMap));
verifyEqual(testCase, size(cfarOut.cfarMap), size(f.RDM));
end

function test_separable_ca_default_lbound_used_when_missing(testCase)
% L_bound default = 1.5; omitting cfgDOA.L_bound must not error.
f = canonicalRDM();
cfgDOA.CFARMethod = 'separable_ca';

cfarOut = CFAR_2D(f.RDM, f.Pfa, f.TestCells, f.GuardCells, cfgDOA);
verifyEqual(testCase, cfarOut.method, 'separable_ca');
verifyEqual(testCase, cfarOut.L_bound, 1.5);
end

function test_separable_ca_higher_lbound_kills_detections(testCase)
% Monotonicity sanity: raising L_bound never increases detection count.
f = canonicalRDM();
cfgDOA.CFARMethod = 'separable_ca';

cfgDOA.L_bound = 1.5;
cfarLow = CFAR_2D(f.RDM, f.Pfa, f.TestCells, f.GuardCells, cfgDOA);
cfgDOA.L_bound = 50;   % crank threshold high
cfarHigh = CFAR_2D(f.RDM, f.Pfa, f.TestCells, f.GuardCells, cfgDOA);

verifyLessThanOrEqual(testCase, nnz(cfarHigh.cfarMap), nnz(cfarLow.cfarMap));
end

function test_separable_ca_per_axis_lbound_matches_py_ca(testCase)
% OpenRadar uses independent additive l_bound values on range and
% Doppler axes. The MATLAB separable branch should keep the same contract.
RDM = reshape(1:20, 4, 5);
Pfa = 1e-3;
TestCells = [1, 2];
GuardCells = [1, 0];

cfgDOA.CFARMethod = 'separable_ca';
cfgDOA.L_bound = 99;                 % Should be ignored by axis-specific fields
cfgDOA.L_bound_Range = 2.0;
cfgDOA.L_bound_Doppler = 7.0;

cfarOut = CFAR_2D(RDM, Pfa, TestCells, GuardCells, cfgDOA);

noiseRMap = localPyMean1D(RDM, GuardCells(1), TestCells(1), 1);
noiseDMap = localPyMean1D(RDM, GuardCells(2), TestCells(2), 2);

verifyEqual(testCase, cfarOut.noiseRMap, noiseRMap, 'AbsTol', 1e-12);
verifyEqual(testCase, cfarOut.noiseDMap, noiseDMap, 'AbsTol', 1e-12);
verifyEqual(testCase, cfarOut.thresholdOut(:,:,1), noiseRMap + cfgDOA.L_bound_Range, 'AbsTol', 1e-12);
verifyEqual(testCase, cfarOut.thresholdOut(:,:,2), noiseDMap + cfgDOA.L_bound_Doppler, 'AbsTol', 1e-12);
verifyEqual(testCase, cfarOut.L_bound_Range, cfgDOA.L_bound_Range);
verifyEqual(testCase, cfarOut.L_bound_Doppler, cfgDOA.L_bound_Doppler);
end

% ----------------------- phased_soca branch tests --------------------------

function test_phased_soca_default_method(testCase)
% Backward compat: empty cfgDOA must route to phased_soca (legacy default).
f = canonicalRDM();
if ~hasPhasedToolbox()
    assumeFail(testCase, 'Phased Array Toolbox missing; skipping phased_soca test');
end

cfarOut = CFAR_2D(f.RDM, f.Pfa, f.TestCells, f.GuardCells);   % no cfgDOA
verifyEqual(testCase, cfarOut.method, 'phased_soca');
end

function test_phased_soca_detects_at_least_one_target(testCase)
f = canonicalRDM();
if ~hasPhasedToolbox()
    assumeFail(testCase, 'Phased Array Toolbox missing; skipping phased_soca test');
end

cfgDOA.CFARMethod = 'phased_soca';
cfarOut = CFAR_2D(f.RDM, f.Pfa, f.TestCells, f.GuardCells, cfgDOA);

% At least one of the 4 truth bins must be detected.
hitCount = 0;
for tIdex = 1:size(f.targetBins, 1)
    if cfarOut.cfarMap(f.targetBins(tIdex, 1), f.targetBins(tIdex, 2))
        hitCount = hitCount + 1;
    end
end
verifyGreaterThanOrEqual(testCase, hitCount, 1);
end

% ----------------------- dispatcher behavior -------------------------------

function test_unknown_method_raises(testCase)
f = canonicalRDM();
cfgDOA.CFARMethod = 'totally_unknown_method_xyz';

verifyError(testCase, ...
    @() CFAR_2D(f.RDM, f.Pfa, f.TestCells, f.GuardCells, cfgDOA), ...
    ?MException);   % CFAR_2D uses bare error() without identifier
end

% ----------------------- helpers -------------------------------------------

function ok = hasPhasedToolbox()
ok = ~isempty(ver('phased'));
end

function noiseMap = localPyMean1D(RDM, guardLen, noiseLen, dimIdex)
% Reference behavior from OpenRadar mmwave/dsp/cfar.py::ca_:
% convolve1d with mode='wrap', guard+CUT zeroed, denominator 2*noiseLen.
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

noiseMap = noiseMap / (2 * noiseLen);
end
