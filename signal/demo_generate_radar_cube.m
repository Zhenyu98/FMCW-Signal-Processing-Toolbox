%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : demo_generate_radar_cube.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Demo for FMCW radar signal generation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% generate radar signal
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 3.04;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Adc_Start_Time_us = 4.66;
sensorParams.Frame_Repetition_Period_ms = 80;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 64;
sensorParams.TxNum = 3;
sensorParams.RxNum = 4;
% sensorParams.SNR_dB = 20;                       % Uncomment to add observation noise

%% define antenna array
sensorParams.ArrayType = 'TI_xWRx843';           % TI_xWRx843 / TI_xWRx843_ODS / TI_xWRx642
% sensorParams.VirtualArrayMap = [               % Custom virtual array map
%     NaN NaN 8   9   10  11 NaN NaN
%     0   1   2   3   4   5   6   7
% ];

targetParams.amplitude = [8, 12];       % Target amplitudes
targetParams.range = [7.00, 7.50];      % Target ranges (m)
targetParams.velocity = [-0.2, 0.5];    % Target velocities (m/s)
targetParams.azimuth = [0, 0];          % Target azimuth angles (degree)
targetParams.elevation = [0, 0];        % Target elevation angles (degree)

radarParams = RadarParameterGenerate(sensorParams, targetParams);
[data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);

disp('Data generation completed!')
disp(['data size: ', mat2str(size(data))])
disp(['range resolution: ', num2str(radarParams.range_res), ' m'])
if ~isempty(noiseInfo.SNR_dB)
    disp(['SNR: ', num2str(noiseInfo.SNR_dB), ' dB'])
end

%% plotting and comparison
range_profile = fft(data(:, 1, 1, 1), radarParams.SampleNum);

figure
plot(radarParams.range_axis, abs(range_profile), 'LineWidth', 1.5, 'Color', 'r')
hold on
for targetIdex = 1:length(targetParams.range)
    xline(targetParams.range(targetIdex), 'k--', 'LineWidth', 1.2)
end
xlabel('Range (m)')
ylabel('Amplitude')
legend('Range FFT', 'Real Value')
title('Generated FMCW Range Profile')
grid on
