function adcData = RadarCubeToPointCloudInput(data)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : RadarCubeToPointCloudInput.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Convert radar cube to point cloud processing input
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ndims(data) == 3
    adcData = data;
    return
end

if ndims(data) ~= 4
    error('data must be SampleNum x ChirpNum x RxNum x TxNum or SampleNum x ChirpNum x ArrayNum.');
end

[SampleNum, ChirpNum, RxNum, TxNum] = size(data);
adcData = reshape(data, SampleNum, ChirpNum, RxNum * TxNum);

end
