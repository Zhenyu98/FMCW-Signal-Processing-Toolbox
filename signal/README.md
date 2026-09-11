# signal

`signal/` 是 FMCW 雷达信号生成模块，主要用于仿真点目标、多散射点复杂目标和动态轨迹 radar cube。

当前入口分成两步：

```matlab
radarParams = RadarParameterGenerate(sensorParams, targetParams);
[data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);
```

这样做的目的很简单：`RadarParameterGenerate` 只负责雷达参数和阵列参数推导，`RadarCubeGenerate` 负责根据目标生成信号，并在需要时统一加入观测噪声。

## Data Format

`RadarCubeGenerate` 输出：

```matlab
% nSample x PulseNum x RxNum x TxNum
data(tIdex, pIdex, rxIdex, txIdex)
```

其中：

- `nSample`：每个 chirp 的 ADC sample 数。
- `PulseNum`：每帧 TDM cycle 数，也就是每个 Tx 都发射一遍后的慢时间数量。
- `RxNum`：接收天线数。
- `TxNum`：TDM 发射天线数，顺序由 `ArrayType` 或自定义 map 决定。

## Basic Usage

常速度点目标仍然使用原来的参数写法：

```matlab
sensorParams.Start_Freq_GHz = 77;
sensorParams.Slope_MHzperus = 3.04;
sensorParams.Sampling_Rate_ksps = 5000;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 64;
sensorParams.TxNum = 3;
sensorParams.RxNum = 4;
sensorParams.ArrayType = 'TI_xWRx843';
sensorParams.SNR_dB = 20;               % Optional. Remove this field for clean data

targetParams.amplitude = [8, 12];
targetParams.range = [7.00, 7.50];
targetParams.velocity = [-0.2, 0.5];
targetParams.azimuth = [0, 10];
targetParams.elevation = [0, 5];

radarParams = RadarParameterGenerate(sensorParams, targetParams);
rng(2026)
[data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);
```

## Target Modes

`RadarCubeGenerate` 现在支持两类目标输入。

第一类是点目标 / 常速度散射点：

```matlab
targetParams.amplitude = [8, 12];
targetParams.range = [7.00, 7.50];          % Range (m)
targetParams.velocity = [-0.2, 0.5];        % Radial velocity (m/s)
targetParams.azimuth = [0, 10];             % Azimuth angle (degree)
targetParams.elevation = [0, 5];            % Elevation angle (degree)
```

第二类是笛卡尔坐标散射点。注意下面写的是 MATLAB 语法，`ScatterNum` 是散射点个数：

```matlab
ScatterNum = 6;
targetParams.position_m = zeros(ScatterNum, 3);

% position_m 的每一行是一个散射点 [x, y, z]，单位 m
targetParams.position_m = [
    0.00, 10.00, 1.70
    0.00, 10.00, 1.20
   -0.35, 10.05, 1.25
    0.35, 10.05, 1.25
   -0.15,  9.95, 0.10
    0.15,  9.95, 0.10
];

targetParams.amplitude = [5, 10, 3, 3, 2, 2];
```

坐标约定和点云一致：

```matlab
% x: horizontal / azimuth direction
% y: radar boresight / range direction
% z: vertical / elevation direction
```

`position_m` 可以有两种尺寸：

```matlab
% Static scatterers inside one radar frame:
% size(targetParams.position_m) should be [ScatterNum, 3]

% Chirp-level dynamic scatterers:
% size(targetParams.position_m) should be [ScatterNum, 3, PulseNum]
```

上面是尺寸说明。真正初始化时写：

```matlab
targetParams.position_m = zeros(ScatterNum, 3);
targetParams.position_m = zeros(ScatterNum, 3, radarParams.PulseNum);
```

如果使用 chirp-level 轨迹，第 `pIdex` 个 chirp 使用：

```matlab
targetParams.position_m(scatterIdex, :, pIdex)
```

这适合 Kinect / RealSense / Boulic / VICON 这类人体骨架或手势轨迹。

可选速度输入：

```matlab
targetParams.velocity_mps = zeros(ScatterNum, 3);
```

`velocity_mps` 的每一行是一个散射点的 `[vx, vy, vz]`，单位 m/s。它主要用于 frame-level 动态：外部每个人体姿态 frame 调一次 `RadarCubeGenerate`，同时给当前姿态下的散射点速度，让一个 radar frame 内仍然保留 Doppler 相位。

振幅可以写成：

