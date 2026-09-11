function [centroidList, centroidInfo] = GenerateCentroidMeasurement(frame_data, trackingParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : GenerateCentroidMeasurement.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Generate centroid candidates from one point-cloud frame
% -------------------------------------------------------------------------
% frame_data: X, Y, Z, Range, Azimuth, Elevation, Doppler, SNR
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 2
    trackingParams = struct();
end

centroidList = emptyCentroidList();
centroidInfo.IDX = zeros(0, 1);
centroidInfo.isnoise = false(0, 1);
centroidInfo.bestIdex = NaN;
centroidInfo.frame_data = frame_data;

if isempty(frame_data)
    return
end

clusterParams = getSubStruct(trackingParams, 'Cluster');
methodName = getStructText(clusterParams, 'Method', 'DBSCAN');
clusterInput = getClusterInput(frame_data, clusterParams);

switch lower(methodName)
    case 'dbscan'
        epsilon = getStructNumber(clusterParams, 'DBSCAN_epsilon', 0.75);
        MinPts = round(getStructNumber(clusterParams, 'DBSCAN_MinPts', 2));
        [IDX, isnoise] = DBSCANCluster(clusterInput, epsilon, MinPts);
    case 'none'
        IDX = ones(size(frame_data, 1), 1);
        isnoise = false(size(frame_data, 1), 1);
    otherwise
        error('Unknown trackingParams.Cluster.Method: %s', methodName)
end

centroidInfo.IDX = IDX;
centroidInfo.isnoise = isnoise;
clusterIdex = unique(IDX(IDX > 0 & ~isnoise));

if isempty(clusterIdex)
    useFallback = getStructLogical(clusterParams, 'UseFallbackStrongest', true);
    if useFallback
        [~, pointIdex] = max(frame_data(:,8));
        centroidList = makeCentroidFromPoints(frame_data(pointIdex,:), 1, trackingParams);
    end
else
    for kk = 1:length(clusterIdex)
        targetPoints = frame_data(IDX == clusterIdex(kk), :);
        centroidList(kk) = makeCentroidFromPoints(targetPoints, clusterIdex(kk), trackingParams); %#ok<AGROW>
    end
end

if isempty(centroidList)
    return
end

objPower = [centroidList.obj_power];
numPoints = [centroidList.numPoints];
[~, order] = sortrows([-objPower(:), -numPoints(:)], [1 2]);
centroidList = centroidList(order);
centroidInfo.bestIdex = 1;

end

function centroidNow = makeCentroidFromPoints(targetPoints, clusterIdex, trackingParams)
centroidParams = getSubStruct(trackingParams, 'Centroid');
weightMode = getStructText(centroidParams, 'WeightMode', 'SNR');
weights = getPointWeights(targetPoints, weightMode);

centroidCart = calcCentroid(targetPoints(:,1:3), weights);
centroidPlainCart = mean(targetPoints(:,1:3), 1, 'omitnan');

rangeWeighted = calcCentroid(targetPoints(:,4), weights);
azimuthWeighted = calcAngleCentroidDeg(targetPoints(:,5), weights);
elevationWeighted = calcAngleCentroidDeg(targetPoints(:,6), weights);
dopplerWeighted = calcCentroid(targetPoints(:,7), weights);

centroidPlainSphere = mean(targetPoints(:,4:7), 1, 'omitnan');
centroidNow.centroid = centroidCart;
centroidNow.centroid_plain = centroidPlainCart;
centroidNow.sphere_position = [rangeWeighted, deg2rad(azimuthWeighted), ...
    deg2rad(elevationWeighted), dopplerWeighted];
centroidNow.sphere_position_plain = [centroidPlainSphere(1), ...
    deg2rad(centroidPlainSphere(2)), deg2rad(centroidPlainSphere(3)), ...
    centroidPlainSphere(4)];
centroidNow.points = targetPoints;

rangeVar = var(targetPoints(:,4), 0, 'omitnan');
azimuthVar = deg2rad(sqrt(max(var(targetPoints(:,5), 0, 'omitnan'), 0)))^2;
elevationVar = deg2rad(sqrt(max(var(targetPoints(:,6), 0, 'omitnan'), 0)))^2;
dopplerVar = var(targetPoints(:,7), 0, 'omitnan');

centroidNow.rangeVar = max(rangeVar, getStructNumber(centroidParams, 'RangeVarFloor', eps));
centroidNow.azimuthVar = max(azimuthVar, getStructNumber(centroidParams, 'AzimuthVarFloor', eps));
centroidNow.elevationVar = max(elevationVar, getStructNumber(centroidParams, 'ElevationVarFloor', eps));
centroidNow.dopplerVar = max(dopplerVar, getStructNumber(centroidParams, 'DopplerVarFloor', eps));
centroidNow.obj_power = 10 * log10(sum(weights) + eps);
centroidNow.numPoints = size(targetPoints, 1);
centroidNow.clusterIdex = clusterIdex;
centroidNow.userData = struct();
end

function X = getClusterInput(frame_data, clusterParams)
dimensionName = getStructText(clusterParams, 'Dimension', 'XY');
switch lower(dimensionName)
    case 'xy'
        X = frame_data(:,1:2);
    case 'xyz'
        X = frame_data(:,1:3);
    case {'range-doppler', 'rd'}
        X = frame_data(:,[4,7]);
    case {'xy-doppler', 'xyv'}
        X = frame_data(:,[1,2,7]);
    otherwise
        error('Unknown trackingParams.Cluster.Dimension: %s', dimensionName)
end
end

function weights = getPointWeights(targetPoints, weightMode)
switch lower(weightMode)
    case {'snr', 'linear_snr'}
        weights = 10.^(targetPoints(:,8) / 10);
    case {'power', 'snr_power'}
        weights = max(targetPoints(:,8), 0) + eps;
    case {'uniform', 'mean'}
        weights = ones(size(targetPoints, 1), 1);
    otherwise
        error('Unknown trackingParams.Centroid.WeightMode: %s', weightMode)
end
weights = max(weights(:), eps);
end

function centroid = calcCentroid(points, weights)
centroid = sum(points .* weights, 1) / sum(weights);
end

function angleDeg = calcAngleCentroidDeg(angleDegIn, weights)
sinVal = sum(sind(angleDegIn) .* weights) / sum(weights);
cosVal = sum(cosd(angleDegIn) .* weights) / sum(weights);
angleDeg = atan2d(sinVal, cosVal);
end

function sOut = getSubStruct(sIn, fieldName)
if isstruct(sIn) && isfield(sIn, fieldName) && isstruct(sIn.(fieldName))
    sOut = sIn.(fieldName);
else
    sOut = struct();
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

function value = getStructLogical(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = logical(s.(fieldName));
else
    value = defaultValue;
end
end

function centroidList = emptyCentroidList()
centroidList = struct( ...
    'centroid', {}, ...
    'centroid_plain', {}, ...
    'sphere_position', {}, ...
    'sphere_position_plain', {}, ...
    'points', {}, ...
    'rangeVar', {}, ...
    'azimuthVar', {}, ...
    'elevationVar', {}, ...
    'dopplerVar', {}, ...
    'obj_power', {}, ...
    'numPoints', {}, ...
    'clusterIdex', {}, ...
    'userData', {});
end
