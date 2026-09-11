%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : demo_bp_imaging_2d.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : 2D-BP imaging demo for raw echo data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% define parameters
IsFFTpre = false;
imgFisrt = false;
IsPlot = true;
IsReverseData = true;
Flag = [IsFFTpre, imgFisrt, IsPlot, IsReverseData];

sensorParams.TxNum = 1;
sensorParams.RxNum = 4;
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 1.5;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Adc_Start_Time_us = 4.66;
sensorParams.Frame_Repetition_Period_ms = 80;
sensorParams.Samples_per_Chirp = 512;

sarParams.RowSampleNum = 200;
sarParams.Horizontal_stepSize_mm = 1;

% imgCut = [AzimuthL, dL, rangeNear, rangeFar]
imgCut = [200, 200, 0, 400];

%% load data
filespath = '';
if isempty(filespath) || ~exist(filespath, 'file')
    [filename, pathname] = uigetfile('*.*', 'choose SAR raw echo file');
    if isequal(filename, 0)
        return
    end
    filespath = fullfile(pathname, filename);
end

%% main method
[rawData, Matrix_Imag] = RAM_BPimaging(filespath, sensorParams, sarParams, imgCut, Flag);

figure
imagesc(abs(Matrix_Imag))
axis xy
xlabel('Azimuth index')
ylabel('Range index')
title('BP Imaging Result')
colorbar
