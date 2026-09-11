%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : demo_range_doppler_map.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Range-Doppler map demo using generated radar cube
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% generate radar signal
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 3.04;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 64;
sensorParams.TxNum = 1;
sensorParams.RxNum = 8;

targetParams.amplitude = [8, 12];
targetParams.range = [7.00, 7.50];
targetParams.velocity = [-0.2, 0.5];
targetParams.azimuth = [0, 0];
targetParams.elevation = [0, 0];

radarParams = RadarParameterGenerate(sensorParams, targetParams);
data = RadarCubeGenerate(targetParams, radarParams);

%% main method
[dopplerFFTOut, range_axis, velocity_axis] = RDM(data, sensorParams, true);
