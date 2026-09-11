function tests = test_azimuthDOA_dc_alignment
% Pin: angle-FFT 必须把 DC bin (sinθ=0) 精确映射到 0°。
%
% 旧实现用 freqGrids = linspace(-pi, pi, N)，把 sinθ=0 放在 fftshift 真实
% DC 位置偏半个 bin 的地方，broadside 目标 (0°) 会被估成 ~0.22° (N=256)，
% 且偏差在大角度端放大。修复后用与 fftshift bin 对齐的 sinθ 网格：
%   sinGrid = ((0:N-1) - floor(N/2)) / N * 2;  angleVal = asind(sinGrid(Idx));
%
% Run from project root:
%   >> startup
%   >> runtests('tests/pointcloud/test_azimuthDOA_dc_alignment.m')

tests = functiontests(localfunctions);
end

function test_broadside_target_maps_to_exact_zero(testCase)
% λ/2 ULA broadside 平面波 → 峰落在 DC bin → 角度必须是精确 0°。
cfgDOA.AziMethod = 'FFT';
cfgDOA.FFTNum = 256;
cfgDOA.AzisigNum = 1;
arrData = exp(1j * pi * sind(0) * (0:7).');   % broadside, 即全 1 向量

doaOut = azimuthDOA(arrData, cfgDOA);

verifyEqual(testCase, doaOut.angleVal(1), 0, 'AbsTol', 0.05);
end