```matlab
targetParams.amplitude = 1;                         % All scatterers use same amplitude
targetParams.amplitude = ones(ScatterNum, 1);       % Fixed amplitude per scatterer
targetParams.amplitude = ones(ScatterNum, PulseNum); % Chirp-level amplitude
```

如果 `position_m` 模式下不提供 `amplitude`，默认所有散射点幅度为 1。

典型选择：

- 点目标或普通多目标：用 `range / velocity / azimuth / elevation`。
- STL 或某一帧人体姿态：用 `position_m = zeros(ScatterNum, 3)` 这种静态复杂目标。
- frame-level 人体移动：外部循环更新 `position_m`，必要时同时给 `velocity_mps`。
- micro-Doppler / 手势 / 非刚体动作：用 `position_m = zeros(ScatterNum, 3, PulseNum)`。

## Noise / SNR

默认不设置 `sensorParams.SNR_dB` 时，`RadarCubeGenerate` 输出干净 radar cube：

```matlab
radarParams = RadarParameterGenerate(sensorParams, targetParams);
data = RadarCubeGenerate(targetParams, radarParams);
```

如果需要给仿真观测加入复高斯白噪声，直接在 `sensorParams` 中设置：

```matlab
sensorParams.SNR_dB = 20;
radarParams = RadarParameterGenerate(sensorParams, targetParams);
rng(2026)                                      % Reproducible noise
[data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);
```

`noiseInfo` 会记录实际使用的：

```matlab
noiseInfo.SNR_dB
noiseInfo.signalPower
noiseInfo.noisePower
noiseInfo.noiseStd
```

这样点云、成像或超分辨率 demo 不需要各自再写一份加噪声逻辑。

## Radar Parameters

`RadarParameterGenerate` 会显式计算常用物理量：

```matlab
radarParams.f_0
radarParams.K
radarParams.Fs
radarParams.Ts
radarParams.nSample
radarParams.PulseNum
radarParams.TxNum
radarParams.RxNum
radarParams.Ta
radarParams.Tc
radarParams.TF
radarParams.B
radarParams.fc
radarParams.lambda
radarParams.range_res
radarParams.doppler_res
radarParams.angle_res
radarParams.range_axis
radarParams.doppler_axis
```

`fc` 的默认值是：

```matlab
fc = f_0 + B / 2;
```

如果需要和旧实验或硬件配置严格一致，可以显式指定：

```matlab
sensorParams.Center_Freq_Hz = 79e9;
```

阵元单位间距默认是 `lambda / 2`。如果需要旧实验里的 `d = 1e-3`，可以写：

```matlab
sensorParams.Antenna_Spacing_m = 1e-3;
```

## Virtual Array

推荐优先使用 `ArrayType`：

```matlab
sensorParams.ArrayType = 'TI_xWRx843';       % xWR1843 / xWR6843 ISK style
sensorParams.ArrayType = 'TI_xWRx843_ODS';   % xWR6843 ODS / AOP style
sensorParams.ArrayType = 'TI_xWRx642';       % xWR1642 style
```

`TI_xWRx843` 对应的虚拟阵列图为：

```matlab
sensorParams.VirtualArrayMap = [
    NaN NaN 8   9   10  11 NaN NaN
    0   1   2   3   4   5   6   7
];
```

`TI_xWRx843_ODS` 默认 map 为：

```matlab
sensorParams.VirtualArrayMap = [
    0   3   8   11
    1   2   9   10
    NaN NaN 4   7
    NaN NaN 5   6
];
```

`TI_xWRx642` 默认 map 为：

```matlab
sensorParams.VirtualArrayMap = 0:7;
```

也可以直接手写自定义 map：

```matlab
sensorParams.TxNum = 3;
sensorParams.RxNum = 4;
sensorParams.VirtualArrayMap = [
    NaN NaN 8   9   10  11 NaN NaN
    0   1   2   3   4   5   6   7
];
```

map 里的数字是 virtual channel index，从 `0` 到 `TxNum*RxNum-1`。`NaN` 表示该位置没有虚拟阵元。

内部会转换成：

```matlab
radarParams.VirtualArrayMap
radarParams.VirtualPos_m
radarParams.VirtualArrayUnit_m
```

`RadarCubeGenerate` 只使用 `radarParams.VirtualPos_m` 计算阵列相位。

## Angle Convention

坐标约定：

```matlab
% x: horizontal array aperture, controls azimuth phase
% y: radar boresight / range direction
% z: vertical array aperture, controls elevation phase
```

