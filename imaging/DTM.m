function [DopplerTimeMap, velocity_axis, time_axis] = DTM(data, sensorParams, IsPlot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : DTM.m
% Date & time         : Jul. 2026
% Version             : 2.0
% Purpose             : Doppler-Time Map (per-frame) for framed FMCW radar
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Doppler-domain sibling of RTM.m (Range-Time Map) for FRAMED data: each radar
% frame is one Doppler snapshot. Per frame we range-FFT, pick the strongest
% range bin (follows range migration), Doppler-FFT the in-frame slow time, and
% place that column at the frame time (frame index x frame repetition period).
% This is the physically correct Doppler-time map when frames are separated by
% an inter-frame gap. For a CONTINUOUS capture (no gaps), use MDS.m (slow-time
% STFT micro-Doppler spectrogram) instead.
%
% data         : framed radar cube, [Sample x ChirpPerFrame x FrameNum] or
%                [Sample x ChirpPerFrame x Array x FrameNum]. Last dim = frames.
% sensorParams : standard sensor struct; time axis uses
%                sensorParams.Frame_Repetition_Period_ms if present (else the
%                in-frame slow-time span, with a warning).
% IsPlot       : plot the map when true (default true).
% DopplerTimeMap : power map, [Doppler x FrameNum].
% velocity_axis  : radial velocity axis (m/s), same convention as RDM.m.
% time_axis      : frame time axis (s).

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
Tc = TxNum * Ta;                                  % Chirp repetition interval (in-frame slow-time period)
B = K * Ta;                                       % Bandwidth (Hz)
fc = f_0 + B / 2;                                 % Center frequency (Hz)
lambda = c / fc;                                  % Wave length (m)

%% reshape to [Sample x ChirpPerFrame x Array x FrameNum]
if ndims(data) == 4
    [~, ChirpNum, ~, FrameNum] = size(data);
elseif ndims(data) == 3
    [nSmp, ChirpNum, FrameNum] = size(data);
    data = reshape(data, [nSmp, ChirpNum, 1, FrameNum]);
else
    error('DTM:data', 'data must be [Sample x ChirpPerFrame x FrameNum] or [Sample x ChirpPerFrame x Array x FrameNum].');
end

%% per-frame Doppler FFT -> one column each (RTM.m Doppler version)
dopplerZoom = 4;                                  % zero-padding for a smoother Doppler axis
nDopFFT = dopplerZoom * ChirpNum;
dopplerWin = hann(ChirpNum).';                    % in-frame slow-time window

DopplerTimeMap = zeros(nDopFFT, FrameNum);
for frameIdex = 1:FrameNum
    frameCube = data(:, :, :, frameIdex);                    % [Sample x Chirp x Array]
    rangeFFT = fft(frameCube, [], 1);                        % range FFT per chirp
    rangePower = squeeze(sum(abs(rangeFFT).^2, 3));          % [Sample x Chirp]
    if ChirpNum == 1; rangePower = rangePower(:); end
    [~, targetBin] = max(mean(rangePower, 2));               % strongest bin this frame (range migration)
    slowTime = squeeze(sum(rangeFFT(targetBin, :, :), 3));   % array-summed slow-time series
    slowTime = slowTime(:).' - mean(slowTime(:));            % remove DC (static clutter)
    spec = fftshift(fft(slowTime .* dopplerWin, nDopFFT));
    DopplerTimeMap(:, frameIdex) = abs(spec).^2;
end

%% axes (velocity convention identical to RDM.m: v = f_d * lambda / 2)
velocity_axis = ((-nDopFFT / 2):(nDopFFT / 2 - 1)) / nDopFFT * (lambda / (2 * Tc));
if isfield(sensorParams, 'Frame_Repetition_Period_ms')
    framePeriod = sensorParams.Frame_Repetition_Period_ms * 1e-3;  % wall-clock frame spacing
else
    framePeriod = ChirpNum * Tc;                              % fallback: no inter-frame gap
    warning('DTM:framePeriod', 'sensorParams.Frame_Repetition_Period_ms missing; using in-frame span %.4f s as frame spacing.', framePeriod);
end
time_axis = (0:FrameNum - 1) * framePeriod;

%% plotting
if IsPlot
    figure
    PowerdB = 10 * log10(DopplerTimeMap / max(DopplerTimeMap(:)) + eps);   % normalize to peak 0 dB
    imagesc(time_axis, velocity_axis, PowerdB)
    axis xy
    clim([-40, 0])
    xlabel('Time (s)')
    ylabel('Radial velocity (m/s)')
    title('Doppler-Time Map')
    colorbar
    drawnow
end

end
