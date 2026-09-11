%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : profile_pointcloud_frame_time.m
% Date & time         : Sep. 2026
% Version             : 1.0
% Purpose             : Time one point-cloud frame, legacy CFAR vs separable_ca
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The legacy configuration (phased_soca CFAR) keeps the reference-project
% behaviour; the fast configuration only switches CFAR_2D to separable_ca.
% Both runs use the same simulated cube, so the printed times are directly
% comparable. This is a profiling script, not an equivalence check.

clc
clear
close all

%% generate radar signal (same scene as pointcloud/demo_pointcloud_sim.m)
sensorParams.Start_Freq_GHz = 76.5;
sensorParams.Slope_MHzperus = 46.397;
sensorParams.Sampling_Rate_ksps = 6874;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 64;                         % TDM cycles in one frame
sensorParams.TxNum = 3;
sensorParams.RxNum = 4;
sensorParams.ArrayType = 'TI_xWRx843';
sensorParams.SNR_dB = 20;                        % Observation SNR (dB)

targetParams.amplitude = [20, 20, 10];
targetParams.range = [5, 10, 15];                % Target ranges (m)
targetParams.velocity = [0.4, -0.3, 0.1];        % Target velocities (m/s)
targetParams.azimuth = [15, -20, 25];            % Target azimuth angles (degree)
targetParams.elevation = [0, 8, -5];             % Target elevation angles (degree)

radarParams = RadarParameterGenerate(sensorParams, targetParams);
rng(2026)
data = RadarCubeGenerate(targetParams, radarParams);
adcData = RadarCubeToPointCloudInput(data);
cfgOut = ConfigurePointCloudParameter(sensorParams, radarParams);

%% define point cloud parameters
cfgDOA.FFTNum = 180;
cfgDOA.AziMethod = 'FFT';
cfgDOA.EleMethod = 'FFT';
cfgDOA.thetaGrids = linspace(-90, 90, cfgDOA.FFTNum);
cfgDOA.AzisigNum = 1;
cfgDOA.ElesigNum = 1;
cfgDOA.Pfa = 1e-3;
cfgDOA.TestCells = [8, 8];
cfgDOA.GuardCells = [2, 2];

cfgLegacy = cfgDOA;                              % phased_soca, reference behaviour
cfgFast = cfgDOA;
cfgFast.CFARMethod = 'separable_ca';
cfgFast.L_bound = 1.5;

%% time both configurations
RepeatNum = 20;
cfgList = {cfgLegacy, cfgFast};
cfgName = {'legacy phased_soca', 'fast separable_ca'};
frameTime_ms = zeros(RepeatNum, numel(cfgList));
pointNum = zeros(1, numel(cfgList));

for cfgIdex = 1:numel(cfgList)
    cfg = cfgList{cfgIdex};
    GeneratePointCloudFrame(adcData, cfgOut, cfg, 1);      % warm-up, excluded from timing
    for rIdex = 1:RepeatNum
        tic
        frame_data = GeneratePointCloudFrame(adcData, cfgOut, cfg, 1);
        frameTime_ms(rIdex, cfgIdex) = 1e3 * toc;
    end
    pointNum(cfgIdex) = size(frame_data, 1);
end

%% report
disp('===== profile_pointcloud_frame_time =====')
fprintf('cube size: %s, repeats: %d\n', mat2str(size(data)), RepeatNum)
for cfgIdex = 1:numel(cfgList)
    fprintf('%-20s median %6.1f ms   (min %6.1f, max %6.1f)   points %d\n', ...
        cfgName{cfgIdex}, median(frameTime_ms(:, cfgIdex)), ...
        min(frameTime_ms(:, cfgIdex)), max(frameTime_ms(:, cfgIdex)), pointNum(cfgIdex))
end
fprintf('speedup (median): %.1fx\n', median(frameTime_ms(:, 1)) / median(frameTime_ms(:, 2)))
