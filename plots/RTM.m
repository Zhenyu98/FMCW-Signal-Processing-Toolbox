%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2023 Southwest University, Chongqing
% College of Electronic and Information Engineering
% Any way use this code for research must retain the above copyright notice
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu         (feedback email:zheny_wu@163.com)
% Advisor             : Prof. Chuandong Li
% Code name           : RTM.m                  
% Date & time         : Oct. 27 2023 10:15                    
% Version             : 1.8                                  
% Purpose             : Range-Time Map for mmw radar l
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc;
clear;
close all;
%% Import raw data
% load("0404walk.mat");
% load('sim_data.mat');
load('walk1.mat');
[adc,frame,arr]= size(data3d);
% 
% % combine the slow time axis
% data3d = reshape(data4d, [adc frame Tx*Rx]); 
% 
% % change the dimension order
% data3d = permute(data3d, [2 1 3]); 

%% Define parameters
% common paramters
c = physconst('lightspeed');
tI = 4.5225e-10; % Instrument delay for range calibration 

% parameters of sensor (IWR 1642)
nFFTtime = 256;    % Number of FFT points for Range-FFT
nSample = 256;      % Number of sampling points for a Chirp
f0 = 77*1e9;        % Starting frequency (GHz)
K = 70.295*1e12;    % Slope of LFM (MHz/us)
fS = 5000*1e3;      % Sampling rate (sps) for the fast time
TS = 1/fS;          % Sampling period
T = (nSample-1)*TS;
B = K*TS;
% B = K*T;


np = frame;  % Number of sampling points for the slow time
% axis parameters
slow_time = T*np*Tx;  % Sampling rate (sps) for the slow time
time = linspace(0,slow_time,np);
dr = c/2/B;
L = 1:nFFTtime;
range = dr*(L-B*tI*nFFTtime)/nFFTtime;
plot(range,abs(fft(data3d(1,:,4),nFFTtime)));

%% Range FFT
Rangefft = zeros(np,nFFTtime);
win = hamming(nSample)'; % 使用汉明窗减少频谱泄露
for t = 1:np
 data3d(t,:,4) = data3d(t,:,4).*win; 
end
for t = 1:np
 Rangefft(t,:) = fft(data3d(t,:,4),nFFTtime); 
end

% Remove DC Term
% static filter
RangeRemoveDC = zeros(np,nFFTtime);
avg = sum(Rangefft)/np; % average range vector (slow time)
% If target is static (i,e, DC term), abs(avg) is very big 
% If target is not static in slow time np, abs(avg) is very small
for t=1:np
    RangeRemoveDC(t,:) = Rangefft(t,:)-avg;
end
hold on; plot(range,abs(RangeRemoveDC(1,:)));
legend('Original','Remove DC');

% Turn to power (dB) 
Power = 20*log10(abs(RangeRemoveDC)); 

%% Display Range-Time Image
figure
pcolor(time,range,Power');
% use shading to remove the grid
shading interp;
xlabel('Time(s)')
ylabel('Range (m)')
title('Range-Time Image')
clim = get(gca,'CLim');
% set(gca,'CLim',clim(2) + [-80 0]);
colorbar
drawnow;
