function [dopplerFFTOut, range_axis, velocity_axis] = RDM(data, sensorParams, IsPlot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : RDM.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Range-Doppler Map for FMCW radar data cube
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 3
    IsPlot = true;
end

%% define parameters
f_0 = sensorParams.Start_Freq_GHz * 1e9;          % Starting frequency (Hz)
K = sensorParams.Slope_MHzperus * 1e12;           % Slope (Hz/s)
Fs = sensorParams.Sampling_Rate_ksps * 1e3;       % Sampling rate (Hz)
Ts = 1 / Fs;                                      % Sample interval (s)
SampleNum = sensorParams.Samples_per_Chirp;       % Number of ADC samples
TxNum = sensorParams.TxNum;                       % Number of Tx antennas

c = physconst('lightspeed');                      % Speed of light (m/s)
Ta = (SampleNum - 1) * Ts;                        % Chirp duration (s)
Tc = TxNum * Ta;                                  % Chirp repetition interval
B = K * Ta;                                       % Bandwidth (Hz)
fc = f_0 + B / 2;                                 % Center frequency (Hz)
lambda = c / fc;                                  % Wave length (m)
range_res = c / (2 * B);                          % Range resolution (m)

if ndims(data) == 4
    [SampleNum, ChirpNum, RxNum, TxNum] = size(data);
    ArrayNum = TxNum * RxNum;
    data3d = reshape(data, [SampleNum, ChirpNum, ArrayNum]);
else
    [SampleNum, ChirpNum, ArrayNum] = size(data);
    data3d = data;
end

range_axis = (0:SampleNum - 1) * range_res;
velocity_axis = (-ChirpNum / 2:ChirpNum / 2 - 1) * lambda / (2 * Tc * ChirpNum);

%% range FFT
rangeWin = hanning(SampleNum);
rangeWin3D = repmat(rangeWin, 1, ChirpNum, ArrayNum);
rangeData = data3d .* rangeWin3D;
rangeFFTOut = fft(rangeData, [], 1);

%% doppler FFT
dopplerWin = hanning(ChirpNum).';
dopplerWin3D = repmat(dopplerWin, SampleNum, 1, ArrayNum);
dopplerData = rangeFFTOut .* dopplerWin3D;
dopplerFFTOut = fftshift(fft(dopplerData, [], 2), 2);

accumulateRD = squeeze(sum(abs(dopplerFFTOut), 3)) / sqrt(ArrayNum);

%% plotting
if IsPlot
    figure
    pcolor(velocity_axis, range_axis, abs(accumulateRD))
    shading interp
    xlabel('Velocity (m/s)')
    ylabel('Range (m)')
    title('Range-Doppler Map')
    colorbar
    drawnow
end

end
