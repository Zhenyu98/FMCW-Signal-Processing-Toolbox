%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : generate_algorithm_gallery.m
% Date & time         : Sep. 2026
% Version             : 1.0
% Purpose             : Demonstrate DOA, source count, DTM, two-ray and bounds
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Run from project root: run('docs/generate_algorithm_gallery.m')
% Demos clear the workspace and close figures. Save existing work first.
%
%% success criteria (declared before running the experiments)
% 1. All spatial spectra are finite/nonnegative on the same noisy observation.
%    Newton_NOS must recover 3 sources in this fixed high-SNR scene. The three
%    MUSIC/IAA peaks must lie within 1 degree of truth, used only for checks.
% 2. DTM must produce one column per frame and peak errors < 2 Doppler bins.
% 3. The existing two-ray validation must pass its geometry/peak assertions.
% 4. Original ZZB demo parameters and trial count are preserved; all bounds
%    must be finite/positive, with low-SNR ZZB near APB and high-SNR near CRB.
% These are illustrative scenarios, not a statistical method ranking.

clc
clear
close all
rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'startup.m'))

%% common noisy array observation and source-number estimation
rng(2026)
ArrayNum = 12;
SnapshotNum = 128;
trueAngles = [-25, 0, 25];
SNR_dB = 15;
Atrue = exp(1j * pi * (0:ArrayNum-1).' * sind(trueAngles));
S = (randn(3, SnapshotNum) + 1j * randn(3, SnapshotNum)) / sqrt(2);
noise = (randn(ArrayNum, SnapshotNum) + 1j * randn(ArrayNum, SnapshotNum)) / sqrt(2);
X = sqrt(10^(SNR_dB/10)) * Atrue * S + noise;
Rxx = X * X' / SnapshotNum;
eigenvalues = sort(real(eig(Rxx)), 'descend');
sourceCount = Newton_NOS(eigenvalues, 1);
assert(sourceCount == 3, 'Source-count demo did not recover three sources.')

%% existing FFT, MUSIC, IAA implementations share X
cfgDOA.FFTNum = 1024;
fftOut = DOA_FFT(X, cfgDOA);
fftSpectrum = sqrt(mean(abs(fftOut).^2, 2));
fftAngles = asind(((0:cfgDOA.FFTNum-1) - cfgDOA.FFTNum/2) * 2/cfgDOA.FFTNum);
thetaGrids = -60:0.25:60;
musicSpectrum = abs(DOA_MUSIC(X, sourceCount, thetaGrids));
A = exp(1j * pi * (0:ArrayNum-1).' * sind(thetaGrids));
iaaParams.mode = 'APES';
iaaParams.iter_num = 12;
iaaParams.threshold = 1e-6;
iaaSpectrum = real(DOA_IAA(X, A, iaaParams));
assert(all(isfinite([fftSpectrum(:); musicSpectrum(:); iaaSpectrum(:)])))
assert(all(iaaSpectrum >= 0))
[~, musicIdx] = findpeaks(musicSpectrum, 'SortStr', 'descend', 'NPeaks', 3, 'MinPeakDistance', 20);
[~, iaaIdx] = findpeaks(iaaSpectrum, 'SortStr', 'descend', 'NPeaks', 3, 'MinPeakDistance', 20);
musicError = max(abs(sort(thetaGrids(musicIdx)) - trueAngles));
iaaError = max(abs(sort(thetaGrids(iaaIdx)) - trueAngles));
assert(musicError <= 1 && iaaError <= 1, 'Spatial peak check failed.')
fig = figure('Color', 'w', 'Position', [80, 80, 1440, 550]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact')
nexttile
plot(fftAngles, fftSpectrum/max(fftSpectrum), 'Color', [0.55, 0.60, 0.65], 'LineWidth', 1.8)
hold on
plot(thetaGrids, musicSpectrum/max(musicSpectrum), 'Color', [0, 0.45, 0.70], 'LineWidth', 1.8)
plot(thetaGrids, iaaSpectrum/max(iaaSpectrum), '--', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.8)
for targetIdex = 1:3
    xline(trueAngles(targetIdex), ':', 'HandleVisibility', 'off')
end
xlim([-50, 50])
ylim([0, 1.08])
xlabel('Azimuth (degree)')
ylabel('Normalized spectrum')
title('One observation, three spatial spectra')
legend('FFT', 'MUSIC', 'IAA-APES', 'Location', 'northwest')
grid on
nexttile
semilogy(1:ArrayNum, eigenvalues, '-o', 'Color', [0, 0.45, 0.70], 'LineWidth', 2)
hold on
xline(sourceCount+0.5, '--', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5)
xlabel('Eigenvalue index')
ylabel('Covariance eigenvalue')
title(sprintf('Newton source-count estimate: %d', sourceCount))
xticks(1:ArrayNum)
grid on
set(findall(fig, 'Type', 'axes'), 'FontName', 'Arial', 'FontSize', 14)
exportgraphics(fig, fullfile(fileparts(mfilename('fullpath')), 'assets', 'gallery_doa_source_count.png'), 'Resolution', 160)
fprintf('GALLERY_DOA sourceCount=%d MUSIC_maxErr=%.3f IAA_maxErr=%.3f deg\n', sourceCount, musicError, iaaError)

%% framed moving-target data for DTM
clear sensorParams targetParams
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 10;
sensorParams.Sampling_Rate_ksps = 1000;
sensorParams.Samples_per_Chirp = 128;
sensorParams.Frame = 128;
sensorParams.Frame_Repetition_Period_ms = 80;
sensorParams.TxNum = 1;
sensorParams.RxNum = 1;
sensorParams.SNR_dB = 25;
FrameNum = 40;
frameTime = (0:FrameNum-1) * 0.08;
omega = 2*pi/2.5;
trueVelocity = 0.8 + 0.5*sin(omega*frameTime);
trueRange = 5 + 0.8*frameTime + 0.5/omega*(1-cos(omega*frameTime));
radarParams = RadarParameterGenerate(sensorParams);
framedData = zeros(128, 128, FrameNum);
for tIdex = 1:FrameNum
    targetParams.range = trueRange(tIdex);
    targetParams.velocity = trueVelocity(tIdex);
    targetParams.azimuth = 0;
    targetParams.elevation = 0;
    targetParams.amplitude = 1;
    frameCube = RadarCubeGenerate(targetParams, radarParams);
    framedData(:, :, tIdex) = frameCube(:, :, 1, 1);
end
[DopplerTimeMap, velocity_axis, time_axis] = DTM(framedData, sensorParams, false);
assert(size(DopplerTimeMap, 2) == FrameNum)
[~, velocityIdx] = max(DopplerTimeMap, [], 1);
velocityError = max(abs(velocity_axis(velocityIdx) - trueVelocity));
velocityBin = abs(velocity_axis(2) - velocity_axis(1));
assert(velocityError < 2*velocityBin, 'DTM peak differs by more than two velocity bins.')
rangeTimeMap = squeeze(mean(abs(fft(framedData, [], 1)).^2, 2));
fig = figure('Color', 'w', 'Position', [80, 80, 1440, 550]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact')
nexttile
imagesc(time_axis, radarParams.range_axis, sqrt(rangeTimeMap/max(rangeTimeMap(:))))
axis xy
hold on
plot(frameTime, trueRange, 'w--', 'LineWidth', 1.3)
ylim([4.5, 8.5])
xlabel('Time (s)')
ylabel('Range (m)')
title('Range migration across radar frames')
cb = colorbar; cb.Label.String = 'Normalized amplitude';
nexttile
imagesc(time_axis, velocity_axis, sqrt(DopplerTimeMap/max(DopplerTimeMap(:))))
axis xy
hold on
plot(frameTime, trueVelocity, 'w--', 'LineWidth', 1.3)
ylim([0, 1.6])
xlabel('Time (s)')
ylabel('Velocity (m/s)')
title('DTM: velocity changes over time')
cb = colorbar; cb.Label.String = 'Normalized amplitude';
colormap(parula)
set(findall(fig, 'Type', 'axes'), 'FontName', 'Arial', 'FontSize', 14)
exportgraphics(fig, fullfile(fileparts(mfilename('fullpath')), 'assets', 'gallery_doppler_time.png'), 'Resolution', 160)
fprintf('GALLERY_DTM maxVelocityError=%.6f bin=%.6f m/s\n', velocityError, velocityBin)

%% official two-ray model and its apparent range peaks
rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'validation', 'validate_mathworks_two_ray_signal_source.m'))
fig = figure('Color', 'w', 'Position', [80, 80, 1440, 550]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact')
nexttile
radar = multipathParams.RadarPosition_m;
target = multipathParams.TargetPosition_m;
reflectionY = radar(2) + (target(2)-radar(2))*radar(3)/(radar(3)+target(3));
plot([radar(2),target(2)], [radar(3),target(3)], '-', 'Color', [0, 0.45, 0.70], 'LineWidth', 2)
hold on
plot([radar(2),reflectionY,target(2)], [radar(3),0,target(3)], '--', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 2)
yline(0, 'k-', 'HandleVisibility', 'off')
scatter([radar(2),target(2)], [radar(3),target(3)], 65, 'k', 'filled', 'HandleVisibility', 'off')
text(radar(2)+0.4,radar(3),'Radar')
text(target(2)+0.4,target(3),'Target')
xlabel('Horizontal distance (m)')
ylabel('Height (m)')
title('Direct and ground-reflected paths')
legend('Direct path', 'Reflected path', 'Location', 'northwest')
xlim([-1,13])
ylim([-1,23])
grid on
nexttile
plot(radarParams.range_axis, rangeProfile/max(rangeProfile), 'LineWidth', 1.8, 'Color', [0, 0.45, 0.70])
hold on
for pathIdex = 1:numel(multipathInfo.ExpectedApparentRange_m)
    xline(multipathInfo.ExpectedApparentRange_m(pathIdex), '--', 'Color', [0.85, 0.33, 0.10]);
end
xlim([12,33])
ylim([0,1.08])
xlabel('Apparent range (m)')
ylabel('Normalized amplitude')
title('One target, multiple range peaks')
grid on
set(findall(fig, 'Type', 'axes'), 'FontName', 'Arial', 'FontSize', 14)
exportgraphics(fig, fullfile(fileparts(mfilename('fullpath')), 'assets', 'gallery_two_ray.png'), 'Resolution', 160)
fprintf('GALLERY_TWO_RAY maxBinError=%d\n', max(binError))

%% original performance-bound demo: unchanged parameters and 1000 trials
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(rootDir, 'performance'))
rng(2026)
disp('GALLERY_BOUNDS_START original Main_ZZB_Demo parameters, 1000 trials')
run(fullfile(rootDir, 'performance', 'Main_ZZB_Demo.m'))
assert(all(isfinite([RAPB(:); RCRB(:); RZZB_Generalized(:); RZZB(:)])))
assert(all([RAPB(:); RCRB(:); RZZB_Generalized(:); RZZB(:)] > 0))
assert(abs(RZZB(1)/RAPB(1)-1) < 0.05, 'Low-SNR ZZB does not approach APB.')
assert(abs(RZZB(end)/RCRB(end)-1) < 0.05, 'High-SNR ZZB does not approach CRB.')
fig = gcf;
set(fig, 'Color', 'w', 'Position', [80, 80, 1300, 550])
title('DOA error bounds: from prior uncertainty to the high-SNR regime')
ylabel('Root error bound (degree)')
set(findall(fig, 'Type', 'axes'), 'FontName', 'Arial', 'FontSize', 14)
exportgraphics(fig, fullfile(fileparts(mfilename('fullpath')), 'assets', 'gallery_doa_bounds.png'), 'Resolution', 160)
fprintf('GALLERY_BOUNDS lowRatio=%.6f highRatio=%.6f trials=%d\n', RZZB(1)/RAPB(1), RZZB(end)/RCRB(end), num_MC)
disp('ALGORITHM_GALLERY_EXPORTED')
