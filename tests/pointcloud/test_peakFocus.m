function tests = test_peakFocus
% Unit tests for pointcloud/peakFocus.m.
%
% Pins the current behavior: 4-neighbor local-max refinement over CFAR
% survivors only (NOT over the full RDM). This guards against any future
% "refactor to full-RDM scan" regression.
%
% Run from project root:
%   >> startup
%   >> runtests('tests/pointcloud/test_peakFocus.m')

tests = functiontests(localfunctions);
end

% --------------------------- helpers ---------------------------------------

function RDM = makeRDMWithSinglePeak(R, D, rIdex, dIdex, height)
RDM = ones(R, D);
RDM(rIdex, dIdex) = height;
end

% --------------------------- tests -----------------------------------------

function test_empty_survivor_returns_empty(testCase)
RDM = ones(64, 32);
[rd_peak_list, rd_peak] = peakFocus(RDM, zeros(0, 2));
verifyEmpty(testCase, rd_peak_list);
verifyEqual(testCase, size(rd_peak), size(RDM));
verifyEqual(testCase, nnz(rd_peak), 0);
end

function test_isolated_peak_survives(testCase)
RDM = makeRDMWithSinglePeak(64, 32, 20, 10, 99);
cfar_out_list = [20, 10];
[rd_peak_list, rd_peak] = peakFocus(RDM, cfar_out_list);

verifyEqual(testCase, size(rd_peak_list), [2, 1]);
verifyEqual(testCase, rd_peak_list(1), 20);
verifyEqual(testCase, rd_peak_list(2), 10);
verifyEqual(testCase, rd_peak(20, 10), 99);
end

function test_non_local_max_dropped(testCase)
% A cell that is NOT bigger than all 4 neighbors must be dropped.
RDM = ones(64, 32);
RDM(20, 10) = 50;
RDM(20, 11) = 80;   % east neighbor is larger
cfar_out_list = [20, 10];

[rd_peak_list, ~] = peakFocus(RDM, cfar_out_list);
verifyEmpty(testCase, rd_peak_list);
end

function test_border_cells_are_skipped(testCase)
% peakFocus's bounds check rejects index 1 / size(RDM,*) on either axis.
% This is current behavior; pin it so a refactor doesn't silently change it.
RDM = ones(64, 32);
RDM(1, 10) = 99;       % top border
RDM(64, 10) = 99;      % bottom border
RDM(20, 1) = 99;       % left border
RDM(20, 32) = 99;      % right border
cfar_out_list = [1, 10; 64, 10; 20, 1; 20, 32];

[rd_peak_list, ~] = peakFocus(RDM, cfar_out_list);
verifyEmpty(testCase, rd_peak_list);
end

function test_only_survivors_are_examined(testCase)
% Pin the survivor-only contract: a strong peak NOT in cfar_out_list must
% not appear in rd_peak_list, even though it would qualify as local-max.
% Guards against any "scan full RDM" regression suggested by the diagnostic
% report's §2.3 (which mis-described current behavior).
RDM = ones(64, 32);
RDM(20, 10) = 99;   % in survivor list
RDM(40, 15) = 80;   % NOT in survivor list, would-be local max
cfar_out_list = [20, 10];

[rd_peak_list, rd_peak] = peakFocus(RDM, cfar_out_list);
verifyEqual(testCase, size(rd_peak_list, 2), 1);
verifyEqual(testCase, rd_peak(40, 15), 0);   % rd_peak only fills survivors
verifyEqual(testCase, rd_peak(20, 10), 99);
end

function test_multiple_survivors_partial_keep(testCase)
% Two survivors, only one is a local max.
RDM = ones(64, 32);
RDM(20, 10) = 99;   % real local max
RDM(40, 15) = 50;
RDM(40, 16) = 80;   % neighbor larger => (40,15) not local max
cfar_out_list = [20, 10; 40, 15];

[rd_peak_list, ~] = peakFocus(RDM, cfar_out_list);
verifyEqual(testCase, size(rd_peak_list, 2), 1);
verifyEqual(testCase, rd_peak_list(1, 1), 20);
verifyEqual(testCase, rd_peak_list(2, 1), 10);
end

function test_py_doppler_wrap_keeps_border_peak(testCase)
% OpenRadar peak grouping wraps Doppler neighbors. A Doppler-bin-1
% survivor can be a valid peak if it beats bin D and bin 2.
RDM = ones(8, 5);
RDM(3, 5) = 5;
RDM(3, 1) = 10;
RDM(3, 2) = 4;
cfar_out_list = [3, 1];

cfgDOA.PeakFocusMode = 'py_doppler';
cfgDOA.ReservePeakNeighbor = false;

[rd_peak_list, rd_peak] = peakFocus(RDM, cfar_out_list, cfgDOA);

verifyEqual(testCase, rd_peak_list, [3; 1]);
verifyEqual(testCase, rd_peak(3, 1), 10);
end

function test_py_doppler_reserve_neighbor_keeps_peak_neighbor(testCase)
% Reference pattern from OpenRadar noise_removal.py::prune_to_peaks:
% use a wrap-safe variant [4 1 5 3 2], which keeps [4 5 3].
RDM = ones(8, 5);
RDM(3, :) = [4, 1, 5, 3, 2];
cfar_out_list = [3, 1;
                 3, 2;
                 3, 3;
                 3, 4;
                 3, 5];

cfgDOA.PeakFocusMode = 'py_doppler';
cfgDOA.ReservePeakNeighbor = true;

[rd_peak_list, rd_peak] = peakFocus(RDM, cfar_out_list, cfgDOA);

verifyEqual(testCase, rd_peak_list.', [3, 1; 3, 3; 3, 4]);
verifyEqual(testCase, rd_peak(3, [1, 3, 4]), [4, 5, 3]);
verifyEqual(testCase, nnz(rd_peak), 3);
end
