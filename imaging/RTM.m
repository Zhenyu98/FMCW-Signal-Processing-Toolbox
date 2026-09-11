function [] = RTM(data,np,sensorParams)
% data:Data to be processed
% np: Number of sampling points for the slow time
% sensorParams: IWR1642 system parameter
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
% Purpose             : Range-Time Map for mmw radar 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Define parameters
% common paramters
c = physconst('lightspeed');
tI = 4.5225e-10; % Instrument delay for range calibration 

% parameters of sensor (IWR 1642)
Zoom =4;
nSample = sensorParams.Samples_per_Chirp;      % Number of sampling points for a Chirp
nFFTtime = nSample*Zoom;    % Number of FFT points for Range-FFT
f0 = sensorParams.Start_Freq_GHz*1e9;        % Starting frequency (GHz)
fc = 79*1e9;        % Starting frequency (GHz)
K = sensorParams.Slope_MHzperus*1e12;    % Slope of LFM (MHz/us)
fS = sensorParams.Sampling_Rate_ksps*1e3;      % Sampling rate (sps) for the fast time
TS = 1/fS;          % Sampling period
T = (nSample)*TS;
B = K*TS;

% axis parameters
dt_slow = 10/3200;  % Sampling rate (sps) for the slow time
% np = frame*nframe;  % Number of sampling points for the slow time
time = 0:dt_slow:dt_slow*(np-1);
dr = c/2/B;
L = 1:nFFTtime;
range = dr*(L-B*tI*nFFTtime)/nFFTtime;
plot(range,abs(fft(data(100,:,4),nFFTtime)));

%% Range FFT
Rangefft = zeros(np,nFFTtime);
for t = 1:np
 Rangefft(t,:) = (fft(data(t,:,4),nFFTtime)); 
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
hold on; plot(range,abs(RangeRemoveDC(100,:)));

% Range compression
RangeTimeMat = RangeRemoveDC.*conj(RangeRemoveDC);

hold on; plot(range,abs(RangeTimeMat(100,:)));
% Turn to power (dB) 
Power = 20*log10(abs(RangeTimeMat)); 

%% Display Range-Time Image
figure();
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
end