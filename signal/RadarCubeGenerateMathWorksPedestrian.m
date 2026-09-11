function [data, sourceInfo, pedestrianInfo] = RadarCubeGenerateMathWorksPedestrian(pedestrianParams, radarParams, sourceOptions)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : RadarCubeGenerateMathWorksPedestrian.m
% Date & time         : May. 2026
% Version             : 1.1
% Purpose             : Generate pedestrian FMCW echo with the official
%                       MathWorks backscatterPedestrian model
% -------------------------------------------------------------------------
% Format of data      : nSample x PulseNum x RxNum x TxNum
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 3
    sourceOptions = struct;
end

if isfield(radarParams, 'SNR_dB') && ~isempty(radarParams.SNR_dB)
    error('RadarCubeGenerateMathWorksPedestrian currently generates clean signals only.');
end

if exist('backscatterPedestrian', 'class') ~= 8
    error('Radar Toolbox backscatterPedestrian is required for this signal source.');
end

requiredFields = {'Initial_Position_m', 'Height_m', 'WalkingSpeed_mps', 'Heading_deg'};
for fieldIdex = 1:length(requiredFields)
    if ~isfield(pedestrianParams, requiredFields{fieldIdex})
        error('pedestrianParams.%s is required.', requiredFields{fieldIdex});
    end
end

%% Build waveform and official pedestrian model
nSample = radarParams.nSample;
PulseNum = radarParams.PulseNum;
TxNum = radarParams.TxNum;
RxNum = radarParams.RxNum;
FsADC = radarParams.Fs;
sweepTime = nSample / FsADC;
sweepBandwidth = radarParams.K * sweepTime;
internalOversampling = getParam(sourceOptions, 'InternalOversampling', ...
    ceil(sweepBandwidth / FsADC));
FsInternal = internalOversampling * FsADC;

if internalOversampling < 1 || internalOversampling ~= round(internalOversampling) || ...
        FsInternal < sweepBandwidth
    error('sourceOptions.InternalOversampling must provide an internal rate above the FMCW bandwidth.');
end

waveform = phased.FMCWWaveform( ...
    'SampleRate', FsInternal, ...
    'SweepTime', sweepTime, ...
    'SweepBandwidth', sweepBandwidth, ...
    'OutputFormat', 'Sweeps', ...
    'NumSweeps', 1);

channel = phased.FreeSpace( ...
    'PropagationSpeed', radarParams.c, ...
    'OperatingFrequency', radarParams.fc, ...
    'SampleRate', FsInternal, ...
    'TwoWayPropagation', true);

pedestrian = backscatterPedestrian( ...
    'Height', pedestrianParams.Height_m, ...
    'WalkingSpeed', pedestrianParams.WalkingSpeed_mps, ...
    'PropagationSpeed', radarParams.c, ...
    'OperatingFrequency', radarParams.fc, ...
    'InitialPosition', pedestrianParams.Initial_Position_m(:), ...
    'InitialHeading', pedestrianParams.Heading_deg);

radarPosition = [0; 0; 0];
radarVelocity = [0; 0; 0];

%% Generate echo chirp by chirp so the official walking state evolves
if TxNum == 1 && RxNum == 1
    motionInterval = getParam(sourceOptions, 'MotionInterval_s', radarParams.Tc);
    data = zeros(nSample, PulseNum, 1, 1);
    bodyPosition_m = zeros(3, 16, PulseNum);

    for pIdex = 1:PulseNum
        [bodyPosition, bodyVelocity, bodyAxes] = move( ...
            pedestrian, motionInterval, pedestrianParams.Heading_deg);
        txSignal = waveform();
        incidentSignal = channel(repmat(txSignal, 1, 16), ...
            radarPosition, bodyPosition, radarVelocity, bodyVelocity);
        [~, incidentAngle] = rangeangle(radarPosition, bodyPosition, bodyAxes);
        rxSignal = reflect(pedestrian, incidentSignal, incidentAngle);
        beatSignal = dechirp(rxSignal, txSignal);
        adcSignal = beatSignal(1:internalOversampling:end);

        data(:, pIdex, 1, 1) = adcSignal(1:nSample);
        bodyPosition_m(:, :, pIdex) = bodyPosition;
    end
    spatialModel = 'official monostatic SISO channel';
