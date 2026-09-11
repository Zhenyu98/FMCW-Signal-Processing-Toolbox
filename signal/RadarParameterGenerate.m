function radarParams = RadarParameterGenerate(sensorParams, targetParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : RadarParameterGenerate.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Calculate common FMCW radar parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 2
    targetParams = [];
end

if needConfigureVirtualArray(sensorParams)
    sensorParams = ConfigureVirtualArray(sensorParams);
end

%% Basic radar parameters
f_0 = sensorParams.Start_Freq_GHz * 1e9;          % Starting frequency (Hz)
K = sensorParams.Slope_MHzperus * 1e12;           % Slope (Hz/s)
Fs = sensorParams.Sampling_Rate_ksps * 1e3;       % Sampling rate (Hz)
Ts = 1 / Fs;                                      % Sample interval (s)
nSample = sensorParams.Samples_per_Chirp;         % Number of ADC samples
PulseNum = sensorParams.Frame;                    % Pulse number / chirp number
TxNum = sensorParams.TxNum;                       % Number of Tx antennas
RxNum = sensorParams.RxNum;                       % Number of Rx antennas

c = physconst('lightspeed');                      % Speed of light (m/s)
Ta = (nSample - 1) * Ts;                          % Chirp duration before TDM (s)
Tc = TxNum * Ta;                                  % Chirp duration after TDM (s)
TF = Tc * PulseNum;                               % Frame duration (s)
B = K * Ta;                                       % Bandwidth (Hz)

if isfield(sensorParams, 'Center_Freq_Hz') && ~isempty(sensorParams.Center_Freq_Hz)
    fc = sensorParams.Center_Freq_Hz;             % Center frequency (Hz)
elseif isfield(sensorParams, 'Center_Freq_GHz') && ~isempty(sensorParams.Center_Freq_GHz)
    fc = sensorParams.Center_Freq_GHz * 1e9;      % Center frequency (Hz)
else
    fc = f_0 + B / 2;                             % Center frequency (Hz)
end

lambda = c / fc;                                  % Wave length (m)
d = getParam(sensorParams, 'Antenna_Spacing_m', lambda / 2);
ArrayNum = TxNum * RxNum;                         % Number of antenna array

%% Antenna positions
TxPos_m = [];
RxPos_m = [];
VirtualPos_m = [];

if isfield(sensorParams, 'RxPos_m') && ~isempty(sensorParams.RxPos_m)
    RxPos_m = sensorParams.RxPos_m;
end

if isfield(sensorParams, 'TxPos_m') && ~isempty(sensorParams.TxPos_m)
    TxPos_m = sensorParams.TxPos_m;
end

if isfield(sensorParams, 'VirtualPos_m') && ~isempty(sensorParams.VirtualPos_m)
    VirtualPos_m = sensorParams.VirtualPos_m;
end

if isempty(VirtualPos_m)
    if isempty(RxPos_m)
        RxPos_m = [(0:RxNum - 1).' * d, zeros(RxNum, 1), zeros(RxNum, 1)];
    end
    if isempty(TxPos_m)
        TxPos_m = [(0:TxNum - 1).' * RxNum * d, zeros(TxNum, 1), zeros(TxNum, 1)];
    end
end

if ~isempty(RxPos_m) && (size(RxPos_m, 1) ~= RxNum || size(RxPos_m, 2) ~= 3)
    error('sensorParams.RxPos_m must be RxNum x 3.');
end
if ~isempty(TxPos_m) && (size(TxPos_m, 1) ~= TxNum || size(TxPos_m, 2) ~= 3)
    error('sensorParams.TxPos_m must be TxNum x 3.');
end

if isempty(VirtualPos_m)
    VirtualPos_m = zeros(ArrayNum, 3);
    arrayIdex = 1;
    for txIdex = 1:TxNum
        for rxIdex = 1:RxNum
            VirtualPos_m(arrayIdex, :) = TxPos_m(txIdex, :) + RxPos_m(rxIdex, :);
            arrayIdex = arrayIdex + 1;
        end
    end
elseif size(VirtualPos_m, 1) ~= ArrayNum || size(VirtualPos_m, 2) ~= 3
    error('sensorParams.VirtualPos_m must be (TxNum*RxNum) x 3.');
end

%% Resolution and axes
range_res = c / (2 * B);                          % Range resolution (m)
doppler_res = lambda / (2 * TF);                  % Velocity resolution (m/s)
range_axis = (0:nSample - 1) * range_res;         % Range axis (m)
doppler_axis = (-PulseNum / 2:PulseNum / 2 - 1) * doppler_res;

if ~isempty(targetParams) && isfield(targetParams, 'azimuth') && ~isempty(targetParams.azimuth)
    Azimuth = targetParams.azimuth;
    [theta1, theta2] = meshgrid(Azimuth, Azimuth);
    theta_bar = (theta1 + theta2) / 2;
    angle_res = 2 * asind(lambda ./ (2 * ArrayNum * d * cosd(theta_bar)));
else
    angle_res = 2 * asind(lambda / (2 * ArrayNum * d));  % Broadside reference
end

%% Output
radarParams.f_0 = f_0;
radarParams.K = K;
radarParams.Fs = Fs;
radarParams.Ts = Ts;
radarParams.nSample = nSample;
radarParams.SampleNum = nSample;
radarParams.PulseNum = PulseNum;
radarParams.ChirpNum = PulseNum;
radarParams.TxNum = TxNum;
radarParams.RxNum = RxNum;
radarParams.ArrayNum = ArrayNum;
radarParams.c = c;
radarParams.Ta = Ta;
radarParams.Tc = Tc;
radarParams.TF = TF;
radarParams.B = B;
radarParams.fc = fc;
radarParams.lambda = lambda;
radarParams.d = d;
radarParams.VirtualArrayUnit_m = getParam(sensorParams, 'VirtualArrayUnit_m', d);
radarParams.VirtualPos_m = VirtualPos_m;
if ~isempty(RxPos_m)
    radarParams.RxPos_m = RxPos_m;
end
if ~isempty(TxPos_m)
    radarParams.TxPos_m = TxPos_m;
end
if isfield(sensorParams, 'VirtualArrayMap')
    radarParams.VirtualArrayMap = sensorParams.VirtualArrayMap;
end
if isfield(sensorParams, 'VirtualPosIndex')
    radarParams.VirtualPosIndex = sensorParams.VirtualPosIndex;
end
if isfield(sensorParams, 'ArrayType')
    radarParams.ArrayType = sensorParams.ArrayType;
end
if isfield(sensorParams, 'TxPosIndex')
    radarParams.TxPosIndex = sensorParams.TxPosIndex;
end
if isfield(sensorParams, 'RxPosIndex')
    radarParams.RxPosIndex = sensorParams.RxPosIndex;
end
if isfield(sensorParams, 'TxOrder')
    radarParams.TxOrder = sensorParams.TxOrder;
end
if isfield(sensorParams, 'SNR_dB')
    radarParams.SNR_dB = sensorParams.SNR_dB;
end
radarParams.range_res = range_res;
radarParams.doppler_res = doppler_res;
radarParams.angle_res = angle_res;
radarParams.range_axis = range_axis;
radarParams.doppler_axis = doppler_axis;

end

function tf = needConfigureVirtualArray(sensorParams)
hasTxRxPos = isfield(sensorParams, 'TxPos_m') && ~isempty(sensorParams.TxPos_m) && ...
             isfield(sensorParams, 'RxPos_m') && ~isempty(sensorParams.RxPos_m);

tf = (isfield(sensorParams, 'ArrayPreset') && ~isempty(sensorParams.ArrayPreset)) || ...
     (isfield(sensorParams, 'ArrayType') && ~isempty(sensorParams.ArrayType)) || ...
     (isfield(sensorParams, 'VirtualArrayMap') && ~isempty(sensorParams.VirtualArrayMap) && ~hasTxRxPos) || ...
     (isfield(sensorParams, 'TxPosIndex') && ~isempty(sensorParams.TxPosIndex)) || ...
     (isfield(sensorParams, 'RxPosIndex') && ~isempty(sensorParams.RxPosIndex));
end

function value = getParam(params, fieldName, defaultValue)
if isfield(params, fieldName)
    value = params.(fieldName);
    if isempty(value)
        value = defaultValue;
    end
else
    value = defaultValue;
end
end
