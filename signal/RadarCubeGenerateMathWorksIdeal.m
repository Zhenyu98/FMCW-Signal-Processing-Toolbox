function [data, sourceInfo] = RadarCubeGenerateMathWorksIdeal(targetParams, radarParams, sourceOptions)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : RadarCubeGenerateMathWorksIdeal.m
% Date & time         : May. 2026
% Version             : 0.3
% Purpose             : Generate a clean point-target FMCW signal by
%                       MathWorks radarTransceiver for source validation
% -------------------------------------------------------------------------
% Format of data      : nSample x PulseNum x RxNum x TxNum
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 3
    sourceOptions = struct;
end

%% Scope guard for the first validated source switch
if isfield(radarParams, 'SNR_dB') && ~isempty(radarParams.SNR_dB)
    error('RadarCubeGenerateMathWorksIdeal currently validates clean signals only.');
end

if isfield(targetParams, 'position_m') && ~isempty(targetParams.position_m)
    error('RadarCubeGenerateMathWorksIdeal currently accepts range/velocity/angle point targets only.');
end

requiredTargetFields = {'range', 'velocity', 'azimuth', 'elevation', 'amplitude'};
for fieldIdex = 1:length(requiredTargetFields)
    if ~isfield(targetParams, requiredTargetFields{fieldIdex})
        error('targetParams.%s is required.', requiredTargetFields{fieldIdex});
    end
end

if length(targetParams.range) ~= 1 || length(targetParams.velocity) ~= 1 || ...
        length(targetParams.azimuth) ~= 1 || length(targetParams.elevation) ~= 1 || ...
        length(targetParams.amplitude) ~= 1
    error('RadarCubeGenerateMathWorksIdeal currently accepts one point target only.');
end

if exist('radarTransceiver', 'class') ~= 8
    error('Radar Toolbox radarTransceiver is required for this signal source.');
end

%% Build the ideal MathWorks waveform-level radar
internalOversampling = getParam(sourceOptions, 'InternalOversampling', 128);
if internalOversampling < 1 || internalOversampling ~= round(internalOversampling)
    error('sourceOptions.InternalOversampling must be a positive integer.');
end

nSample = radarParams.nSample;
PulseNum = radarParams.PulseNum;
TxNum = radarParams.TxNum;
RxNum = radarParams.RxNum;
FsADC = radarParams.Fs;
sweepTime = nSample / FsADC;
sweepBandwidth = radarParams.K * sweepTime;
FsInternal = internalOversampling * FsADC;

if FsInternal < sweepBandwidth
    error(['Internal sample rate must cover the FMCW sweep bandwidth. ' ...
        'Increase sourceOptions.InternalOversampling.']);
end

isotropicAntenna = phased.IsotropicAntennaElement( ...
    'FrequencyRange', [radarParams.fc - sweepBandwidth / 2, ...
    radarParams.fc + sweepBandwidth / 2]);

% The local cube uses a positive virtual-array phase convention. Negating
% the MathWorks element locations keeps the existing pointcloud/DOA
% contract unchanged when a non-zero azimuth is simulated.
rxArray = phased.ConformalArray( ...
    'Element', isotropicAntenna, ...
    'ElementPosition', -radarParams.RxPos_m.');

%% Define one point target in the toolbox X/Y/Z coordinate convention
directionVec = [cosd(targetParams.elevation) * sind(targetParams.azimuth), ...
                cosd(targetParams.elevation) * cosd(targetParams.azimuth), ...
                sind(targetParams.elevation)];
targetPosition = targetParams.range * directionVec;
targetVelocity = targetParams.velocity * directionVec;
targetRCS_dBsm = 10 * log10(abs(targetParams.amplitude)^2 + eps);

target = struct( ...
    'Position', targetPosition, ...
    'Velocity', targetVelocity, ...
    'Signatures', rcsSignature('Pattern', targetRCS_dBsm));

%% Generate, dechirp and sample at the requested ADC rate
data = zeros(nSample, PulseNum, RxNum, TxNum);
for txIdex = 1:TxNum
    waveform = phased.FMCWWaveform( ...
        'SampleRate', FsInternal, ...
        'SweepTime', sweepTime, ...
        'SweepBandwidth', sweepBandwidth, ...
        'OutputFormat', 'Sweeps', ...
        'NumSweeps', 1);
    transmittedWaveform = clone(waveform);
    txArray = phased.ConformalArray( ...
        'Element', isotropicAntenna, ...
        'ElementPosition', -radarParams.TxPos_m(txIdex, :).');

    radar = radarTransceiver( ...
        'Waveform', waveform, ...
        'Transmitter', phased.Transmitter('PeakPower', 1, 'Gain', 0), ...
        'TransmitAntenna', phased.Radiator( ...
            'Sensor', txArray, 'OperatingFrequency', radarParams.fc), ...
        'ReceiveAntenna', phased.Collector( ...
            'Sensor', rxArray, 'OperatingFrequency', radarParams.fc), ...
        'Receiver', phased.ReceiverPreamp( ...
            'Gain', 0, ...
            'NoiseMethod', 'Noise power', ...
            'NoisePower', realmin, ...
            'SeedSource', 'Property', ...
            'Seed', 1), ...
        'NumRepetitions', 1);

    for pIdex = 1:PulseNum
        slowTime = (pIdex - 1) * radarParams.Tc + (txIdex - 1) * radarParams.Ta;
        % radarTransceiver uses target.Position at the current call time.
        % 跨 chirp 的径向运动需要显式推进，否则只保留单个 chirp 内的速度效应。
        target.Position = targetPosition + targetVelocity * slowTime;
        txSignal = transmittedWaveform();
        rxSignal = radar(target, slowTime);
        beatSignal = dechirp(rxSignal, txSignal);
        adcSignal = beatSignal(1:internalOversampling:end, :, 1);
        data(:, pIdex, :, txIdex) = reshape(adcSignal(1:nSample, :), ...
            nSample, 1, RxNum);
    end
end

%% Source metadata
sourceInfo.SourceType = 'mathworks_ideal_waveform';
sourceInfo.ModelLevel = 'waveform_level_no_ti_frontend';
sourceInfo.InternalOversampling = internalOversampling;
sourceInfo.InternalSampleRate_Hz = FsInternal;
sourceInfo.SweepTime_s = sweepTime;
sourceInfo.SweepBandwidth_Hz = sweepBandwidth;
sourceInfo.OutputSampleRate_Hz = FsADC;
sourceInfo.OutputFormat = 'nSample x PulseNum x RxNum x TxNum';
sourceInfo.AmplitudeConvention = 'radar equation amplitude; compare after complex gain alignment';
sourceInfo.ArrayPhaseConvention = 'MathWorks element locations negated to preserve local cube phase convention';
sourceInfo.ValidatedScope = 'clean single point target; static SISO/TI_xWRx642/TI_xWRx843 and moving TI_xWRx843 TDM-MIMO cube';

end

function value = getParam(params, fieldName, defaultValue)
if isfield(params, fieldName) && ~isempty(params.(fieldName))
    value = params.(fieldName);
else
    value = defaultValue;
end
end
