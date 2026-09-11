function [RangeAngleFFT, range_axis, angle_axis] = RAM(data, sensorParams, FFTpoints, IsPlot)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : RAM.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Range-Angle Map using range FFT and angle FFT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 3 || isempty(FFTpoints)
    FFTpoints = 180;
end
if nargin < 4
    IsPlot = true;
end

%% define parameters
K = sensorParams.Slope_MHzperus * 1e12;           % Slope (Hz/s)
Fs = sensorParams.Sampling_Rate_ksps * 1e3;       % Sampling rate (Hz)
Ts = 1 / Fs;                                      % Sample interval (s)
SampleNum = sensorParams.Samples_per_Chirp;       % Number of ADC samples

c = physconst('lightspeed');                      % Speed of light (m/s)
Ta = (SampleNum - 1) * Ts;                        % Chirp duration (s)
B = K * Ta;                                       % Bandwidth (Hz)
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
% angle-FFT 输出在空间频率(sinθ)上等间距，与 fftshift bin 对齐 → asin 映射回角度
% sinGrid 的 *2 = 1/(d/λ)，对应半波长阵列 d = λ/2
sinGrid = ((0:FFTpoints - 1) - floor(FFTpoints / 2)) / FFTpoints * 2;  % [-1,1) 等间距 sinθ
angle_axis = asind(max(min(sinGrid, 1), -1));

%% range FFT
Rangefft = zeros(SampleNum, ChirpNum, ArrayNum);
win = hanning(SampleNum);
for a = 1:ArrayNum
    for t = 1:ChirpNum
        Rangefft(:, t, a) = fft(data3d(:, t, a) .* win, SampleNum);
    end
end

%% angle FFT
RangeAngle = squeeze(sum(Rangefft, 2));
winArray = hanning(ArrayNum);
for r = 1:SampleNum
    RangeAngle(r, :) = RangeAngle(r, :) .* winArray.';
end
RangeAngleFFT = fftshift(fft(RangeAngle, FFTpoints, 2), 2);

%% plotting
if IsPlot
    figure
    mesh(angle_axis, range_axis, abs(RangeAngleFFT))
    xlabel('Angle (degree)')
    ylabel('Range (m)')
    title('Range-Angle Map')
    colorbar
    drawnow
end

end
