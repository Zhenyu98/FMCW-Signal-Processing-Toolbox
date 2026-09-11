function sensorParams = ConfigureVirtualArray(sensorParams, arrayType)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : ConfigureVirtualArray.m
% Date & time         : May. 2026
% Version             : 1.1
% Purpose             : Configure Tx/Rx antenna positions from readable maps
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin >= 2 && ~isempty(arrayType)
    sensorParams.ArrayType = arrayType;
end

if hasFieldValue(sensorParams, 'ArrayType')
    arrayType = char(sensorParams.ArrayType);
elseif hasFieldValue(sensorParams, 'ArrayPreset')
    arrayType = char(sensorParams.ArrayPreset);
elseif hasFieldValue(sensorParams, 'VirtualArrayMap') && isequaln(sensorParams.VirtualArrayMap, tiXWR1843Map())
    arrayType = 'TI_xWRx843';
elseif hasFieldValue(sensorParams, 'VirtualArrayMap') && isequaln(sensorParams.VirtualArrayMap, tiXWRx843ODSMap_TX021())
    arrayType = 'TI_xWRx843_ODS';
elseif hasFieldValue(sensorParams, 'VirtualArrayMap') && isequaln(sensorParams.VirtualArrayMap, tiXWRx642Map())
    arrayType = 'TI_xWRx642';
else
    arrayType = 'custom';
end

unit_m = getVirtualArrayUnit(sensorParams);
sensorParams.ArrayType = arrayType;
sensorParams.VirtualArrayUnit_m = unit_m;
sensorParams.Antenna_Spacing_m = getParam(sensorParams, 'Antenna_Spacing_m', unit_m);

switch normalizeArrayType(arrayType)
    case {'ti_xwrx843', 'xwrx843', 'ti_xwr1843', 'xwr1843', 'iwr1843', 'awr1843', ...
          'ti_xwr6843isk', 'xwr6843isk', 'iwr6843isk', 'awr6843isk'}
        sensorParams.TxNum = checkOrSetCount(sensorParams, 'TxNum', 3);
        sensorParams.RxNum = checkOrSetCount(sensorParams, 'RxNum', 4);

        sensorParams.VirtualArrayMap = tiXWR1843Map();
        sensorParams.TxOrder = [1 3 2];          % Physical Tx ID in TDM firing order

        % Rows follow TDM firing order: Tx1, Tx3, Tx2.
        sensorParams.TxPosIndex = [
            0 0 0
            4 0 0
            2 0 1
        ];
        sensorParams.RxPosIndex = [
            0 0 0
            1 0 0
            2 0 0
            3 0 0
        ];

    case {'ti_xwrx843_ods', 'xwrx843_ods', 'ti_xwr6843ods', 'xwr6843ods', ...
          'iwr6843isk_ods', 'awr6843isk_ods', 'iwr6843aop', 'awr6843aop', 'xwr6843aop'}
        sensorParams.TxNum = checkOrSetCount(sensorParams, 'TxNum', 3);
        sensorParams.RxNum = checkOrSetCount(sensorParams, 'RxNum', 4);

        % Default ODS/AOP map follows the common TX0, TX2, TX1 chirp order.
        sensorParams.VirtualArrayMap = tiXWRx843ODSMap_TX021();
        sensorParams.TxOrder = [1 3 2];

    case {'ti_xwrx843_ods_tx012', 'xwrx843_ods_tx012', 'iwr6843isk_ods_tx012', ...
          'awr6843isk_ods_tx012', 'iwr6843aop_tx012', 'awr6843aop_tx012'}
        sensorParams.TxNum = checkOrSetCount(sensorParams, 'TxNum', 3);
        sensorParams.RxNum = checkOrSetCount(sensorParams, 'RxNum', 4);

        sensorParams.VirtualArrayMap = tiXWRx843ODSMap_TX012();
        sensorParams.TxOrder = [1 2 3];

    case {'ti_xwrx642', 'xwrx642', 'ti_xwr1642', 'xwr1642', 'iwr1642', 'awr1642'}
        sensorParams.TxNum = checkOrSetCount(sensorParams, 'TxNum', 2);
        sensorParams.RxNum = checkOrSetCount(sensorParams, 'RxNum', 4);

        sensorParams.VirtualArrayMap = tiXWRx642Map();
        sensorParams.TxOrder = [1 2];
        sensorParams.TxPosIndex = [
            0 0 0
            4 0 0
        ];
        sensorParams.RxPosIndex = [
            0 0 0
            1 0 0
            2 0 0
            3 0 0
        ];

    case 'custom'
        if hasFieldValue(sensorParams, 'TxPos_m') && hasFieldValue(sensorParams, 'RxPos_m')
            return
        end
        if ~hasFieldValue(sensorParams, 'VirtualArrayMap') && ...
                (~hasFieldValue(sensorParams, 'TxPosIndex') || ~hasFieldValue(sensorParams, 'RxPosIndex'))
            error('Custom array needs VirtualArrayMap, TxPosIndex/RxPosIndex, or TxPos_m/RxPos_m.');
        end

    otherwise
        error('Unknown array type: %s', arrayType);
end

if hasFieldValue(sensorParams, 'TxPosIndex')
    sensorParams.TxPos_m = sensorParams.TxPosIndex * unit_m;
