%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : demo_pointcloud_sim.m
% Date & time         : May. 2026
% Version             : 1.1
% Purpose             : TDMA-MIMO point cloud generation from signal module
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% generate radar signal
sensorParams.Start_Freq_GHz = 76.5;
sensorParams.Slope_MHzperus = 46.397;
sensorParams.Sampling_Rate_ksps = 6874;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 64;                         % TDM cycles in one frame
sensorParams.TxNum = 3;
sensorParams.RxNum = 4;
sensorParams.ArrayType = 'TI_xWRx843';
sensorParams.SNR_dB = 20;                       % Observation SNR (dB)

targetParams.amplitude = [20, 20, 10];           % Target amplitudes
targetParams.range = [5, 10, 15];                % Target ranges (m)
targetParams.velocity = [0.4, -0.3, 0.1];        % Target velocities (m/s)
targetParams.azimuth = [15, -20, 25];             % Target azimuth angles (degree)
targetParams.elevation = [0, 8, -5];             % Target elevation angles (degree)

radarParams = RadarParameterGenerate(sensorParams, targetParams);
rng(2026)
[data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);
adcData = RadarCubeToPointCloudInput(data);

%% define point cloud parameters
cfgOut = ConfigurePointCloudParameter(sensorParams, radarParams);
IQFlag = 1;

cfgDOA.FFTNum = 180;
cfgDOA.AziMethod = 'FFT';
cfgDOA.EleMethod = 'FFT';
cfgDOA.thetaGrids = linspace(-90, 90, cfgDOA.FFTNum);
cfgDOA.AzisigNum = 1;
cfgDOA.ElesigNum = 1;
cfgDOA.Pfa = 1e-3;
cfgDOA.TestCells = [8, 8];
cfgDOA.GuardCells = [2, 2];

range_axis = radarParams.range_axis;
doppler_axis = radarParams.doppler_axis;

%% main method
[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, IQFlag);

figure
imagesc(range_axis, doppler_axis, db(pointcloudInfo.dopplerFFTOut(:, :, 1).'))
xlabel('Range (m)')
ylabel('Velocity (m/s)')
title('Simulated Range-Doppler Map')
colormap('jet')
axis xy
grid minor
subtitle(['SNR = ', num2str(noiseInfo.SNR_dB), ' dB'])

if ~isempty(frame_data)
    figure
    scatter3(frame_data(:, 1), frame_data(:, 2), frame_data(:, 3), 10, frame_data(:, 8), 'filled')
    hold on
    scatter3(targetParams.range .* cosd(targetParams.elevation) .* sind(targetParams.azimuth), ...
        targetParams.range .* cosd(targetParams.elevation) .* cosd(targetParams.azimuth), ...
        targetParams.range .* sind(targetParams.elevation), 60, 'r', 'filled')
    xlabel('X (m)')
    ylabel('Y (m)')
    zlabel('Z (m)')
    legend('Estimated point cloud', 'Real target')
    title('Simulated Point Cloud')
    grid on
    axis equal
end
