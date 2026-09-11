function cfgOut = ConfigurePointCloudParameter(sensorParams, radarParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : ConfigurePointCloudParameter.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Build point cloud processing parameters from radarParams
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cfgOut.Mode = getFieldOrDefault(sensorParams, 'Mode', 1);
cfgOut.ADCNum = radarParams.nSample;
cfgOut.ChirpNum = radarParams.PulseNum;
cfgOut.Frame = getFieldOrDefault(sensorParams, 'PointCloudFrame', 1);
cfgOut.numTx = radarParams.TxNum;
cfgOut.numRx = radarParams.RxNum;
cfgOut.applyVmaxExtend = getFieldOrDefault(sensorParams, 'applyVmaxExtend', 0);
cfgOut.min_dis_apply_vmax_extend = getFieldOrDefault(sensorParams, 'min_dis_apply_vmax_extend', 10);

cfgOut.startFreq = radarParams.f_0;
cfgOut.fs = radarParams.Fs;
cfgOut.Slope = radarParams.K;
cfgOut.validB = radarParams.B;
cfgOut.totalB = radarParams.B;
cfgOut.Tc = radarParams.Ta;              % single-Tx chirp interval used by the signal model
cfgOut.ValidTc = radarParams.Ta;
cfgOut.fc = radarParams.fc;

cfgOut.Pt = getFieldOrDefault(sensorParams, 'Pt', 12);
cfgOut.Fn = getFieldOrDefault(sensorParams, 'Fn', 12);
cfgOut.Ls = getFieldOrDefault(sensorParams, 'Ls', 3);

cfgOut.arrdx = radarParams.VirtualArrayUnit_m / radarParams.lambda;
cfgOut.arrdy = cfgOut.arrdx;
cfgOut.antennaPhase = zeros(1, radarParams.ArrayNum);

virtualPosIndex = getVirtualPosIndex(radarParams);
rxId = zeros(radarParams.ArrayNum, 1);
txId = zeros(radarParams.ArrayNum, 1);
for virtualIdex = 1:radarParams.ArrayNum
    txId(virtualIdex) = ceil(virtualIdex / radarParams.RxNum);
    rxId(virtualIdex) = mod(virtualIdex - 1, radarParams.RxNum) + 1;
end

aziArr = virtualPosIndex(:, 1);
eleArr = virtualPosIndex(:, 3);
aziArr = aziArr - min(aziArr);
eleArr = eleArr - min(eleArr);

virtual_array.azi_arr = aziArr;
virtual_array.ele_arr = eleArr;
virtual_array.rx_id = rxId;
virtual_array.tx_id = txId;
virtual_array.virtual_arr = [aziArr, eleArr, rxId, txId];

[~, noredundant_idx] = unique(virtual_array.virtual_arr(:, 1:2), 'rows');
virtual_array.noredundant_arr = virtual_array.virtual_arr(sort(noredundant_idx), :);
virtual_array.noredundant_aziarr = virtual_array.noredundant_arr(virtual_array.noredundant_arr(:, 2) == 0, :);
redundant_idx = setxor(1:radarParams.ArrayNum, noredundant_idx);
virtual_array.redundant_arr = virtual_array.virtual_arr(redundant_idx, :);
virtual_array.info_overlaped_diff1tx = [];

cfgOut.virtual_array = virtual_array;

cfgOut.sigSpaceIdx = [aziArr.' + 1; eleArr.' + 1];
cfgOut.sigIdx = [rxId.'; txId.'];

if isfield(radarParams, 'VirtualArrayMap')
    cfgOut.VirtualArrayMap = radarParams.VirtualArrayMap;
end
if isfield(radarParams, 'ArrayType')
    cfgOut.ArrayType = radarParams.ArrayType;
end

end

function virtualPosIndex = getVirtualPosIndex(radarParams)
if isfield(radarParams, 'VirtualPosIndex') && ~isempty(radarParams.VirtualPosIndex)
    virtualPosIndex = radarParams.VirtualPosIndex;
else
    virtualPosIndex = round(radarParams.VirtualPos_m / radarParams.VirtualArrayUnit_m);
end
end

function value = getFieldOrDefault(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName)
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end
