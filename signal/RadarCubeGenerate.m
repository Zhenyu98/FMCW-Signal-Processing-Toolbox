function [data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : RadarCubeGenerate.m
% Date & time         : May. 2026
% Version             : 1.4
% Purpose             : Generate FMCW radar data cube
% -------------------------------------------------------------------------
% Format of data      : nSample x PulseNum x RxNum x TxNum
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Parameters of FMCW radar
f_0 = radarParams.f_0;                          % Starting frequency (Hz)
K = radarParams.K;                              % Slope (Hz/s)
Ts = radarParams.Ts;                            % Sample interval (s)
nSample = radarParams.nSample;                  % Number of ADC samples
PulseNum = radarParams.PulseNum;                % Pulse number / chirp number
TxNum = radarParams.TxNum;                      % Number of Tx antennas
RxNum = radarParams.RxNum;                      % Number of Rx antennas
c = radarParams.c;                              % Speed of light (m/s)
Ta = radarParams.Ta;                            % Chirp duration before TDM (s)
Tc = radarParams.Tc;                            % Chirp duration after TDM (s)
VirtualPos_m = radarParams.VirtualPos_m;        % Virtual antenna positions (m)

%% Parameters of target
usePositionMode = isfield(targetParams, 'position_m') && ~isempty(targetParams.position_m);

if usePositionMode
    Position_m = preparePositionInput(targetParams.position_m, PulseNum);
    M = size(Position_m, 1);                    % Number of scatterers
    sigma = prepareAmplitudeInput(targetParams, M, PulseNum);
    Velocity_mps = prepareVelocityInput(targetParams, M, PulseNum);
else
    sigma = targetParams.amplitude;             % Target amplitudes / RCS
    R = targetParams.range;                     % Target ranges (m)
    V = targetParams.velocity;                  % Target velocities (m/s)
    Azimuth = targetParams.azimuth;             % Target azimuth angles (degree)
    Elevation = targetParams.elevation;         % Target elevation angles (degree)
    M = length(R);                              % Number of targets

    if length(Elevation) ~= M
        error('targetParams.elevation must have the same length as targetParams.range.');
    end
end

%% Generate transmit signal
St = zeros(1, nSample);
for tIdex = 1:nSample
    fastTime = (tIdex - 1) * Ts;
    St(tIdex) = exp(1j * 2 * pi * (f_0 * fastTime + 0.5 * K * fastTime^2));
end

%% Generate receive signal
Sr = zeros(nSample, PulseNum, RxNum, TxNum);
for targetIdex = 1:M
    Srtemp = zeros(nSample, PulseNum, RxNum, TxNum);
    if ~usePositionMode
        InitRange = R(targetIdex);
        directionVec = [cosd(Elevation(targetIdex)) * sind(Azimuth(targetIdex)), ...
                        cosd(Elevation(targetIdex)) * cosd(Azimuth(targetIdex)), ...
                        sind(Elevation(targetIdex))];
    end
    for tIdex = 1:nSample
        fastTime = (tIdex - 1) * Ts;
        for pIdex = 1:PulseNum
            slowTime = (pIdex - 1) * Tc;
            for txIdex = 1:TxNum
                Txdelay = (txIdex - 1) * Ta;
                for rxIdex = 1:RxNum
                    t = fastTime + slowTime + Txdelay;
                    if usePositionMode
                        localTime = fastTime + Txdelay;
                        targetPos = getScatterPosition(Position_m, Velocity_mps, targetIdex, pIdex, t, localTime);
                        InstantRange = norm(targetPos);
                        if InstantRange <= eps
                            error('targetParams.position_m contains a scatterer at the radar origin.');
                        end
                        directionVec = targetPos / InstantRange;
                        sigmaVal = getAmplitudeValue(sigma, targetIdex, pIdex);
                    else
                        InstantRange = InitRange + V(targetIdex) * t;
                        sigmaVal = sigma(targetIdex);
                    end

                    virtualIdex = (txIdex - 1) * RxNum + rxIdex;
                    arrayPath = dot(VirtualPos_m(virtualIdex, :), directionVec);
                    tau = (2 * InstantRange + arrayPath) / c;

                    Srtemp(tIdex, pIdex, rxIdex, txIdex) = sigmaVal * ...
                        exp(1j * 2 * pi * (f_0 * (fastTime - tau) + 0.5 * K * (fastTime - tau)^2));
                end
            end
        end
    end
    Sr = Sr + Srtemp;
end

%% Mixer output
data = zeros(nSample, PulseNum, RxNum, TxNum);
for tIdex = 1:nSample
    for pIdex = 1:PulseNum
        for txIdex = 1:TxNum
            for rxIdex = 1:RxNum
                data(tIdex, pIdex, rxIdex, txIdex) = St(tIdex) * conj(Sr(tIdex, pIdex, rxIdex, txIdex));
            end
        end
    end
end

%% Add noise by SNR
noiseInfo.SNR_dB = [];
noiseInfo.signalPower = mean(abs(data(:)).^2);
noiseInfo.noisePower = 0;
noiseInfo.noiseStd = 0;

if isfield(radarParams, 'SNR_dB') && ~isempty(radarParams.SNR_dB)
    [data, noiseInfo] = AddNoiseBySNR(data, radarParams.SNR_dB);
end

end

function Position_m = preparePositionInput(Position_m, PulseNum)
if ~isnumeric(Position_m) || size(Position_m, 2) ~= 3
    error('targetParams.position_m must be a ScatterNum-by-3 or ScatterNum-by-3-by-PulseNum numeric array.');
end

if ndims(Position_m) <= 2
    Position_m = reshape(Position_m, size(Position_m, 1), 3, 1);
elseif ndims(Position_m) == 3
    if size(Position_m, 3) ~= 1 && size(Position_m, 3) ~= PulseNum
        error('The third dimension of targetParams.position_m must be 1 or radarParams.PulseNum.');
    end
else
    error('targetParams.position_m must be a ScatterNum-by-3 or ScatterNum-by-3-by-PulseNum numeric array.');
end
end

function sigma = prepareAmplitudeInput(targetParams, M, PulseNum)
if ~isfield(targetParams, 'amplitude') || isempty(targetParams.amplitude)
    sigma = ones(M, 1);
    return
end

sigma = targetParams.amplitude;
if isscalar(sigma)
    sigma = sigma * ones(M, 1);
elseif isvector(sigma) && numel(sigma) == M
    sigma = sigma(:);
elseif isequal(size(sigma), [M, PulseNum])
    % Chirp-level amplitude, already in the expected shape.
else
    error('targetParams.amplitude must be scalar, ScatterNum-by-1, or ScatterNum-by-PulseNum.');
end
end

function Velocity_mps = prepareVelocityInput(targetParams, M, PulseNum)
Velocity_mps = [];
if ~isfield(targetParams, 'velocity_mps') || isempty(targetParams.velocity_mps)
    return
end

Velocity_mps = targetParams.velocity_mps;
if ~isnumeric(Velocity_mps) || size(Velocity_mps, 1) ~= M || size(Velocity_mps, 2) ~= 3
    error('targetParams.velocity_mps must be a ScatterNum-by-3 or ScatterNum-by-3-by-PulseNum numeric array.');
end

if ndims(Velocity_mps) <= 2
    Velocity_mps = reshape(Velocity_mps, M, 3, 1);
elseif ndims(Velocity_mps) == 3
    if size(Velocity_mps, 3) ~= 1 && size(Velocity_mps, 3) ~= PulseNum
        error('The third dimension of targetParams.velocity_mps must be 1 or radarParams.PulseNum.');
    end
else
    error('targetParams.velocity_mps must be a ScatterNum-by-3 or ScatterNum-by-3-by-PulseNum numeric array.');
end
end

function targetPos = getScatterPosition(Position_m, Velocity_mps, targetIdex, pIdex, t, localTime)
if size(Position_m, 3) == 1
    targetPos = reshape(Position_m(targetIdex, :, 1), 1, 3);
    timeOffset = t;
else
    targetPos = reshape(Position_m(targetIdex, :, pIdex), 1, 3);
    timeOffset = localTime;  % position_m(:,:,pIdex) already contains slow-time motion.
end

if ~isempty(Velocity_mps)
    if size(Velocity_mps, 3) == 1
        targetVel = reshape(Velocity_mps(targetIdex, :, 1), 1, 3);
    else
        targetVel = reshape(Velocity_mps(targetIdex, :, pIdex), 1, 3);
    end
    targetPos = targetPos + targetVel * timeOffset;
end
end

function sigmaVal = getAmplitudeValue(sigma, targetIdex, pIdex)
if size(sigma, 2) == 1
    sigmaVal = sigma(targetIdex);
else
    sigmaVal = sigma(targetIdex, pIdex);
end
end