else
    if ~isfield(radarParams, 'TxPos_m') || ~isfield(radarParams, 'RxPos_m')
        error('MIMO pedestrian output requires radarParams.TxPos_m and radarParams.RxPos_m.');
    end

    motionInterval = getParam(sourceOptions, 'MotionInterval_s', radarParams.Ta);
    data = zeros(nSample, PulseNum, RxNum, TxNum);
    bodyPosition_m = zeros(3, 16, PulseNum, TxNum);

    outgoingChannel = cell(TxNum, 1);
    returnChannel = cell(RxNum, TxNum);
    for txIdex = 1:TxNum
        outgoingChannel{txIdex} = phased.FreeSpace( ...
            'PropagationSpeed', radarParams.c, ...
            'OperatingFrequency', radarParams.fc, ...
            'SampleRate', FsInternal, ...
            'TwoWayPropagation', false);
        for rxIdex = 1:RxNum
            returnChannel{rxIdex, txIdex} = phased.FreeSpace( ...
                'PropagationSpeed', radarParams.c, ...
                'OperatingFrequency', radarParams.fc, ...
                'SampleRate', FsInternal, ...
                'TwoWayPropagation', false);
        end
    end

    for pIdex = 1:PulseNum
        for txIdex = 1:TxNum
            [bodyPosition, bodyVelocity, bodyAxes] = move( ...
                pedestrian, motionInterval, pedestrianParams.Heading_deg);
            txSignal = waveform();

            % 与本地 RadarCubeGenerate 的正虚拟阵列相位约定对齐。
            txPosition = -radarParams.TxPos_m(txIdex, :).';
            incidentSignal = outgoingChannel{txIdex}(repmat(txSignal, 1, 16), ...
                txPosition, bodyPosition, radarVelocity, bodyVelocity);
            [~, incidentAngle] = rangeangle(txPosition, bodyPosition, bodyAxes);

            % reflect 的公开输出会合并 16 个身体段。逐列激励后再求和
            % 与官方合成输出等价，同时保留每个段到 Rx 的传播相位。
            reflectedSegmentSignal = zeros(size(incidentSignal));
            for bodyIdex = 1:size(bodyPosition, 2)
                isolatedIncidentSignal = zeros(size(incidentSignal));
                isolatedIncidentSignal(:, bodyIdex) = incidentSignal(:, bodyIdex);
                reflectedSegmentSignal(:, bodyIdex) = reflect( ...
                    pedestrian, isolatedIncidentSignal, incidentAngle);
            end

            for rxIdex = 1:RxNum
                rxPosition = -radarParams.RxPos_m(rxIdex, :).';
                returnedSegmentSignal = returnChannel{rxIdex, txIdex}( ...
                    reflectedSegmentSignal, bodyPosition, rxPosition, ...
                    bodyVelocity, radarVelocity);
                rxSignal = sum(returnedSegmentSignal, 2);
                beatSignal = dechirp(rxSignal, txSignal);
                adcSignal = beatSignal(1:internalOversampling:end);
                data(:, pIdex, rxIdex, txIdex) = adcSignal(1:nSample);
            end
            bodyPosition_m(:, :, pIdex, txIdex) = bodyPosition;
        end
    end
    spatialModel = 'official segment reflection with TDM-MIMO path propagation';
end

%% Source metadata
sourceInfo.SourceType = 'mathworks_pedestrian';
sourceInfo.ModelLevel = 'official_backscatterPedestrian_waveform_level';
sourceInfo.InternalOversampling = internalOversampling;
sourceInfo.InternalSampleRate_Hz = FsInternal;
sourceInfo.SweepBandwidth_Hz = sweepBandwidth;
sourceInfo.OutputSampleRate_Hz = FsADC;
sourceInfo.OutputFormat = 'nSample x PulseNum x RxNum x TxNum';
sourceInfo.ArrayPhaseConvention = 'MathWorks Tx/Rx positions negated to preserve local cube phase convention';
sourceInfo.SpatialModel = spatialModel;
sourceInfo.ValidatedScope = 'clean SISO pedestrian cube and TI_xWRx843 TDM-MIMO pointcloud input';

pedestrianInfo.BodySegmentNum = size(bodyPosition_m, 2);
pedestrianInfo.BodyPosition_m = bodyPosition_m;
pedestrianInfo.MotionInterval_s = motionInterval;
pedestrianInfo.BodyPositionFormat = '3 x 16 x PulseNum x TxNum for MIMO; 3 x 16 x PulseNum for SISO';

end

function value = getParam(params, fieldName, defaultValue)
if isfield(params, fieldName) && ~isempty(params.(fieldName))
    value = params.(fieldName);
else
    value = defaultValue;
end
end
