function [radar_data, adcCube, readerInfo] = readDCA1000Raw(fileName, numADCSamples, numRX, numTX, numADCBits, isReal)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : readDCA1000Raw.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Read DCA1000 raw bin data for TDM-MIMO processing
% -------------------------------------------------------------------------
% radar_data format   : (numRX*numTX) x (loopChirpNum*numADCSamples)
% adcCube format      : numADCSamples x loopChirpNum x (numRX*numTX)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 4 || isempty(numTX)
    numTX = 1;
end
if nargin < 5 || isempty(numADCBits)
    numADCBits = 16;
end
if nargin < 6 || isempty(isReal)
    isReal = 0;
end

%% read file
fid = fopen(fileName, 'r');
if fid < 0
    error('Cannot open DCA1000 bin file: %s', fileName);
end
adcData = fread(fid, 'int16');
fclose(fid);

if numADCBits ~= 16
    l_max = 2^(numADCBits - 1) - 1;
    adcData(adcData > l_max) = adcData(adcData > l_max) - 2^numADCBits;
end

fileSize = size(adcData, 1);
channelNum = numRX * numTX;

%% LVDS data to complex samples
if isReal
    chirpTotalNum = fileSize / numADCSamples / numRX;
    if mod(chirpTotalNum, numTX) ~= 0
        error('File size does not match numADCSamples, numRX and numTX.');
    end
    lvds_data = reshape(adcData, numADCSamples * numRX * numTX, chirpTotalNum / numTX);
    lvds_data = lvds_data.';
else
    chirpTotalNum = fileSize / 2 / numADCSamples / numRX;
    if mod(chirpTotalNum, numTX) ~= 0
        error('File size does not match complex DCA1000 TDM-MIMO configuration.');
    end

    % TI DCA1000 complex format: two I samples followed by two Q samples.
    lvds_complex = zeros(1, fileSize / 2);
    count = 1;
    for idx = 1:4:fileSize - 1
        lvds_complex(1, count) = adcData(idx) + 1j * adcData(idx + 2);
        lvds_complex(1, count + 1) = adcData(idx + 1) + 1j * adcData(idx + 3);
        count = count + 2;
    end

    lvds_data = reshape(lvds_complex, numADCSamples * channelNum, chirpTotalNum / numTX);
    lvds_data = lvds_data.';
end

loopChirpNum = size(lvds_data, 1);

%% organize data per virtual channel
radar_data = zeros(channelNum, loopChirpNum * numADCSamples);
for row = 1:channelNum
    for chirpIdex = 1:loopChirpNum
        sampleStart = (chirpIdex - 1) * numADCSamples + 1;
        sampleEnd = chirpIdex * numADCSamples;
        lvdsStart = (row - 1) * numADCSamples + 1;
        lvdsEnd = row * numADCSamples;
        radar_data(row, sampleStart:sampleEnd) = lvds_data(chirpIdex, lvdsStart:lvdsEnd);
    end
end

adcCube = zeros(numADCSamples, loopChirpNum, channelNum);
for channelIdex = 1:channelNum
    adcCube(:, :, channelIdex) = reshape(radar_data(channelIdex, :), numADCSamples, loopChirpNum);
end

readerInfo.fileSize = fileSize;
readerInfo.numADCSamples = numADCSamples;
readerInfo.numRX = numRX;
readerInfo.numTX = numTX;
readerInfo.channelNum = channelNum;
readerInfo.chirpTotalNum = chirpTotalNum;
readerInfo.loopChirpNum = loopChirpNum;
readerInfo.numADCBits = numADCBits;
readerInfo.isReal = isReal;

end
