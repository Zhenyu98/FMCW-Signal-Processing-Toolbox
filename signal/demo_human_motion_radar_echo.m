%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : demo_human_motion_radar_echo.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Human motion FMCW radar echo simulation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% generate radar signal
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 10;
sensorParams.Sampling_Rate_ksps = 1000;
sensorParams.Samples_per_Chirp = 64;
sensorParams.Frame = 4096;                       % Chirps in one synthetic CPI
sensorParams.TxNum = 1;                          % Use 1Tx for clear micro-Doppler
sensorParams.RxNum = 1;
sensorParams.SNR_dB = 35;                        % Observation SNR (dB)

radarParams = RadarParameterGenerate(sensorParams);

%% define human trajectory
humanParams.Initial_Position_m = [0, 8.0, 0];    % Ground point [x, y, z]
humanParams.Body_Velocity_mps = [0.10, -1.00, 0]; % Walking direction
humanParams.Height_m = 1.75;
humanParams.Gait_Frequency_Hz = 2.0;
humanParams.Arm_Swing_m = 0.38;
humanParams.Leg_Swing_m = 0.42;
humanParams.Side_Sway_m = 0.04;
humanParams.Vertical_Bob_m = 0.03;

% The demo follows the same input idea as Boulic/Kinect/RealSense radar
% simulation: each body scatterer has a 3-D location at each chirp.
[Position_m, scatterAmp, humanInfo] = GenerateWalkingHumanScatterers(humanParams, radarParams);

targetParams.position_m = Position_m;            % ScatterNum x 3 x PulseNum
targetParams.amplitude = scatterAmp;             % ScatterNum x 1

radarParams = RadarParameterGenerate(sensorParams, targetParams);
rng(2026)
[data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);

disp('Human motion radar echo generation completed!')
disp(['data size: ', mat2str(size(data))])
disp(['scatterer number: ', num2str(size(targetParams.position_m, 1))])
disp(['simulation time: ', num2str(humanInfo.time_axis(end)), ' s'])
disp(['range resolution: ', num2str(radarParams.range_res), ' m'])
disp(['Doppler resolution: ', num2str(radarParams.doppler_res), ' m/s'])
if ~isempty(noiseInfo.SNR_dB)
    disp(['SNR: ', num2str(noiseInfo.SNR_dB), ' dB'])
end

%% range-Doppler and micro-Doppler processing
rxData = squeeze(data(:, :, 1, 1));              % SampleNum x PulseNum
rangeFFTOut = fft(rxData, radarParams.SampleNum, 1);
dopplerFFTOut = fftshift(fft(rangeFFTOut, radarParams.PulseNum, 2), 2);

scatterRange = squeeze(sqrt(sum(targetParams.position_m.^2, 2)));
rangeMin = min(scatterRange, [], 1);
rangeMax = max(scatterRange, [], 1);
rangeWindow = [min(rangeMin) - 0.8, max(rangeMax) + 0.8];
searchIdx = radarParams.range_axis >= rangeWindow(1) & ...
            radarParams.range_axis <= rangeWindow(2);

rangePower = abs(rangeFFTOut(searchIdx, :));
rangeSearchAxis = radarParams.range_axis(searchIdx);
[~, peakRangeIdx] = max(rangePower, [], 1);
peakRange = rangeSearchAxis(peakRangeIdx);

slowSignal = sum(rangeFFTOut(searchIdx, :), 1);
slowSignal = slowSignal - mean(slowSignal);
windowLen = 512;
overlapLen = 384;
nfft = 1024;
[spec, specTime, freqAxis] = SimpleSpectrogram(slowSignal, windowLen, overlapLen, nfft, radarParams.Tc);
velocityAxis = freqAxis * radarParams.lambda / 2;

%% validation
rangeInside = peakRange >= rangeMin - radarParams.range_res & ...
              peakRange <= rangeMax + radarParams.range_res;
rangeInsideRatio = mean(rangeInside);
radialVelocity = diff(scatterRange, 1, 2) / radarParams.Tc;
radialVelocitySpan = [min(radialVelocity(:)), max(radialVelocity(:))];
signalPower = mean(abs(data(:)).^2);
microDopplerPeak = max(abs(spec(:)));

