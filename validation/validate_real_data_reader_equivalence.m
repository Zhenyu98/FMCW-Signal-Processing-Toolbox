%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_real_data_reader_equivalence.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Equivalence check for DCA1000 real-data raw reader
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% reference project
toolboxRoot = fileparts(fileparts(mfilename('fullpath')));
refPath = fullfile(toolboxRoot, '0_refer_code', '点云生成实际数据');
binFile = fullfile(refPath, 'adc_data.bin');

%% define parameters
numADCSamples = 256;
numRX = 4;
numTX = 3;

if ~exist(binFile, 'file')
    disp(['Skip DCA1000 raw reader equivalence: reference bin file not found: ', binFile])
    disp('`0_refer_code/` is local-only and ignored by git.')
    return
end

%% run reference reader
addpath(refPath, '-begin')
ref_radar_data = readDCA1000(binFile, numADCSamples, numRX);
rmpath(refPath)

%% run toolbox reader
run(fullfile(toolboxRoot, 'startup.m'));
[radar_data, adcCube, readerInfo] = readDCA1000Raw(binFile, numADCSamples, numRX, numTX);

%% equivalence metrics
rawNmse = norm(ref_radar_data(:) - radar_data(:))^2 / (norm(ref_radar_data(:))^2 + eps);
maxAbsError = max(abs(ref_radar_data(:) - radar_data(:)));

disp(['raw NMSE: ', num2str(rawNmse)])
disp(['max abs error: ', num2str(maxAbsError)])
disp(['readerInfo.loopChirpNum: ', num2str(readerInfo.loopChirpNum)])
disp(['adcCube size: ', mat2str(size(adcCube))])

%% sanity checks
assert(isequal(size(ref_radar_data), size(radar_data)))
assert(rawNmse < 1e-12)
assert(maxAbsError == 0)

disp('DCA1000 raw reader equivalence validation passed.')
