function [data, sourceInfo, multipathInfo] = RadarCubeGenerateMathWorksTwoRay(targetParams, radarParams, multipathParams, sourceOptions)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : RadarCubeGenerateMathWorksTwoRay.m
% Date & time         : May. 2026
% Version             : 1.1
% Purpose             : Generate FMCW echo through the official MathWorks
%                       widebandTwoRayChannel multipath model
% -------------------------------------------------------------------------
% Format of data      : nSample x PulseNum x RxNum x TxNum
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 4
    sourceOptions = struct;
end

if isfield(radarParams, 'SNR_dB') && ~isempty(radarParams.SNR_dB)
    error('RadarCubeGenerateMathWorksTwoRay currently generates clean signals only.');
end

if exist('widebandTwoRayChannel', 'class') ~= 8
    error('Radar Toolbox widebandTwoRayChannel is required for this signal source.');
end

requiredTargetFields = {'amplitude'};
for fieldIdex = 1:length(requiredTargetFields)
    if ~isfield(targetParams, requiredTargetFields{fieldIdex})
        error('targetParams.%s is required.', requiredTargetFields{fieldIdex});
    end
end

requiredPathFields = {'RadarPosition_m', 'TargetPosition_m', ...
    'TargetVelocity_mps', 'GroundReflectionCoefficient'};
for fieldIdex = 1:length(requiredPathFields)
    if ~isfield(multipathParams, requiredPathFields{fieldIdex})
        error('multipathParams.%s is required.', requiredPathFields{fieldIdex});
    end
end

if any(multipathParams.TargetVelocity_mps(:) ~= 0)
    error('RadarCubeGenerateMathWorksTwoRay currently validates static target geometry only.');
end

%% Build wideband waveform and official two-ray propagation channels
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

target = phased.RadarTarget( ...
    'OperatingFrequency', radarParams.fc, ...
    'MeanRCS', abs(targetParams.amplitude)^2);

radarPosition = multipathParams.RadarPosition_m(:);
targetPosition = multipathParams.TargetPosition_m(:);
radarVelocity = [0; 0; 0];
targetVelocity = multipathParams.TargetVelocity_mps(:);

if TxNum == 1 && RxNum == 1
    txPositionOffset_m = zeros(3, 1);
    rxPositionOffset_m = zeros(3, 1);
else
    if ~isfield(radarParams, 'TxPos_m') || ~isfield(radarParams, 'RxPos_m')
        error('MIMO two-ray output requires radarParams.TxPos_m and radarParams.RxPos_m.');
    end
    % 与本地 RadarCubeGenerate 和官方行人 MIMO 源使用同一阵列相位约定。
    txPositionOffset_m = -radarParams.TxPos_m.';
    rxPositionOffset_m = -radarParams.RxPos_m.';
end

outgoingPath = cell(TxNum, 1);
returnPath = cell(RxNum, TxNum);
for txIdex = 1:TxNum
    outgoingPath{txIdex} = widebandTwoRayChannel( ...
        'PropagationSpeed', radarParams.c, ...
        'OperatingFrequency', radarParams.fc, ...
        'SampleRate', FsInternal, ...
        'GroundReflectionCoefficient', multipathParams.GroundReflectionCoefficient);
    for rxIdex = 1:RxNum
        returnPath{rxIdex, txIdex} = widebandTwoRayChannel( ...
            'PropagationSpeed', radarParams.c, ...
            'OperatingFrequency', radarParams.fc, ...
            'SampleRate', FsInternal, ...
            'GroundReflectionCoefficient', multipathParams.GroundReflectionCoefficient);
    end
end

%% Generate combined direct and ground-reflected return
data = zeros(nSample, PulseNum, RxNum, TxNum);
for pIdex = 1:PulseNum
    for txIdex = 1:TxNum
        txPosition = radarPosition + txPositionOffset_m(:, min(txIdex, size(txPositionOffset_m, 2)));
        txSignal = waveform();
        incidentSignal = outgoingPath{txIdex}(txSignal, txPosition, targetPosition, ...
            radarVelocity, targetVelocity);
        reflectedSignal = target(incidentSignal);

        for rxIdex = 1:RxNum
            rxPosition = radarPosition + rxPositionOffset_m(:, min(rxIdex, size(rxPositionOffset_m, 2)));
            rxSignal = returnPath{rxIdex, txIdex}(reflectedSignal, targetPosition, ...
                rxPosition, targetVelocity, radarVelocity);
            beatSignal = dechirp(rxSignal, txSignal);
            adcSignal = beatSignal(1:internalOversampling:end);
            data(:, pIdex, rxIdex, txIdex) = adcSignal(1:nSample);
        end
    end
end

%% Expected two-way apparent range components for a flat ground at z = 0
horizontalDistance = norm(targetPosition(1:2) - radarPosition(1:2));
directOneWayRange = norm(targetPosition - radarPosition);
reflectedOneWayRange = sqrt(horizontalDistance^2 + ...
    (targetPosition(3) + radarPosition(3))^2);

multipathInfo.ExpectedApparentRange_m = [ ...
    directOneWayRange, ...
    (directOneWayRange + reflectedOneWayRange) / 2, ...
    reflectedOneWayRange];
multipathInfo.DirectOneWayRange_m = directOneWayRange;
multipathInfo.ReflectedOneWayRange_m = reflectedOneWayRange;

sourceInfo.SourceType = 'mathworks_two_ray';
sourceInfo.ModelLevel = 'official_widebandTwoRayChannel_waveform_level';
sourceInfo.InternalOversampling = internalOversampling;
sourceInfo.InternalSampleRate_Hz = FsInternal;
sourceInfo.SweepBandwidth_Hz = sweepBandwidth;
sourceInfo.OutputSampleRate_Hz = FsADC;
sourceInfo.OutputFormat = 'nSample x PulseNum x RxNum x TxNum';
sourceInfo.ArrayPhaseConvention = 'MathWorks Tx/Rx positions negated to preserve local cube phase convention';
sourceInfo.ValidatedScope = 'clean static SISO and TI_xWRx843 TDM-MIMO target with resolvable ground two-ray return';

end

function value = getParam(params, fieldName, defaultValue)
if isfield(params, fieldName) && ~isempty(params.(fieldName))
    value = params.(fieldName);
else
    value = defaultValue;
end
end