disp(['range peak inside human envelope ratio: ', num2str(rangeInsideRatio)])
disp(['human radial velocity span: ', mat2str(radialVelocitySpan, 4), ' m/s'])

if signalPower <= 0 || ~isfinite(signalPower)
    error('Generated radar echo has invalid signal power.')
end
if rangeInsideRatio < 0.90
    error('Range peak sanity check failed. Please check the human trajectory or radar parameters.')
end
if microDopplerPeak <= 0 || ~isfinite(microDopplerPeak)
    error('Micro-Doppler sanity check failed.')
end

%% plotting and comparison
figure
hold on
plot3(squeeze(targetParams.position_m(:, 1, 1)), ...
      squeeze(targetParams.position_m(:, 2, 1)), ...
      squeeze(targetParams.position_m(:, 3, 1)), 'ko', 'LineWidth', 1.2)
plot3(squeeze(targetParams.position_m(:, 1, round(radarParams.PulseNum / 2))), ...
      squeeze(targetParams.position_m(:, 2, round(radarParams.PulseNum / 2))), ...
      squeeze(targetParams.position_m(:, 3, round(radarParams.PulseNum / 2))), 'bo', 'LineWidth', 1.2)
plot3(squeeze(targetParams.position_m(:, 1, end)), ...
      squeeze(targetParams.position_m(:, 2, end)), ...
      squeeze(targetParams.position_m(:, 3, end)), 'ro', 'LineWidth', 1.2)
plot3(humanInfo.body_center(:, 1), humanInfo.body_center(:, 2), humanInfo.body_center(:, 3), ...
      'k-', 'LineWidth', 1.5)
xlabel('X (m)')
ylabel('Y (m)')
zlabel('Z (m)')
legend('Start pose', 'Middle pose', 'End pose', 'Body trajectory')
title('Human Scatterer Trajectory')
grid on
axis equal
view([-35, 20])

