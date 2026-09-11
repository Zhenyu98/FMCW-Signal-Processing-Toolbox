%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : demo_pointcloud_bin.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Point cloud generation from DCA1000 bin data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% load data
cfgOut = ConfigureParameter;
ADC_samples = cfgOut.ADCNum;
chirpsNum = cfgOut.ChirpNum;
numRx = cfgOut.numRx;
numTx = cfgOut.numTx;
Frame = cfgOut.Frame;
IQFlag = 1;

fileName = '';
if isempty(fileName) || ~exist(fileName, 'file')
    [filename, pathname] = uigetfile('*.bin', 'choose DCA1000 adc_data bin file');
    if isequal(filename, 0)
        return
    end
    fileName = fullfile(pathname, filename);
end

% read DCA1000 raw data and organize TDM-MIMO channels.
[radar_data, adcCubeAll, readerInfo] = readDCA1000Raw(fileName, ADC_samples, numRx, numTx);
Frame = min(Frame, floor(readerInfo.loopChirpNum / chirpsNum));

%% define parameters
cfgDOA.FFTNum = 180;
cfgDOA.AziMethod = 'FFT';
cfgDOA.EleMethod = 'FFT';
cfgDOA.thetaGrids = linspace(-90, 90, cfgDOA.FFTNum);
cfgDOA.AzisigNum = 1;
cfgDOA.ElesigNum = 1;
cfgDOA.Pfa = 1e-3;
cfgDOA.TestCells = [8, 8];
cfgDOA.GuardCells = [2, 2];

allFrames = struct('frame_data', cell(1, Frame));

%% main method
for frame_id = 1:Frame
    chirpStart = (frame_id - 1) * chirpsNum + 1;
    chirpEnd = frame_id * chirpsNum;
    adcData = adcCubeAll(:, chirpStart:chirpEnd, :);

    [frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, IQFlag);
    allFrames(frame_id).frame_data = frame_data;

    if ~isempty(frame_data)
        figure(1)
        scatter3(frame_data(:, 1), frame_data(:, 2), frame_data(:, 3), 10, frame_data(:, 8), 'filled')
        xlabel('X (m)')
        ylabel('Y (m)')
        zlabel('Z (m)')
        title(['Frame ', num2str(frame_id), ' Point Cloud'])
        grid on
        axis equal
        drawnow
    end
end

save('pointcloud_frames.mat', 'allFrames')
