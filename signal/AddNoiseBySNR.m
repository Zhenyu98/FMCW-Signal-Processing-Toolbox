function [noisyData, noiseInfo] = AddNoiseBySNR(cleanData, SNR_dB)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : AddNoiseBySNR.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Add complex white Gaussian noise by measured SNR
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

signalPower = mean(abs(cleanData(:)).^2);
noisePower = signalPower / (10^(SNR_dB / 10));

if isreal(cleanData)
    noise = sqrt(noisePower) * randn(size(cleanData));
else
    noise = sqrt(noisePower / 2) * (randn(size(cleanData)) + 1j * randn(size(cleanData)));
end

noisyData = cleanData + noise;

noiseInfo.SNR_dB = SNR_dB;
noiseInfo.signalPower = signalPower;
noiseInfo.noisePower = noisePower;
noiseInfo.noiseStd = sqrt(noisePower);

end