目标方向向量为：

```matlab
directionVec = [cosd(elevation) * sind(azimuth), ...
                cosd(elevation) * cosd(azimuth), ...
                sind(elevation)];
```

阵列路径差为：

```matlab
arrayPath = dot(VirtualPos_m(virtualIdex, :), directionVec);
tau = (2 * InstantRange + arrayPath) / c;
```

因此 `azimuth` 和 `elevation` 都会进入信号模型。

## TDM-MIMO Timing

信号生成包含 TDM 发射时序：

```matlab
slowTime = (pIdex - 1) * Tc;
Txdelay = (txIdex - 1) * Ta;
t = fastTime + slowTime + Txdelay;
InstantRange = InitRange + V(targetIdex) * t;
```

这意味着运动目标在不同 Tx 发射时刻的距离不同，TDM 带来的运动相位会自然进入信号。

如果使用 `position_m` 模式：

- `position_m` 是 `ScatterNum-by-3` 时，散射点在一个 radar frame 内位置固定；如果同时给 `velocity_mps`，会按 `t` 在 frame 内推进位置。
- `position_m` 是 `ScatterNum-by-3-by-PulseNum` 时，`position_m(:,:,pIdex)` 已经包含第 `pIdex` 个 chirp 的慢时间位置；此时 `velocity_mps` 只用于补充一个 chirp 内的 fast-time / TDM Txdelay 运动。

注意：这里不做 Doppler compensation。补偿应该放在点云或 DOA 处理阶段，例如 `pointcloud/compensate_doppler.m`。

## Compatibility With The Old ULA Model

旧版 `utils/RadarCubeGenerate.m` 已经从 `utils/` 清理，正式入口只保留
`signal/RadarCubeGenerate.m`。如果需要复现旧版 3Tx4Rx 一维 ULA 模型，使用下面
条件即可和旧模型逐点一致：

```matlab
sensorParams.Center_Freq_Hz = 79e9;
sensorParams.Antenna_Spacing_m = 1e-3;
% 不设置 ArrayType / VirtualArrayMap
targetParams.elevation = zeros(size(targetParams.range));
```

验证结果：

```text
range_res_utils   = 7.95289839770798
range_res_signal  = 7.95289839770798
oldlike_nmse      = 0
oldlike_maxerr    = 0
```

如果启用真实阵列图：

```matlab
sensorParams.ArrayType = 'TI_xWRx843';
```

那么非零方位角下和旧版线阵模型不再一致，这是预期结果。旧模型默认把 3Tx4Rx
当成 12 阵元一维 ULA；`TI_xWRx843` 则使用真实的 8 个水平虚拟阵元加 4 个俯仰虚拟阵元。

本次测试中，目标方位角包含 `18 deg` 时：

```text
arraytype_1843_nmse   = 3.9122875269354329e-01
arraytype_1843_maxerr = 1.5955789525346946
```

而所有目标都在 broadside，即 `azimuth = 0`、`elevation = 0` 时：

```text
arraytype_1843_broadside_nmse   = 0
arraytype_1843_broadside_maxerr = 0
```

所以结论是：

- 旧线阵兼容模式：和原始 `utils` 输出一致。
- 真实 `ArrayType` 阵列模式：非零角度下会和原始 `utils` 不一致，因为阵列几何已经不同。

## Demo

点目标 / 常速度散射点 demo：

```matlab
demo_generate_radar_cube
```

这个 demo 使用：

```matlab
sensorParams.ArrayType = 'TI_xWRx843';
```

如果需要复现旧版线阵结果，把 demo 里的阵列配置改成：

```matlab
sensorParams.TxNum = 3;
sensorParams.RxNum = 4;
sensorParams.Center_Freq_Hz = 79e9;
sensorParams.Antenna_Spacing_m = 1e-3;
```

并且不要设置 `ArrayType` 或 `VirtualArrayMap`。

人体运动回波 demo：

```matlab
demo_human_motion_radar_echo
```

这个 demo 用一个简化人体骨架生成：

```matlab
targetParams.position_m = Position_m;      % ScatterNum x 3 x PulseNum
targetParams.amplitude = scatterAmp;       % ScatterNum x 1
```

然后复用：

```matlab
[data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);
```

脚本里可以直接改：

```matlab
humanParams.Initial_Position_m
humanParams.Body_Velocity_mps
humanParams.Height_m
humanParams.Gait_Frequency_Hz
humanParams.Arm_Swing_m
humanParams.Leg_Swing_m
```

