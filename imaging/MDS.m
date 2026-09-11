function [MicroDopplerSpec, velocity_axis, time_axis] = MDS(data, sensorParams, IsPlot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : MDS.m
% Date & time         : Jul. 2026
% Version             : 1.0
% Purpose             : Micro-Doppler Spectrogram (slow-time STFT) for FMCW radar
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Continuous slow-time STFT micro-Doppler signature: pick the strongest range
% bin, then run a sliding-window FFT over the whole slow-time stream to show the
% fine time-frequency (radial-velocity) evolution (limb micro-Doppler ...).
% Use this for a CONTINUOUS capture (chirps at Tc, no inter-frame gaps). For
% gapped framed data (one Doppler snapshot per frame), use DTM.m instead.
%
% data         : radar cube, [Sample x SlowTime x Array] or [Sample x SlowTime x Rx x Tx].
%                SlowTime is the continuous chirp axis sampled at Tc.
% sensorParams : standard sensor struct (Start_Freq_GHz / Slope_MHzperus /
%                Sampling_Rate_ksps / Samples_per_Chirp / TxNum ...).
% IsPlot       : plot the spectrogram when true (default true).
% MicroDopplerSpec : power spectrogram, [Doppler x Time].
% velocity_axis    : radial velocity axis (m/s), same convention as RDM.m.
% time_axis        : slow-time axis (s) at each STFT window center.

if nargin < 3
    IsPlot = true;
end

%% define parameters (显式推导,风格同 RDM.m)
f_0 = sensorParams.Start_Freq_GHz * 1e9;          % Starting frequency (Hz)
K = sensorParams.Slope_MHzperus * 1e12;           % Slope (Hz/s)
Fs = sensorParams.Sampling_Rate_ksps * 1e3;       % Sampling rate (Hz)
Ts = 1 / Fs;                                      % Sample interval (s)
SampleNum = sensorParams.Samples_per_Chirp;       % Number of ADC samples
TxNum = sensorParams.TxNum;                       % Number of Tx antennas

c = physconst('lightspeed');                      % Speed of light (m/s)
Ta = (SampleNum - 1) * Ts;                        % Chirp duration (s)
Tc = TxNum * Ta;                                  % Chirp repetition interval (slow-time period)
B = K * Ta;                                       % Bandwidth (Hz)
fc = f_0 + B / 2;                                 % Center frequency (Hz)
lambda = c / fc;                                  % Wave length (m)

%% reshape to [Sample x SlowTime x Array]
if ndims(data) == 4
    [SampleNum, SlowTimeNum, RxNum, TxNum2] = size(data);
    data3d = reshape(data, [SampleNum, SlowTimeNum, RxNum * TxNum2]);
else
    [SampleNum, SlowTimeNum, ~] = size(data);
    data3d = data;
end
ArrayNum = size(data3d, 3);

%% range FFT, then pick the strongest range bin over the whole slow-time
rangeWin = hanning(SampleNum);
rangeWin3D = repmat(rangeWin, 1, SlowTimeNum, ArrayNum);
rangeFFTOut = fft(data3d .* rangeWin3D, [], 1);   % [Sample x SlowTime x Array]

rangePower = squeeze(sum(abs(rangeFFTOut).^2, 3));    % [Sample x SlowTime]
[~, targetBin] = max(mean(rangePower, 2));            % strongest range bin (energy over time)

% array-summed complex slow-time series at the target bin
slowTime = squeeze(sum(rangeFFTOut(targetBin, :, :), 3));
slowTime = slowTime(:).' - mean(slowTime(:));         % remove DC (static clutter)

%% slow-time STFT -> micro-Doppler spectrogram
winLen  = min(128, SlowTimeNum);                  % STFT window length (slow-time samples)
hopLen  = max(1, round(winLen / 4));              % 75% overlap
nDopFFT = 4 * winLen;                             % zero-padding for a smoother Doppler axis
stftWin = hann(winLen).';                         % slow-time window suppresses sidelobes

startIdx = 1:hopLen:(SlowTimeNum - winLen + 1);
MicroDopplerSpec = zeros(nDopFFT, numel(startIdx));
for k = 1:numel(startIdx)
    seg = slowTime(startIdx(k):startIdx(k) + winLen - 1) .* stftWin;
    MicroDopplerSpec(:, k) = fftshift(abs(fft(seg, nDopFFT)).^2);
end

%% axes (velocity convention identical to RDM.m: v = f_d * lambda / 2)
velocity_axis = ((-nDopFFT / 2):(nDopFFT / 2 - 1)) / nDopFFT * (lambda / (2 * Tc));
time_axis = (startIdx + winLen / 2 - 1) * Tc;     % slow-time at each window center

%% plotting
if IsPlot
    figure
    PowerdB = 10 * log10(MicroDopplerSpec / max(MicroDopplerSpec(:)) + eps);   % normalize to peak 0 dB
    pcolor(time_axis, velocity_axis, PowerdB)
    shading interp
    clim([-40, 0])
    xlabel('Time (s)')
    ylabel('Radial velocity (m/s)')
    title('Micro-Doppler Spectrogram')
    colorbar
    drawnow
end

end
