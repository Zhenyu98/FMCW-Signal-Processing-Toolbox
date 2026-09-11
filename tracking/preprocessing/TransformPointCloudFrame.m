function frame_data_out = TransformPointCloudFrame(frame_data, coordinateParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : TransformPointCloudFrame.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Optional coordinate transform for standard point cloud
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

frame_data_out = frame_data;
if isempty(frame_data)
    return
end
if nargin < 2 || ~isstruct(coordinateParams)
    return
end
if ~getStructLogical(coordinateParams, 'Enable', false)
    return
end

R = getStructMatrix(coordinateParams, 'Rotation', eye(3));
t = getStructVector(coordinateParams, 'Translation', [0, 0, 0], 3);

xyz = frame_data(:,1:3);
xyzNew = (R * xyz.').' + t(:).';
range = sqrt(sum(xyzNew.^2, 2));
azimuth = atan2d(xyzNew(:,1), xyzNew(:,2));
elevation = atan2d(xyzNew(:,3), sqrt(xyzNew(:,1).^2 + xyzNew(:,2).^2));

frame_data_out(:,1:3) = xyzNew;
frame_data_out(:,4) = range;
frame_data_out(:,5) = azimuth;
frame_data_out(:,6) = elevation;

end

function value = getStructLogical(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = logical(s.(fieldName));
else
    value = defaultValue;
end
end

function value = getStructMatrix(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = double(s.(fieldName));
else
    value = defaultValue;
end
end

function value = getStructVector(s, fieldName, defaultValue, expectedNum)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = double(s.(fieldName));
else
    value = defaultValue;
end
value = value(:).';
if length(value) ~= expectedNum
    error('%s must contain %d values.', fieldName, expectedNum)
end
end
