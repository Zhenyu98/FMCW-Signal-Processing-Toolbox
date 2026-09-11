%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : demo_mathworks_signal_source_switch.m
% Date & time         : May. 2026
% Version             : 1.1
% Purpose             : Switch between local and MathWorks FMCW signal
%                       sources in the same TI_xWRx843 MIMO processing route
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
close all

%% select signal source
% 'local_point'          : fast analytic point-target signal
% 'mathworks_point'      : waveform-level ideal point-target signal
% 'mathworks_pedestrian' : official backscatterPedestrian signal
% 'mathworks_two_ray'    : official widebandTwoRayChannel multipath signal
if ~exist('signalSource', 'var') || isempty(signalSource)
    signalSource = 'mathworks_pedestrian';
end

%% generate radar signal
switch signalSource
    case {'local_point', 'mathworks_point'}
        sensorParams.Start_Freq_GHz = 77;
        sensorParams.Slope_MHzperus = 3.04;
        sensorParams.Sampling_Rate_ksps = 5000;
        sensorParams.Samples_per_Chirp = 256;
        sensorParams.Frame = 16;
        sensorParams.TxNum = 3;
        sensorParams.RxNum = 4;
        sensorParams.ArrayType = 'TI_xWRx843';

        targetParams.amplitude = 1;
        targetParams.range = 7;
        targetParams.velocity = 0.8;
        targetParams.azimuth = 15;
        targetParams.elevation = 5;

        radarParams = RadarParameterGenerate(sensorParams, targetParams);
        if strcmp(signalSource, 'local_point')
            [data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);
            sourceInfo.SourceType = 'local_analytic';
            sourceInfo.ModelLevel = 'analytic_beat_signal';
            sourceInfo.NoiseInfo = noiseInfo;
        else
            sourceOptions.InternalOversampling = 128;
            [data, sourceInfo] = RadarCubeGenerateMathWorksIdeal( ...
                targetParams, radarParams, sourceOptions);
        end

    case 'mathworks_pedestrian'
        sensorParams.Start_Freq_GHz = 77;
        sensorParams.Slope_MHzperus = 6.08;
        sensorParams.Sampling_Rate_ksps = 5000;
        sensorParams.Samples_per_Chirp = 128;
        sensorParams.Frame = 16;
        sensorParams.TxNum = 3;
        sensorParams.RxNum = 4;
        sensorParams.ArrayType = 'TI_xWRx843';

        radarParams = RadarParameterGenerate(sensorParams);
        pedestrianParams.Initial_Position_m = [2, 8, 0];
        pedestrianParams.Height_m = 1.70;
        pedestrianParams.WalkingSpeed_mps = 1.20;
        pedestrianParams.Heading_deg = 0;
        sourceOptions.InternalOversampling = 32;

        [data, sourceInfo, pedestrianInfo] = RadarCubeGenerateMathWorksPedestrian( ...
            pedestrianParams, radarParams, sourceOptions);
        disp(['body segment number: ', num2str(pedestrianInfo.BodySegmentNum)])

    case 'mathworks_two_ray'
        sensorParams.Start_Freq_GHz = 77;
        sensorParams.Slope_MHzperus = 3.04;
        sensorParams.Sampling_Rate_ksps = 5000;
        sensorParams.Samples_per_Chirp = 256;
        sensorParams.Frame = 16;
        sensorParams.TxNum = 3;
        sensorParams.RxNum = 4;
        sensorParams.ArrayType = 'TI_xWRx843';

        radarParams = RadarParameterGenerate(sensorParams);
        targetParams.amplitude = 20;
        multipathParams.RadarPosition_m = [0; 0; 5];
        multipathParams.TargetPosition_m = [3; 10; 20];
        multipathParams.TargetVelocity_mps = [0; 0; 0];
        multipathParams.GroundReflectionCoefficient = -0.8;
        sourceOptions.InternalOversampling = 128;

        [data, sourceInfo, multipathInfo] = RadarCubeGenerateMathWorksTwoRay( ...
            targetParams, radarParams, multipathParams, sourceOptions);
        disp(['expected apparent ranges: ', ...
            mat2str(multipathInfo.ExpectedApparentRange_m, 4), ' m'])

    otherwise
        error('Unknown signalSource: %s', signalSource)
end

disp(['signal source: ', sourceInfo.SourceType])
disp(['data size: ', mat2str(size(data))])
assert(size(data, 3) == radarParams.RxNum && size(data, 4) == radarParams.TxNum, ...
    'Signal-source switch demo must keep the MIMO radar cube contract.')

%% same toolbox processing after the signal-source switch
[dopplerFFTOut, range_axis, velocity_axis] = RDM(data, sensorParams, false);
rdMap = squeeze(sum(abs(dopplerFFTOut), 3));

figure
imagesc(velocity_axis, range_axis, abs(rdMap))
axis xy
xlabel('Velocity (m/s)')
ylabel('Range (m)')
title(['Range-Doppler Map: ', strrep(signalSource, '_', ' ')])
colorbar
grid on
