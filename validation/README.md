# validation

这个目录用于保存参考项目吸收到工具箱后的同等性验证脚本。

每次从 `0_refer_code/project_name/` 内化一段可复用代码后，建议新增：

```text
validate_project_name_equivalence.m
```

验证脚本应该用同一份输入运行：

```matlab
ref_output = reference_code(input);
new_output = toolbox_code(input);
```

然后比较关键中间变量或最终输出，例如：

```matlab
rawNmse = norm(ref_output(:) - new_output(:))^2 / (norm(ref_output(:))^2 + eps);
alpha = (new_output(:)' * ref_output(:)) / (new_output(:)' * new_output(:) + eps);
alignedNmse = norm(ref_output(:) - alpha * new_output(:))^2 / (norm(ref_output(:))^2 + eps);
```

建议验证内容：

- 信号生成：data cube size、range peak、range profile NMSE。
- 人体动态信号：signal power、range peak 是否落在人体散射点距离包络内、micro-Doppler STFT 是否有有效能量。
- 点云生成：RDM、CFAR peak、range/doppler/angle、`frame_data` 八列格式。
- 成像：image size、raw/aligned NMSE、最大峰位置、坐标轴。

验证通过后，再把对应函数写入主 `README.md` 的正式入口。

## Tracking Core Validation

tracking 模块的轻量验证入口：

```matlab
run('validation/validate_tracking_core.m')
run('validation/validate_tracking_lifecycle.m')
run('validation/validate_tracking_assignment_solver.m')
run('validation/validate_tracking_pointcloud_integration.m')
```

这个脚本直接构造标准 `frame_data` 序列，验证：

- DBSCAN centroid candidate 是否能生成。
- GNN gate / association 是否能跑通。
- EKF 航迹管理是否能形成 confirmed tracks。
- TI-GTRACK style `tentative -> confirmed -> deleted` 生命周期是否符合阈值预期。
- `SolveGlobalAssignment` 的 exact / Hungarian 是否在小规模多目标上等价于 brute-force 全局最小 cost。
- `signal -> pointcloud -> tracking` 集成链路是否能维持目标航迹。

这些脚本只用于测试验证，不作为正式工具箱 demo 入口。

## Pointcloud Reference Validation

点云模块对原始参考项目的验证入口：

```matlab
results = validate_pointcloud_equivalence(3);
```

CFAR 性能诊断入口：

```matlab
run('validation/profile_pointcloud_cfar_diagnosis.m')
```

这个脚本使用固定合成 `RDM` 对比 `phased_soca` 和 `separable_ca` 的运行时间、
CFAR 点数和 peakFocus 点数。它只做 profiling，不作为等价性结论。

RA 点云管线验证入口：

```matlab
run('validation/validate_ra_pointcloud_pipeline.m')
```

这个脚本使用两个静止 ULA 仿真点目标，验证 `GeneratePointCloudFrameRA`
和 `GeneratePointCloudFrame(..., cfgDOA.PointCloudPipeline='RA')` 输出一致，
并检查八列 `frame_data`、`RAM`、`angle_axis`、`ra_peak_list` 以及
range / azimuth 峰位误差。

OpenRadar-style 点云前端选项的单元测试：

```matlab
runtests('tests/pointcloud')
```

这里包含 `CFAR_2D` per-axis `L_bound`、`peakFocus` 的 `py_doppler`
wrap grouping，以及 `SelectDOAPeaks` 的 `py_full_variance` gamma /
sidelobe-level 规则。

`0_refer_code/` 是本地参考项目目录，已经被 `.gitignore` 排除，不属于正式工具箱源码。
如果本地没有对应参考项目或原始数据，等价性验证脚本会跳过并说明原因。

当前本地完整验证覆盖两个参考项目：

```text
0_refer_code/TDMA-MIMO 点云生成
0_refer_code/点云生成实际数据
```

验证内容包括：

- DCA1000 reader output。
- `rangeFFTOut`。
- `dopplerFFTOut`。
- `accumulateRD`。
- `cfarMap`。
- `rd_peak_list`。
- 最终八列 `frame_data`。

当前工具箱在 TDM-MIMO Doppler compensation 中使用物理一致的 Doppler bin：

```matlab
dopplerBin = dopplerIdx - ChirpNum / 2 - 1;
```

