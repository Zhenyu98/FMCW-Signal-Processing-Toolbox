%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2023 Southwest University, Chongqing
% College of Electronic and Information Engineering
% Any way use this code for research must retain the above copyright notice
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu         (feedback email:zheny_wu@163.com)
% Advisor             : Prof. Chuandong Li
% Code name           : RAM.m
% Date & time         : April 2024
% Version             : 1.5
% Purpose             : Range-Angle Map for mmw radar
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc;
clear;
close all;
%% Import raw data
sensorParams.Start_Freq_GHz = 77; 
sensorParams.Slope_MHzperus = 15;
sensorParams.Sampling_Rate_ksps = 25500;
sensorParams.Adc_Start_Time_us = 4.66;
sensorParams.Frame_Repetition_Period_ms= 80;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 2560;
sensorParams.TxNum = 1;
sensorParams.RxNum = 8;

% tagert ranges and velocities and angles
targetParams.amplitude = [12 13 0 0];        % Target amplitudes (dB)
targetParams.range = [50 100 0 0];           % Target ranges (m)
targetParams.velocity = [0 0 0 0];           % Target velocities (m/s)
targetParams.azimuth = [-15 10 0 0];        % Target azimuth angles (degree)
targetParams.elevation = [0 0 0 0];          % Target elevation angles (degree)
M = length(targetParams.range);              % Number of targets

% global c f_0 K Ts nSample
f_0 = sensorParams.Start_Freq_GHz*1e9;          % Starting frequency (Hz)
K = sensorParams.Slope_MHzperus*1e12;           % Slope (MHz/us)
Fs = sensorParams.Sampling_Rate_ksps*1e3;       % Sampling rate (sps)
Ts = 1/Fs;                                      % Sample interval (s)
SampleNum = sensorParams.Samples_per_Chirp;     % Number of ADC samples
TxNum = sensorParams.TxNum;                     % Number of Tx antennas
RxNum = sensorParams.RxNum;                     % Number of Rx antennas

c = physconst('lightspeed');                    % Speed of light (m/s)
fc = 77*1e9;                                    % Center frequency (Hz)

% calculate duration (Ta Tc TF)
ChirpNum = sensorParams.Frame;          % Pulse number / chirp number
ArrayNum = TxNum*RxNum;                 % Number of Antenna Array
lambda = c/fc;                          % Wave length (m)
Ta = (SampleNum-1) * Ts;                  % Chirp duration (s) before TDM
Tc = TxNum * Ta;                        % Chirp duration (s) after TDM
TF = Tc*ChirpNum;                       % Frame duration (s)
d = 1e-3;                               % Antenna spacing (m)
B = Ta*K;
% % % Format of data : nSample x PulseNum x TxNum x RxNum
[data,range_res] = RadarCubeGenerate(sensorParams,targetParams);

% combine the array axis with TDM
[SampleNum, ChirpNum, Rx, Tx] = size(data);
arrNum = Tx * Rx;
data3d = reshape(data, [SampleNum, ChirpNum, arrNum]);

% load("sim_data.mat")
% [SampleNum, ChirpNum, Rx, Tx] = size(data);
% data3d = reshape(data, [SampleNum, ChirpNum, Rx*Tx]);

% load("sim_data1.mat")
% data3d = RDC;

%% Define parameters


% axis parameters
FFTpoints = 256;        % Number of FFT points for angle-FFT

eta = linspace(-pi, pi, FFTpoints); % 频域网格
angle = asind(eta / 2 / pi * 2); % angle axis

nFFTtime = 256;    % Number of FFT points for Range-FFT
range_res = c/2/B
range = range_res * (1:SampleNum);

%% Range FFT
Rangefft = zeros(nFFTtime,ChirpNum,ArrayNum);
win = hanning(SampleNum); % add window to reduce the spectrum leakage

for a = 1:ArrayNum
    for t = 1:ChirpNum
        Rangefft(:,t,a) = fft(data3d(:,t,a),nFFTtime);
    end
end

plot(abs(Rangefft(:,1,1)))
[~,pksIdx] = findpeaks(abs(Rangefft(:,1,1)),'MinPeakDistance',0.5,'MinPeakHeight',100);
pk = pksIdx(2);

% Remove DC Term
% static filter
RangeRemoveDC = zeros(nFFTtime,ChirpNum,ArrayNum);
avg = sum(Rangefft,2)/ChirpNum; % average range vector (slow time)
for a = 1:ArrayNum
    for t=1:ChirpNum
        RangeRemoveDC(:,t,a) = Rangefft(:,t,a)-avg(:,1,a);
    end
