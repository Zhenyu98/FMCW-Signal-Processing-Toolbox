function tests = test_RAM_angle_axis
% Pin: imaging/RAM.m 的 angle_axis 必须是与 fftshift bin 对齐的 sinθ→asin 网格，
% 不能用度数等间距 linspace(-90, 90, N)。
%
% RAM 内部对阵列维做 angle-FFT (fftshift(fft(...)))，输出在空间频率 (sinθ) 上
% 等间距；用 linspace(-90,90) 当角度轴会让整张图角度错位，且 DC bin 上没有 0° 采样。
% 正确写法：sinGrid = ((0:N-1)-floor(N/2))/N*2;  angle = asind(sinGrid)。
%
% Run from project root:
%   >> startup
%   >> runtests('tests/imaging/test_RAM_angle_axis.m')

tests = functiontests(localfunctions);
end

function sp = sensorFixture()
% RAM 只用这三项算 range_res，不影响 angle_axis。
sp.Slope_MHzperus = 19.988;
sp.Sampling_Rate_ksps = 5000;
sp.Samples_per_Chirp = 8;
end

function test_dc_bin_maps_to_zero_degree(testCase)
% angle_axis 在 DC bin (index floor(N/2)+1) 必须精确为 0°。
data = ones(8, 4, 8);   % SampleNum × ChirpNum × ArrayNum (3D 路径)
FFTpoints = 180;

[~, ~, angle_axis] = RAM(data, sensorFixture(), FFTpoints, false);

dcIdx = floor(FFTpoints / 2) + 1;
verifyEqual(testCase, angle_axis(dcIdx), 0, 'AbsTol', 1e-9);
end

function test_axis_monotonic_and_within_pm90(testCase)
% sinθ 等间距 → asind 后单调递增，且落在 [-90, 90]。
data = ones(8, 4, 8);
FFTpoints = 180;

[~, ~, angle_axis] = RAM(data, sensorFixture(), FFTpoints, false);

verifyGreaterThanOrEqual(testCase, min(angle_axis), -90);
verifyLessThanOrEqual(testCase, max(angle_axis), 90);
verifyTrue(testCase, all(diff(angle_axis) > 0));
end
