%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : demo_pointcloud_ra_sim.m
% Date & time         : Jun. 2026
% Version             : 1.0
% Purpose             : Range-azimuth point cloud generation from signal module
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% generate radar signal
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 19.988;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 64;
sensorParams.TxNum = 1;
sensorParams.RxNum = 8;
sensorParams.SNR_dB = 35;                       % Observation SNR (dB)

targetParams.amplitude = [20, 18];              % Target amplitudes
targetParams.range = [5.0, 9.0];                % Target ranges (m)
targetParams.velocity = [0.0, 0.0];             % Target velocities (m/s)
targetParams.azimuth = [-15, 20];               % Target azimuth angles (degree)
targetParams.elevation = [0, 0];                % Target elevation angles (degree)

radarParams = RadarParameterGenerate(sensorParams, targetParams);
rng(2026)
[data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);
adcData = RadarCubeToPointCloudInput(data);

%% define point cloud parameters
cfgOut = ConfigurePointCloudParameter(sensorParams, radarParams);
IQFlag = 1;

cfgDOA.PointCloudPipeline = 'RA';
cfgDOA.FFTNum = 256;
cfgDOA.AziMethod = 'FFT';
cfgDOA.AzisigNum = 1;
cfgDOA.EleMethod = 'FFT';
cfgDOA.ElesigNum = 1;
cfgDOA.thetaGrids = linspace(-90, 90, cfgDOA.FFTNum);
cfgDOA.Pfa = 1e-3;
cfgDOA.TestCells = [8, 8];
cfgDOA.GuardCells = [2, 2];
cfgDOA.CFARMethod = 'separable_ca';
cfgDOA.L_bound = 0.2;                           % RA map uses its own scale
cfgDOA.MaxDetections = length(targetParams.range);

range_axis = radarParams.range_axis;

%% main method
[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, IQFlag);

figure
imagesc(pointcloudInfo.angle_axis, range_axis, abs(pointcloudInfo.RAM))
xlabel('Azimuth (degree)')
ylabel('Range (m)')
title('Simulated Range-Azimuth Map')
colormap('jet')
axis xy
grid minor
subtitle(['SNR = ', num2str(noiseInfo.SNR_dB), ' dB'])

if ~isempty(frame_data)
    figure
    scatter(frame_data(:, 1), frame_data(:, 2), 30, frame_data(:, 8), 'filled')
    hold on
    scatter(targetParams.range .* sind(targetParams.azimuth), ...
        targetParams.range .* cosd(targetParams.azimuth), 80, 'r', 'filled')
    xlabel('X (m)')
    ylabel('Y (m)')
    legend('Estimated point cloud', 'Real target')
    title('Simulated RA Point Cloud')
    grid on
    axis equal
end