end
if hasFieldValue(sensorParams, 'RxPosIndex')
    sensorParams.RxPos_m = sensorParams.RxPosIndex * unit_m;
end

if hasFieldValue(sensorParams, 'VirtualArrayMap')
    sensorParams.VirtualPosIndex = virtualPosIndexFromMap(sensorParams.VirtualArrayMap);
    checkVirtualArrayCount(sensorParams);
    sensorParams.VirtualPos_m = sensorParams.VirtualPosIndex * unit_m;
elseif hasFieldValue(sensorParams, 'TxPosIndex') && hasFieldValue(sensorParams, 'RxPosIndex')
    sensorParams.VirtualPosIndex = buildVirtualPosIndex(sensorParams.TxPosIndex, sensorParams.RxPosIndex);
    sensorParams.VirtualPos_m = sensorParams.VirtualPosIndex * unit_m;
end

end

function map = tiXWR1843Map()
map = [
    NaN NaN 8   9   10  11 NaN NaN
    0   1   2   3   4   5   6   7
];
end

function map = tiXWRx843ODSMap_TX021()
map = [
    0   3   8   11
    1   2   9   10
    NaN NaN 4   7
    NaN NaN 5   6
];
end

function map = tiXWRx843ODSMap_TX012()
map = [
    0   3   4   7
    1   2   5   6
    NaN NaN 8   11
    NaN NaN 9   10
];
end

function map = tiXWRx642Map()
map = 0:7;
end

function normalizedType = normalizeArrayType(arrayType)
normalizedType = lower(strrep(strrep(char(arrayType), '-', '_'), ' ', '_'));
end

function count = checkOrSetCount(params, fieldName, expectedCount)
if hasFieldValue(params, fieldName)
    count = params.(fieldName);
    if count ~= expectedCount
        error('%s must be %d for this virtual array type.', fieldName, expectedCount);
    end
else
    count = expectedCount;
end
end

function checkVirtualArrayCount(sensorParams)
validIndex = sensorParams.VirtualArrayMap(~isnan(sensorParams.VirtualArrayMap));
validIndex = validIndex(:).';
expectedIndex = 0:(sensorParams.TxNum * sensorParams.RxNum - 1);
if ~isequal(sort(validIndex), expectedIndex)
    error('VirtualArrayMap must contain all virtual antenna indexes from 0 to TxNum*RxNum-1.');
end
end

function virtualPosIndex = virtualPosIndexFromMap(virtualArrayMap)
validIndex = virtualArrayMap(~isnan(virtualArrayMap));
if any(abs(validIndex - round(validIndex)) > eps) || any(validIndex < 0)
    error('VirtualArrayMap must contain non-negative integer indexes.');
end
if length(unique(validIndex)) ~= length(validIndex)
    error('VirtualArrayMap contains duplicate virtual antenna indexes.');
end

virtualNum = max(validIndex) + 1;
virtualPosIndex = zeros(virtualNum, 3);
rowNum = size(virtualArrayMap, 1);
for rowIdex = 1:size(virtualArrayMap, 1)
    for colIdex = 1:size(virtualArrayMap, 2)
        virtualIdex = virtualArrayMap(rowIdex, colIdex);
        if ~isnan(virtualIdex)
            virtualPosIndex(virtualIdex + 1, :) = [colIdex - 1, 0, rowNum - rowIdex];
        end
    end
end
end

function virtualPosIndex = buildVirtualPosIndex(txPosIndex, rxPosIndex)
TxNum = size(txPosIndex, 1);
RxNum = size(rxPosIndex, 1);
virtualPosIndex = zeros(TxNum * RxNum, 3);
arrayIdex = 1;
for txIdex = 1:TxNum
    for rxIdex = 1:RxNum
        virtualPosIndex(arrayIdex, :) = txPosIndex(txIdex, :) + rxPosIndex(rxIdex, :);
        arrayIdex = arrayIdex + 1;
    end
end
end

function unit_m = getVirtualArrayUnit(sensorParams)
if hasFieldValue(sensorParams, 'VirtualArrayUnit_m')
    unit_m = sensorParams.VirtualArrayUnit_m;
elseif hasFieldValue(sensorParams, 'Antenna_Spacing_m')
    unit_m = sensorParams.Antenna_Spacing_m;
else
    c = physconst('lightspeed');
    if hasFieldValue(sensorParams, 'Center_Freq_Hz')
        fc = sensorParams.Center_Freq_Hz;
    elseif hasFieldValue(sensorParams, 'Center_Freq_GHz')
        fc = sensorParams.Center_Freq_GHz * 1e9;
    else
        f_0 = sensorParams.Start_Freq_GHz * 1e9;
        K = sensorParams.Slope_MHzperus * 1e12;
        Fs = sensorParams.Sampling_Rate_ksps * 1e3;
        Ts = 1 / Fs;
        nSample = sensorParams.Samples_per_Chirp;
        Ta = (nSample - 1) * Ts;
        B = K * Ta;
        fc = f_0 + B / 2;
    end
    unit_m = c / fc / 2;
end
end

function value = getParam(params, fieldName, defaultValue)
if hasFieldValue(params, fieldName)
    value = params.(fieldName);
else
    value = defaultValue;
end
end

function tf = hasFieldValue(params, fieldName)
tf = isfield(params, fieldName) && ~isempty(params.(fieldName));
end