原始参考项目使用：

```matlab
dopplerBin = dopplerIdx - ChirpNum / 2;
```

所以当前验证目标分成两层：

- `reader / rangeFFT / dopplerFFT / accumulateRD / cfarMap / rd_peak_list` 应该和参考项目保持一致。
- `frame_data` 的 angle / XYZ 可以和参考项目不同，这是工具箱修正 TDM 补偿 bin 后的预期差异。

旧版兼容公式下的验证结果曾为：

```text
TDMA-MIMO simulation:
rangeFFT_nmse   = 0
dopplerFFT_nmse = 0
accumulate_nmse = 0
cfarMap_equal   = 1
rdPeak_equal    = 1
frameMaxErr     = 0

Real-data pointcloud, adc_data.bin, first 3 frames:
readerMaxAbsErr = 0
readerNmse      = 0
frameMaxErr     = 0 for frame 1, 2 and 3
```

如果当前物理一致公式下 `frame_data` 不再逐点等于参考项目，先看前端链路指标是否仍为 0 或 equal，再判断角度差异是否来自 TDM 补偿修正。

## Human Motion Signal Demo Validation

人体运动回波 demo 自带 sanity check：

```matlab
run('signal/demo_human_motion_radar_echo.m')
```

当前检查：

- `data` 的平均功率必须有效。
- range peak 必须大部分落在人体散射点 range envelope 内。
- micro-Doppler spectrogram 必须有非零有效能量。

这个验证不和外部 Boulic / Kinect 项目逐点等价，因为当前工具箱没有复制外部骨架数据和椭球 RCS 代码；它验证的是工具箱接口链路：

```matlab
human trajectory -> targetParams.position_m -> RadarCubeGenerate -> RDM / micro-Doppler
```

## MathWorks Ideal Point-Target Source Validation

第一条 MathWorks 可切换信号源检查：

```matlab
run('validation/validate_mathworks_ideal_point_target_source.m')
```

比较对象：

```text
signal/RadarCubeGenerate.m
signal/RadarCubeGenerateMathWorksIdeal.m
```

该脚本范围严格限定为 clean static point target；运动目标契约由下一节脚本单独验证。
MathWorks 路径使用 `radarTransceiver` 的 waveform-level 回波生成、`dechirp`
和 ADC 抽取；它不代表 TI digital twin 已接入，也不声明硬件保真度。

成功判据：

- 三个测试距离的 dominant range FFT bin 必须一致。
- 去除整体 complex gain 后，每个测试距离的 aligned NMSE 必须小于 `-18 dB`。
- `TI_xWRx642` 的 `2Tx4Rx` TDM cube 在 `0 deg` 和 `15 deg` 方位角下，
  dominant range FFT bin 必须一致，整体 aligned NMSE 必须小于 `-18 dB`。
- `TI_xWRx843` 的 `3Tx4Rx` TDM cube 在 `15 deg` 方位角与 `5 deg` 俯仰角下，
  dominant range FFT bin 必须一致，整体 aligned NMSE 必须小于 `-18 dB`。

本机 `MATLAB R2025b` 验证结果：

```text
True range (m)     : 3       7       12
Peak bin error     : 0       0       0
Aligned NMSE (dB) : -21.66  -22.95  -21.00
Internal Fs       : 640 MHz (128 x ADC sample rate)
TDM angle (deg)   : 0       15
TDM peak bin err  : 0       0
TDM NMSE (dB)    : -20.86  -20.89
TI_xWRx843 size  : [256 2 4 3]
TI_xWRx843 err   : 0
TI_xWRx843 NMSE  : -20.89 dB
```

首轮选择 generic `radarTransceiver`，而不直接使用 TI digital twin，是为了先
隔离 beat-signal、采样率和峰值位置的数据契约；TI board/RF/ADC 配置会在后续
单独作为高保真前端接入。

## MathWorks Moving Point-Target TDM-MIMO Validation

```matlab
run('validation/validate_mathworks_moving_point_target_source.m')
```

该脚本把 clean 单运动点目标放入 `TI_xWRx843` 的 `3Tx4Rx` cube，比较
本地解析源与 `radarTransceiver` 源的 range-Doppler 主峰、速度符号、
整体 complex-gain aligned NMSE，并将两份 cube 都送入本地点云流程检查
TDM compensation / DOA 后的主点一致性。