figure
rdMap = abs(dopplerFFTOut);
rdMap_dB = 20 * log10(rdMap.' / max(rdMap(:)) + eps);
imagesc(radarParams.range_axis, radarParams.doppler_axis, rdMap_dB)
xlabel('Range (m)')
ylabel('Velocity (m/s)')
title('Human Motion Range-Doppler Map')
colormap('jet')
axis xy
xlim(rangeWindow)
caxis([-45, 0])
colorbar
grid minor

figure
specMap_dB = 20 * log10(abs(spec) / max(abs(spec(:))) + eps);
imagesc(specTime, velocityAxis, specMap_dB)
xlabel('Time (s)')
ylabel('Velocity (m/s)')
title('Human Motion Micro-Doppler Signature')
colormap('jet')
axis xy
caxis([-45, 0])
colorbar
grid minor

figure
plot(humanInfo.time_axis, rangeMin, 'k--', 'LineWidth', 1.2)
hold on
plot(humanInfo.time_axis, rangeMax, 'k--', 'LineWidth', 1.2)
plot(humanInfo.time_axis, peakRange, 'r', 'LineWidth', 1.5)
xlabel('Time (s)')
ylabel('Range (m)')
legend('Human range envelope', 'Human range envelope', 'Peak range')
title('Range Tracking Sanity Check')
grid on

% -------------------------- Subfunctions -------------------------------
function [Position_m, scatterAmp, humanInfo] = GenerateWalkingHumanScatterers(humanParams, radarParams)
Height = humanParams.Height_m;
PulseNum = radarParams.PulseNum;
time_axis = (0:PulseNum - 1) * radarParams.Tc;

ScatterName = {
    'head'
    'torso'
    'left shoulder'
    'right shoulder'
    'left upper arm'
    'right upper arm'
    'left lower arm'
    'right lower arm'
    'left upper leg'
    'right upper leg'
    'left lower leg'
    'right lower leg'
    'left foot'
    'right foot'
    };

ScatterNum = length(ScatterName);
Position_m = zeros(ScatterNum, 3, PulseNum);
body_center = zeros(PulseNum, 3);

scatterAmp = [
    0.80
    2.40
    0.50
    0.50
    0.45
    0.45
    0.55
    0.55
    0.70
    0.70
    0.55
    0.55
    0.45
    0.45
    ];

shoulderWidth = 0.26 * Height / 1.75;
hipWidth = 0.18 * Height / 1.75;
torsoZ = 0.60 * Height;
neckZ = 0.82 * Height;
headZ = 0.96 * Height;
upperArmZ = 0.72 * Height;
lowerArmZ = 0.55 * Height;
upperLegZ = 0.36 * Height;
lowerLegZ = 0.17 * Height;
footZ = 0.04 * Height;

for pIdex = 1:PulseNum
    t = time_axis(pIdex);
    gaitPhase = 2 * pi * humanParams.Gait_Frequency_Hz * t;

    bodySway = humanParams.Side_Sway_m * sin(gaitPhase + 0.4);
    bodyBob = humanParams.Vertical_Bob_m * sin(2 * gaitPhase);
    bodyOrigin = humanParams.Initial_Position_m + humanParams.Body_Velocity_mps * t + ...
                 [bodySway, 0, bodyBob];

    armSwing = humanParams.Arm_Swing_m * sin(gaitPhase);
    legSwing = humanParams.Leg_Swing_m * sin(gaitPhase + pi);
    leftLift = 0.12 * max(0, sin(gaitPhase + pi));
    rightLift = 0.12 * max(0, sin(gaitPhase));

    body_center(pIdex, :) = bodyOrigin + [0, 0, torsoZ];

    Position_m(1, :, pIdex) = bodyOrigin + [0, 0.02 * sin(gaitPhase), headZ];
    Position_m(2, :, pIdex) = bodyOrigin + [0, 0, torsoZ];
    Position_m(3, :, pIdex) = bodyOrigin + [-shoulderWidth, 0.02, neckZ];
    Position_m(4, :, pIdex) = bodyOrigin + [ shoulderWidth, 0.02, neckZ];
    Position_m(5, :, pIdex) = bodyOrigin + [-shoulderWidth, 0.30 * armSwing, upperArmZ];
    Position_m(6, :, pIdex) = bodyOrigin + [ shoulderWidth, -0.30 * armSwing, upperArmZ];
    Position_m(7, :, pIdex) = bodyOrigin + [-shoulderWidth, 0.75 * armSwing, lowerArmZ];
    Position_m(8, :, pIdex) = bodyOrigin + [ shoulderWidth, -0.75 * armSwing, lowerArmZ];
    Position_m(9, :, pIdex) = bodyOrigin + [-hipWidth, 0.28 * legSwing, upperLegZ];
    Position_m(10, :, pIdex) = bodyOrigin + [ hipWidth, -0.28 * legSwing, upperLegZ];
    Position_m(11, :, pIdex) = bodyOrigin + [-hipWidth, 0.70 * legSwing, lowerLegZ + leftLift];
    Position_m(12, :, pIdex) = bodyOrigin + [ hipWidth, -0.70 * legSwing, lowerLegZ + rightLift];
    Position_m(13, :, pIdex) = bodyOrigin + [-hipWidth, 1.00 * legSwing, footZ + leftLift];
    Position_m(14, :, pIdex) = bodyOrigin + [ hipWidth, -1.00 * legSwing, footZ + rightLift];
end

humanInfo.time_axis = time_axis;
humanInfo.scatterName = ScatterName;
humanInfo.body_center = body_center;
end

function [spec, timeAxis, freqAxis] = SimpleSpectrogram(x, windowLen, overlapLen, nfft, slowTimeInterval)
x = x(:).';
step = windowLen - overlapLen;
segmentNum = floor((length(x) - windowLen) / step) + 1;
spec = zeros(nfft, segmentNum);
timeAxis = zeros(1, segmentNum);
win = 0.54 - 0.46 * cos(2 * pi * (0:windowLen - 1) / (windowLen - 1));

for segIdex = 1:segmentNum
    idxStart = (segIdex - 1) * step + 1;
    idxEnd = idxStart + windowLen - 1;
    segment = x(idxStart:idxEnd) .* win;
    spec(:, segIdex) = fftshift(fft(segment, nfft));
    timeAxis(segIdex) = ((idxStart + idxEnd) / 2 - 1) * slowTimeInterval;
end

freqAxis = (-nfft / 2:nfft / 2 - 1) / (nfft * slowTimeInterval);
end
