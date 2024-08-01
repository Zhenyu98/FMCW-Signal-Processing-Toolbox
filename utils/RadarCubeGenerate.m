function [data,range_res] = RadarCubeGenerate(sensorParams,targetParams)
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2024 Southwest University, Chongqing
% College of Electronic and Information Engineering
% Any way use this code for research must retain the above copyright notice
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu         (feedback email:zheny_wu@163.com)
% Advisor             : Prof. Chuandong Li
% Code name           : RadarCubeGenerate.m                  
% Date & time         : April 2024                
% Version             : 1.0                                
% Purpose             : Generate the radar data cube
% -------------------------------------------------------------------------
% Format of data      : nSample x PulseNum x TxNum x RxNum
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parameters of FMCW radar
f_0 = sensorParams.Start_Freq_GHz*1e9;          % Starting frequency (Hz)
K = sensorParams.Slope_MHzperus*1e12;           % Slope (MHz/us)
Fs = sensorParams.Sampling_Rate_ksps*1e3;       % Sampling rate (sps)
Ts = 1/Fs;                                      % Sample interval (s)
nSample = sensorParams.Samples_per_Chirp;       % Number of ADC samples
TxNum = sensorParams.TxNum;                     % Number of Tx antennas
RxNum = sensorParams.RxNum;                     % Number of Rx antennas

c = physconst('lightspeed');                    % Speed of light (m/s)
fc = 79*1e9;                                    % Center frequency (Hz)

% calculate duration (Ta Tc TF) 
PulseNum = sensorParams.Frame;          % Pulse number / chirp number
ArrayNum = TxNum*RxNum;                 % Number of Antenna Array
lambda = c/fc;                          % Wave length (m)
Ta = (nSample-1) * Ts;                    % Chirp duration (s) before TDM
Tc = TxNum * Ta;                        % Chirp duration (s) after TDM
TF = Tc*PulseNum;                       % Frame duration (s)
d = 1e-3;                               % Antenna spacing (m)

%% Parameters of target
sigma = targetParams.amplitude;                       % Target RCS (m^2)
R = targetParams.range;                         % Target ranges (m)
V = targetParams.velocity;                      % Target velocities (m/s)
Azimuth = targetParams.azimuth;                 % Target azimuth angles (degree)
Elevation = targetParams.elevation;             % Target elevation angles (degree)
M = length(R);                                  % Number of targets

% calculate the range, velocity and angle resolution
range_res = c / (2 * K*Ta);        % 距离分辨率
disp('距离分辨率（单位：m）:');
disp(range_res);

doppler_res = lambda / (2 * TF); % 多普勒分辨率
disp('速度分辨率（单位：m/s）:');
disp(doppler_res);
% 生成所有可能的目标对组合的平均方位角
[theta1, theta2] = meshgrid(Azimuth, Azimuth);
theta_bar = (theta1 + theta2) / 2;

% 计算角度分辨率
angle_res = 2 * asind(lambda ./ (2 * ArrayNum * d * cosd(theta_bar)));

% 显示结果
disp('角度分辨率矩阵（单位：度）:');
disp(angle_res);

% target radar in cartesian coordinates
X = R .* cosd(Elevation) .* sind(Azimuth);
Y = R .* cosd(Elevation) .* cosd(Azimuth);
Z = R .* sind(Elevation);

% define transmit signal for a chirp
St = zeros(1,nSample); 
for tIdex = 1:nSample
    t = (tIdex - 1) * Ts;
    St(tIdex) = exp(1i * 2 * pi * (f_0 * t + 0.5 * K * t^2));
end



% the receive signal
% format: nSample x PulseNum x TxNum x RxNum
Sr = zeros(nSample,PulseNum,RxNum,TxNum);
for targetIdex = 1:M 
    Srtemp = zeros(nSample,PulseNum,RxNum,TxNum);
    InitRange = R(targetIdex);
    for tIdex = 1:nSample
        for pIdex = 1:PulseNum
            for txIdex = 1:TxNum
                for rxIdex = 1:RxNum
                    % calculate delay
                    fastTime = (tIdex - 1) * Ts;
                    slowTime = (pIdex - 1) * Tc;
                    Txdelay = (txIdex - 1) * Ta;
                    t = fastTime + slowTime + Txdelay;
                    % calculate instant range
                    InstantRange = InitRange + V(targetIdex) * t;
                    % calculate the differential ranges for receivers
                    Rxdelay = (rxIdex - 1)*d*sind(Azimuth(targetIdex));
                    tua = 2 * (InstantRange +Rxdelay) / c;

                    % calculate the received signal
                    Srtemp(tIdex,pIdex,rxIdex,txIdex) = sigma(targetIdex) * exp(1i * 2 * pi * (f_0 * (fastTime-tua) + 0.5 * K * (fastTime-tua)^2)); 
                end
            end
        end
    end
    % multi-target signal superposition
    Sr = Sr + Srtemp;
end

% mix the transmit signal and receive signal
    Sif = zeros(nSample,PulseNum,RxNum,TxNum);
    for tIdex = 1:nSample
        for pIdex = 1:PulseNum
            for txIdex = 1:TxNum
                for rxIdex = 1:RxNum
                    Sif(tIdex,pIdex,rxIdex,txIdex) = St(tIdex) * conj(Sr(tIdex,pIdex,rxIdex,txIdex));
                end
            end
        end
    end


% range profile
% range_axis = range_res*(1:nSample); % range axis
% range_profile = abs(fft(Sif(:,1,1,1),1024));
% range_axis = linspace(0,range_res*(nSample-1),length(range_profile));
% % range_axis = range_res:range_res:range_res*256;
% plot(range_axis,range_profile,'LineWidth',1.5,'Color','r')


data = Sif;
save sim_data.mat data

end
 