本机结果：

```text
Output cube size       : [256 32 4 3]
Range-Doppler bin err  : 0
Truth / estimate v     : 0.8000 / 0.7944 m/s
Aligned NMSE           : -19.03 dB
Pointcloud output      : [R 6.768, Az 15.223, El 5.450, V 0.794] for both sources
```

## MathWorks Official Pedestrian Signal Validation

```matlab
run('validation/validate_mathworks_pedestrian_signal_source.m')
```

该脚本验证 `signal/RadarCubeGenerateMathWorksPedestrian.m` 对官方
`backscatterPedestrian` 的接入。成功判据：

- 输出保持本地 `SampleNum x PulseNum x 1 x 1` cube 契约。
- 官方 16 段身体模型产生有限、非零信号功率。
- range FFT 后的慢时间信号具有非零变化能量，可继续进入 micro-Doppler 分析。

本机结果：

```text
Body segment count         : 16
Output cube size           : [64 64]
Signal power               : 2.598e-14
Slow-time variation energy : 1.631e-07
```

## MathWorks Official Pedestrian TDM-MIMO Pointcloud Validation

```matlab
run('validation/validate_mathworks_pedestrian_mimo_pointcloud_source.m')
```

该脚本验证官方 `backscatterPedestrian` 可进入 `TI_xWRx843` 的本地点云流程。
`reflect` 公开接口会合并 16 个身体段，因此适配器采用逐段线性激励分解官方
反射结果，再通过各 Tx / 身体段 / Rx 自由空间路径组成 TDM-MIMO cube。

成功判据：

- 输出保持 `SampleNum x PulseNum x RxNum x TxNum` 契约。
- 官方合成 `reflect` 输出可由 16 个逐段激励输出在数值精度内复原。
- 12 个虚拟通道均具有非零官方人体回波，并存在阵列空间差异。
- `GeneratePointCloudFrame` 输出八列 `frame_data`。
- 至少一个检测点落入官方 16 段身体位置的 range/angle 包络。

本机结果：

```text
Reflect decomposition NMSE  : -156.536 dB
Output cube size            : [128 16 4 3]
Virtual-channel power range : [7.648e-15, 1.612e-14]
Pointcloud detection count  : 3
Body range envelope         : [8.090, 8.581] m
Body azimuth envelope       : [12.170, 17.106] deg
Body elevation envelope     : [0.540, 10.386] deg
```

该测试证明官方人体源已能驱动本地点云处理；它不声明真实 TI 前端、
室内多径或实测人体反射已经完成校准。

## MathWorks Official Two-Ray Signal Validation

```matlab
run('validation/validate_mathworks_two_ray_signal_source.m')
```

该脚本验证 `signal/RadarCubeGenerateMathWorksTwoRay.m` 对官方
`widebandTwoRayChannel` 的接入。在人为设置为可分辨的高度几何下，三组两径组合
路径的表观距离必须在 range FFT 中出现。

本机结果：

```text
Expected apparent ranges : [18.03 22.48 26.93] m
Expected range bins      : [20 24 29]
Detected peak bins       : [20 24 29]
```

该测试只证明官方 two-ray 信号源和本地数据契约接通，不声明对真实室内多径完成校准。

## MathWorks Official Two-Ray TDM-MIMO Pointcloud Validation

```matlab
run('validation/validate_mathworks_two_ray_mimo_pointcloud_source.m')
```

该脚本将官方 `widebandTwoRayChannel` 扩展到 `TI_xWRx843` 的 `3Tx4Rx`
cube。每个 Tx/Rx 通道分别使用官方传播路径，阵元位置沿用本工具箱既有
虚拟阵列相位约定；随后将 cube 输入 `GeneratePointCloudFrame`。

本机结果：

```text
Output cube size            : [256 16 4 3]
Expected apparent ranges    : [18.28 22.68 27.09] m
Expected range bins         : [20 24 29]
Max virtual-channel bin err : 1
Virtual-channel power range : [4.738e-11, 5.337e-11]
Pointcloud detection count  : 3
```

这一验证覆盖可分辨地面两径的 MIMO 数据契约，不将其外推为复杂室内多反射模型。
