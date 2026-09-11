function [trackingParams, ekfParams] = ConfigureTrackingParameter(sensorParams, radarParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : ConfigureTrackingParameter.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Build point-cloud tracking parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1
    sensorParams = struct();
end
if nargin < 2
    radarParams = struct();
end

%% tracking parameters
trackingParams.Coordinate.Enable = false;
trackingParams.Coordinate.Rotation = eye(3);
trackingParams.Coordinate.Translation = [0, 0, 0];

trackingParams.Cluster.Method = 'DBSCAN';
trackingParams.Cluster.Dimension = 'XY';
trackingParams.Cluster.DBSCAN_epsilon = 0.75;
trackingParams.Cluster.DBSCAN_MinPts = 2;
trackingParams.Cluster.UseFallbackStrongest = true;

trackingParams.Centroid.WeightMode = 'SNR';
trackingParams.Centroid.RangeVarFloor = getRangeFloor(radarParams);
trackingParams.Centroid.AzimuthVarFloor = deg2rad(1.5)^2;
trackingParams.Centroid.ElevationVarFloor = deg2rad(1.5)^2;
trackingParams.Centroid.DopplerVarFloor = getDopplerFloor(radarParams);

trackingParams.Association.Method = 'GNN';
trackingParams.Association.UseGNN = true;
trackingParams.Association.GateProbability = 0.99;
trackingParams.Association.GateDim = 4;
trackingParams.Association.GateThreshold = ChiSquareGate( ...
    trackingParams.Association.GateProbability, trackingParams.Association.GateDim);
trackingParams.Association.CostMode = 'mahalanobis_logdet';
trackingParams.Association.Solver = 'hungarian';
trackingParams.Association.CostOfNonAssignment = [];
trackingParams.Association.MaxExactAssignmentSize = 8;

trackingParams.Track.CreateNewTracks = true;
trackingParams.Track.MaxTrackNum = 20;
trackingParams.Track.MaxNewTracksPerFrame = 3;
trackingParams.Track.MinConfirmHits = 2;
trackingParams.Track.MaxCoast = 5;
trackingParams.Track.StateLogic = 'TI-GTRACK';
trackingParams.Track.Detect2ActiveThreshold = trackingParams.Track.MinConfirmHits;
trackingParams.Track.Detect2FreeThreshold = 2;
trackingParams.Track.Active2FreeThreshold = [];
trackingParams.Track.MinAssociatedPoints = 1;
trackingParams.Track.UseVisibilityDelete = true;
trackingParams.Track.AgeThreshold = 5;
trackingParams.Track.MinTentativeVisibility = 0.34;
trackingParams.Track.MinConfirmedVisibility = 0.20;

%% EKF parameters
TF = getFrameInterval(sensorParams, radarParams);
range_res = getStructNumber(radarParams, 'range_res', 0.1);
doppler_res = abs(getStructNumber(radarParams, 'doppler_res', 0.1));

ekfParams.TF = TF;
ekfParams.F = [1,0,0,TF,0,0;
               0,1,0,0,TF,0;
               0,0,1,0,0,TF;
               0,0,0,1,0,0;
               0,0,0,0,1,0;
               0,0,0,0,0,1];

sigma_q = 1.2;
Gamma = [TF^2/2, 0,      0;
         0,      TF^2/2, 0;
         0,      0,      TF^2/2;
         TF,     0,      0;
         0,      TF,     0;
         0,      0,      TF];
ekfParams.Q = Gamma * Gamma' * sigma_q^2;
ekfParams.P0 = diag([0.40^2, 0.40^2, 0.30^2, 0.40^2, 0.40^2, 0.30^2]);

ekfParams.R0 = diag([(0.90 * range_res)^2, ...
                     deg2rad(4.0)^2, ...
                     deg2rad(4.0)^2, ...
                     (0.80 * doppler_res)^2]);
ekfParams.RFixed = ekfParams.R0;
ekfParams.RMode = 'clusterVar';
ekfParams.RBuilder = [];

ekfParams.R_floor_range = (0.35 * range_res)^2;
ekfParams.R_floor_azimuth = deg2rad(1.5)^2;
ekfParams.R_floor_elevation = deg2rad(1.5)^2;
ekfParams.R_floor_velocity = (0.25 * doppler_res)^2;

end

function TF = getFrameInterval(sensorParams, radarParams)
if isfield(sensorParams, 'Frame_Repetition_Period_ms') && ...
        ~isempty(sensorParams.Frame_Repetition_Period_ms)
    TF = sensorParams.Frame_Repetition_Period_ms / 1000;
elseif isfield(radarParams, 'TF') && ~isempty(radarParams.TF)
    TF = radarParams.TF;
else
    TF = 0.05;
end
end

function floorVal = getRangeFloor(radarParams)
range_res = getStructNumber(radarParams, 'range_res', 0.1);
floorVal = (0.35 * range_res)^2;
end

function floorVal = getDopplerFloor(radarParams)
doppler_res = abs(getStructNumber(radarParams, 'doppler_res', 0.1));
floorVal = (0.25 * doppler_res)^2;
end

function value = getStructNumber(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = double(s.(fieldName));
else
    value = defaultValue;
end
end