end



% traditional method (angle-FFT)
RangeAngle =  squeeze(sum(Rangefft(:,:,:),2)); % choose the certain frame

win = hanning(ArrayNum); % add window to reduce the spectrum leakage
for r = 1:SampleNum
    RangeAngle(r,:) = RangeAngle(r,:).*win';
end
RangeAngleMat = fftshift(fft(RangeAngle,FFTpoints,2),2);

% MUSIC algorithm
M = 1; % number of sources
TimeAngle =  squeeze(Rangefft(pk,:,:)); % choose the certain frame
[PoutMusic1] = DOA_MUSIC(TimeAngle.', M, angle);

% MUSIC Range-AoA map
for i= 1:SampleNum
    rangebin =  squeeze(Rangefft(i,:,:)); % choose the certain range
    [PoutMusic,RX] = DOA_MUSIC(rangebin.', M, angle);
    RangeAngleMat2(i,:) = PoutMusic;
end

% numCPI = 10;
% RDMs = zeros(SampleNum,ChirpNum/numCPI,ArrayNum,numCPI);
% for i = 1:numCPI
%     RD_frame = data3d(:,(i-1)*ChirpNum+1:i*ChirpNum,:);
%     RDMs(:,:,:,i) = fftshift(fft2(RD_frame,SampleNum,SampleNum),2);
% end

% for i= 1:SampleNum
%     for L = 1:numCPI
%     end
%     rangebin =  squeeze(sum(Rangefft(i,:,:),2)); % choose the certain range
%     [PoutMusic] = DOA_MUSIC(rangebin.', M, angle);
%     RangeAngleMat2(i,:) = PoutMusic;
% end

% Turn to power (dB)
Power = (abs(RangeAngleMat));


%% Display Range-Angle Image
figure
mesh(angle,range,Power);
% use shading to remove the grid
% shading interp;
xlabel('Angle (degree)')
ylabel('Range (m)')
title('Range-Angle Image')
clim = get(gca,'CLim');
% set(gca,'CLim',clim(2) + [-80 0]);
colorbar
drawnow;

% Display Range-Angle Image in MUSIC
figure
mesh(angle,range,abs(RangeAngleMat2));
% use shading to remove the grid
% shading interp;
xlabel('Angle (degree)')
ylabel('Range (m)')
title('Range-Angle Image in MUSIC')
clim = get(gca,'CLim');
% set(gca,'CLim',clim(2) + [-80 0]);
colorbar
drawnow;


figure
plot(angle,abs(RangeAngleMat(pk,:)));
hold on;
plot(angle,abs(PoutMusic1));
legend('angle FFT','MUSIC');
title('Angle estimate using MUSIC and traditional method');

% turn to cartesian coordinates
X = range'*cosd(angle);
Y = range'*sind(angle);

figure
pcolor(Y, X, Power);
shading interp;
ylabel('range (m)')
xlabel('azimuth (m)')
colorbar;
title('Range-Angle Image in Cartesian coordinates');

figure
pcolor(Y, X, abs(RangeAngleMat2));
shading interp;
ylabel('range (m)')
xlabel('azimuth (m)')
colorbar;
title('Range-Angle Image in Cartesian coordinates using MUSIC');




function [PoutMusic, RX] = DOA_MUSIC(X, P, thetaGrids)
  % X: 输入信号 arrNum * ChirpNum
  % P: 信源数
  % thetaGrids: 角度网格 
  % PoutMusic: 输出功率谱
  numCPI = 5;
  M = size(X, 1); % 天线数
  snap = size(X, 2); % 快拍数
  
  numChirps = snap/numCPI;
  RX = zeros(M,M);
  for i =1:numCPI
      Xs = sum(X(:,(i-1)*numChirps+1:i*numChirps),2);
      RX = RX + Xs * Xs' / numCPI; % 协方差矩阵
  end
  
  [V, D] = eig(RX); % 特征值分解
  eig_value = real(diag(D)); % 提取特征值
  [~, I] = sort(eig_value, 'descend'); % 排序特征值
  EN = V(:, I(P+1:end)); % 提取噪声子空间
  
  PoutMusic = zeros(1, length(thetaGrids));
  
  for id = 1 : length(thetaGrids)
      atheta_vec = exp(1j * 2 * pi * [0:M-1]' * 1 / 2 * sind(thetaGrids(id))); % 导向矢量
      PoutMusic(id) = ((1 / (atheta_vec' * EN * EN' * atheta_vec))) ; % 功率谱计算
  end
end
