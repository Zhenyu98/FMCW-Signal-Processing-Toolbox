function [z, R] = BuildMeasurementNoise(candidate, ekfParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : BuildMeasurementNoise.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Build EKF measurement and R from one centroid
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if isfield(candidate, 'sphere_position')
    z = candidate.sphere_position(:);
else
    error('candidate must contain sphere_position.')
end

if isfield(ekfParams, 'MeasurementPosition') && ...
        strcmpi(char(string(ekfParams.MeasurementPosition)), 'plain') && ...
        isfield(candidate, 'sphere_position_plain')
    z = candidate.sphere_position_plain(:);
end

RMode = getStructText(ekfParams, 'RMode', 'clusterVar');
if strcmpi(RMode, 'custom')
    if ~isfield(ekfParams, 'RBuilder') || isempty(ekfParams.RBuilder)
        error('ekfParams.RBuilder is required when ekfParams.RMode = custom.')
    end
    R = ekfParams.RBuilder(candidate, ekfParams);
    R = (R + R') / 2;
    return
end

if isfield(ekfParams, 'RFixed') && ~isempty(ekfParams.RFixed)
    RFixed = ekfParams.RFixed;
elseif isfield(ekfParams, 'R0') && ~isempty(ekfParams.R0)
    RFixed = ekfParams.R0;
else
    RFixed = eye(4);
end

switch lower(RMode)
    case 'fixed'
        R = RFixed;
    case {'clustervar', 'cluster', 'centroidvar'}
        RBase = getBaseR(ekfParams);
        rangeVar = max(getCandidateNumber(candidate, 'rangeVar', 0), ...
            getStructNumber(ekfParams, 'R_floor_range', eps));
        azimuthVar = max(getCandidateNumber(candidate, 'azimuthVar', 0), ...
            getStructNumber(ekfParams, 'R_floor_azimuth', eps));
        elevationVar = max(getCandidateNumber(candidate, 'elevationVar', 0), ...
            getStructNumber(ekfParams, 'R_floor_elevation', eps));
        dopplerVar = max(getCandidateNumber(candidate, 'dopplerVar', 0), ...
            getStructNumber(ekfParams, 'R_floor_velocity', eps));
        R = RBase + diag([rangeVar, azimuthVar, elevationVar, dopplerVar]);
    otherwise
        error('Unknown ekfParams.RMode: %s', RMode)
end

R = (R + R') / 2;

end

function RBase = getBaseR(ekfParams)
if isfield(ekfParams, 'R0') && ~isempty(ekfParams.R0)
    RBase = ekfParams.R0;
else
    RBase = zeros(4, 4);
end
end

function value = getCandidateNumber(candidate, fieldName, defaultValue)
if isfield(candidate, fieldName) && ~isempty(candidate.(fieldName)) && ...
        isfinite(candidate.(fieldName))
    value = double(candidate.(fieldName));
else
    value = defaultValue;
end
end

function value = getStructText(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = char(string(s.(fieldName)));
else
    value = defaultValue;
end
end

function value = getStructNumber(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = double(s.(fieldName));
else
    value = defaultValue;
end
end
