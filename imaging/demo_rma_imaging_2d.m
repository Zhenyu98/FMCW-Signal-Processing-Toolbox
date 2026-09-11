%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : demo_rma_imaging_2d.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : 2D-RMA imaging demo for raw echo data
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
sensorParams.Slope_MHzperus = 70.295;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Adc_Start_Time_us = 4.66;
sensorParams.Frame_Repetition_Period_ms = 80;
sensorParams.Samples_per_Chirp = 256;

sarParams.RowSampleNum = 77;
sarParams.Horizontal_stepSize_mm = 1;
sarParams.Vertical_stepSize_mm = 2;
sarParams.imSize = 5000;

targetDist = 0.48e3;                           % Target distance (mm)

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
[rawData, sarImage, xRangeT, yRangeT] = SarRMAimaging_2D(filespath, sensorParams, sarParams, targetDist, Flag);
