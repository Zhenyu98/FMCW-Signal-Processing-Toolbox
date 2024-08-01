function RDM(data4d,K,Tc,Ts,lambda)

[SampleNum, ChripNum, Tx, Rx] = size(data4d);
arrNum = Tx * Rx;
data3d = reshape(data4d, [SampleNum, ChripNum, arrNum]);

% Vectorized FFT method for Range-Doppler Map generation
rangeWin = hanning(SampleNum);
rangeWin3D = repmat(rangeWin, 1, ChripNum, arrNum); % 扩充与rangeData数据一致
rangeData = data3d .* rangeWin3D ; % 距离维加窗
rangeFFTOut = fft(rangeData, [], 1) ; % 对距离维做FFT【FFT补偿+汉宁窗补偿】

% 多普勒维FFT
dopplerWin = hanning(ChripNum)'; % 汉宁窗
dopplerWin3D = repmat(dopplerWin, SampleNum, 1, arrNum); % 扩充与dopplerData数据一致
dopplerData = rangeFFTOut .* dopplerWin3D; % 多普勒加窗
dopplerFFTOut = fftshift(fft(dopplerData, [], 2),2) ; % 对多普勒维做FFT【FFT补偿+汉宁窗
accumulateRD = squeeze(sum(abs(dopplerFFTOut), 3)) / sqrt(size(dopplerFFTOut, 3));
Power = 20 * log10(accumulateRD);

% Display a Range-Doppler Map
T = (SampleNum-1) * Ts;
B = K * T;
f = -ChripNum / 2 : ChripNum / 2 - 1;
slowtime = Tc*ChripNum;
speed = f * lambda / (2 * slowtime);
c = physconst('lightspeed');                    % Speed of light (m/s)
dr = c / (2 * B);
range = dr * (1:SampleNum);
figure;
pcolor(speed, range, Power);
shading interp;
xlabel('Speed (m/s)');
ylabel('Range (m)');
clim = get(gca, 'CLim');
set(gca, 'CLim', clim(2) + [-80, 0]);
colorbar;
drawnow;
end