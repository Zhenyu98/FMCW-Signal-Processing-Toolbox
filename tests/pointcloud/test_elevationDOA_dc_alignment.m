function tests = test_elevationDOA_dc_alignment
% Pin: elevation angle-FFT 必须把 DC bin (sinθ=0) 精确映射到 0°。
% 与 test_azimuthDOA_dc_alignment 对称，见该文件说明。
%
% Run from project root:
%   >> startup
%   >> runtests('tests/pointcloud/test_elevationDOA_dc_alignment.m')

tests = functiontests(localfunctions);
end

function test_broadside_target_maps_to_exact_zero(testCase)
cfgDOA.EleMethod = 'FFT';
cfgDOA.FFTNum = 256;
cfgDOA.ElesigNum = 1;
arrData = exp(1j * pi * sind(0) * (0:7).');   % broadside, 即全 1 向量

doaOut = elevationDOA(arrData, cfgDOA);

verifyEqual(testCase, doaOut.angleVal(1), 0, 'AbsTol', 0.05);
end
