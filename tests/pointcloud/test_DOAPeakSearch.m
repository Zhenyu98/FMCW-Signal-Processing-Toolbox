function tests = test_DOAPeakSearch
% Unit tests for pointcloud/SelectDOAPeaks.m.
%
% The py_full_variance mode mirrors the peak-search rule used by
% OpenRadar mmwave/dsp/angle_estimation.py::peak_search_full_variance:
% gamma controls when a lobe has fallen enough, and sidelobe_level rejects
% weak peaks relative to the largest spectrum value.

tests = functiontests(localfunctions);
end

function cfgDOA = pyCfg()
cfgDOA.DOAPeakSearch = 'py_full_variance';
cfgDOA.DOAGamma = 1.2;
cfgDOA.DOASidelobeLevel = 0.25;
end

function test_py_full_variance_detects_two_lobes(testCase)
spec = [1, 2, 10, 7, 1, 2, 3, 2, 1];
cfgDOA = pyCfg();

[peakVal, peakIdx] = SelectDOAPeaks(spec, 4, cfgDOA);

verifyEqual(testCase, peakIdx(:).', [3, 7]);
verifyEqual(testCase, peakVal(:).', [10, 3]);
end

function test_py_full_variance_sidelobe_level_rejects_weak_lobe(testCase)
spec = [1, 2, 10, 7, 1, 2, 3, 2, 1];
cfgDOA = pyCfg();
cfgDOA.DOASidelobeLevel = 0.5;

[peakVal, peakIdx] = SelectDOAPeaks(spec, 4, cfgDOA);

verifyEqual(testCase, peakIdx(:).', 3);
verifyEqual(testCase, peakVal(:).', 10);
end

function test_py_full_variance_respects_max_peak_num(testCase)
spec = [1, 2, 10, 7, 1, 2, 8, 2, 1];
cfgDOA = pyCfg();

[peakVal, peakIdx] = SelectDOAPeaks(spec, 1, cfgDOA);

verifyEqual(testCase, peakIdx(:).', 3);
verifyEqual(testCase, peakVal(:).', 10);
end

function test_legacy_findpeaks_keeps_existing_descending_contract(testCase)
spec = [0, 3, 0, 10, 0, 5, 0];
cfgDOA.DOAPeakSearch = 'legacy_findpeaks';

[peakVal, peakIdx] = SelectDOAPeaks(spec, 2, cfgDOA);

verifyEqual(testCase, peakIdx(:).', [4, 6]);
verifyEqual(testCase, peakVal(:).', [10, 5]);
end