运行后会画：

- 人体散射点起始 / 中间 / 结束姿态。
- 单通道 range-Doppler map。
- micro-Doppler signature。
- range peak 是否落在人体散射点距离包络里的 sanity check。

当前 demo 不是把 Boulic/Kinect/RealSense 项目整包复制进来，而是内化它们最关键的接口形式：

```matlab
% each scatterer has one 3-D position at each chirp
position_m(scatterIdex, xyzIdex, pIdex)
```

后续如果有真实 Kinect、RealSense、VICON 或 Boulic 骨架数据，只需要把骨架轨迹插值到 `radarParams.PulseNum` 个 chirp，并按本工具箱坐标约定填进 `targetParams.position_m`。

## Optional MathWorks Signal Sources

本模块支持在信号生成步骤切换到 MathWorks 官方 waveform-level 模型，
而后续继续使用本工具箱的 `RDM`、点云或论文处理链。

点目标入口：

```matlab
[data, sourceInfo] = RadarCubeGenerateMathWorksIdeal(targetParams, radarParams, sourceOptions);
```

该入口使用 `Radar Toolbox` 的 `radarTransceiver` 生成宽带 FMCW 回波，
再执行 `dechirp` 和 ADC 速率抽取。当前已验证：

```text
clean static and moving single point target
single Tx / single Rx / single chirp range profile
TI_xWRx642 2Tx4Rx TDM cube at 0 deg and 15 deg azimuth
TI_xWRx843 3Tx4Rx TDM cube at 15 deg azimuth and 5 deg elevation
TI_xWRx843 moving 3Tx4Rx TDM cube and local pointcloud dominant target
```

为了保持现有 `pointcloud/` 与 DOA 的虚拟阵列相位约定，适配器在调用
MathWorks array model 时对阵元位置采用符号映射；这个映射已经通过非零
方位角的 cube NMSE 检查。

官方行人入口：

```matlab
[data, sourceInfo, pedestrianInfo] = RadarCubeGenerateMathWorksPedestrian( ...
    pedestrianParams, radarParams, sourceOptions);
```

该入口直接调用 `backscatterPedestrian` 的 16 段官方人体散射模型。
SISO 模式用于本地 range-Doppler / micro-Doppler 处理；`TI_xWRx843`
模式把官方 `reflect` 回波按身体段线性分解，并通过各 Tx / 身体段 / Rx
自由空间路径构造 TDM-MIMO cube，可直接进入本地点云流程。阵元位置符号映射
与点目标源一致，用于保持已有 DOA 坐标约定。

这里验证的是 clean waveform-level 官方人体信号和本地点云数据契约，
不表示 TI board-specific frontend、室内多径或真实人体 RCS 已完成校准。

官方两径入口：

```matlab
[data, sourceInfo, multipathInfo] = RadarCubeGenerateMathWorksTwoRay( ...
    targetParams, radarParams, multipathParams, sourceOptions);
```

该入口使用官方 `widebandTwoRayChannel` 产生直达与地面反射组合回波。当前验证的是
人为设置为可分辨的静态两径几何：SISO 验证三类表观距离峰，
`TI_xWRx843` TDM-MIMO 验证虚拟通道回波、距离峰和本地点云入口。
它不是自动室内多径场景或真实环境校准模型。

统一 MIMO 切换 demo：

```matlab
demo_mathworks_signal_source_switch
```

编辑脚本顶部的 `signalSource` 即可选择；四个选项都输出
`TI_xWRx843` 的 `SampleNum x ChirpNum x 4 x 3` radar cube：

```text
local_point
mathworks_point
mathworks_pedestrian
mathworks_two_ray
```

验证入口：

```matlab
run('validation/validate_mathworks_ideal_point_target_source.m')
run('validation/validate_mathworks_moving_point_target_source.m')
run('validation/validate_mathworks_pedestrian_signal_source.m')
run('validation/validate_mathworks_pedestrian_mimo_pointcloud_source.m')
run('validation/validate_mathworks_two_ray_signal_source.m')
run('validation/validate_mathworks_two_ray_mimo_pointcloud_source.m')
```

这些路径不是 TI digital twin。当前选择 generic `radarTransceiver`、
`backscatterPedestrian` 与 `widebandTwoRayChannel`，是为了先引入官方信号/场景能力
并保持处理数据契约；TI board-specific frontend 可在后续作为另一种高保真源接入。
