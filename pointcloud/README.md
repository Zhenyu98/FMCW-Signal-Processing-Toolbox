# pointcloud

`pointcloud/` 只负责 TDMA-MIMO 点云生成流程，不再维护独立的信号生成器，也不保存 DOA 算法实现。

模块边界：

```text
signal/      RadarParameterGenerate, RadarCubeGenerate
utils/       DCA1000 raw bin reading
doa/         DOA_FFT, DOA_MUSIC, DOA_IAA, ...
pointcloud/  range-Doppler, CFAR, TDM compensation, point cloud format
tracking/    centroid, GNN gate, EKF tracking from frame_data
```

## Main Entry

单帧点云入口：

```matlab
[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, IQFlag);
```

默认管线是 RD：

```text
adcData -> rdFFT -> accumulateRD -> CFAR_2D -> peakFocus
        -> Doppler compensation -> azimuth/elevation DOA -> frame_data
```

RA 管线可以直接调用，也可以通过主入口 opt-in：

```matlab
cfgDOA.PointCloudPipeline = 'RA';
[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, IQFlag);

% equivalent direct entry
[frame_data, pointcloudInfo] = GeneratePointCloudFrameRA(adcData, cfgOut, cfgDOA, IQFlag);
```

RA 管线链路：

```text
adcData -> rangeFFT -> GenerateRangeAzimuthMap -> CFAR_2D -> peakFocus
        -> angle-bin slow-time Doppler estimate -> frame_data
```

`pointcloudInfo.RAM`、`pointcloudInfo.angle_axis`、`pointcloudInfo.ra_peak_list`
会保留下来方便画图和调阈值。RA map 的数值尺度不同于 RD map，`separable_ca`
下通常需要单独设置较小的 `cfgDOA.L_bound`。当前仿真 demo / validation 使用：

```matlab
cfgDOA.CFARMethod = 'separable_ca';
cfgDOA.L_bound = 0.2;
```

RA peakFocus 默认使用 `legacy_4neighbor`。如果需要单独改 RA peak focus，
使用 `cfgDOA.RAPeakFocusMode`，不要直接复用 RD 的 `py_doppler` 诊断配置。

验证入口：

```matlab
run('validation/validate_ra_pointcloud_pipeline.m')
```

输入 `adcData` 格式：

```matlab
% SampleNum x ChirpNum x ArrayNum
```

输出点云格式：

```matlab
% frame_data: X, Y, Z, Range, Azimuth, Elevation, Doppler, SNR
frame_data = [XData, YData, ZData, range, azimuth, elevation, doppler, snr];
```

## Simulated Data Workflow

仿真点云不要再调用旧的 `GenerateAdcData / GenerateSigIQ`。正式流程是：

```matlab
sensorParams.SNR_dB = 20;                  % Optional, handled in signal/
radarParams = RadarParameterGenerate(sensorParams, targetParams);
[data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);
adcData = RadarCubeToPointCloudInput(data);

cfgOut = ConfigurePointCloudParameter(sensorParams, radarParams);
[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, 1);
```

这里：

- `RadarCubeGenerate` 属于 `signal/`。
- `RadarCubeToPointCloudInput` 只做数据维度整理。
- `ConfigurePointCloudParameter` 只把 `radarParams` 转成点云流程需要的 `cfgOut`。

MathWorks 官方行人信号也保持同一入口。对 `sensorParams.ArrayType = 'TI_xWRx843'`
可直接使用：

```matlab
[data, sourceInfo, pedestrianInfo] = RadarCubeGenerateMathWorksPedestrian( ...
    pedestrianParams, radarParams, sourceOptions);
adcData = RadarCubeToPointCloudInput(data);
[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, 1);
```

对应接口验证脚本：

```matlab
run('validation/validate_mathworks_pedestrian_mimo_pointcloud_source.m')
```

该路径使用官方 16 段人体散射并建立 TDM-MIMO 路径相位，只证明可供本地点云
处理使用，不声明真实硬件或真实环境已校准。

官方 `widebandTwoRayChannel` 地面两径源也可保持同一 `TI_xWRx843`
MIMO 点云入口：

```matlab
[data, sourceInfo, multipathInfo] = RadarCubeGenerateMathWorksTwoRay( ...
    targetParams, radarParams, multipathParams, sourceOptions);
adcData = RadarCubeToPointCloudInput(data);
[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, 1);
```

验证脚本：

```matlab
run('validation/validate_mathworks_two_ray_mimo_pointcloud_source.m')
```

干净仿真数据没有真实噪声地板，CFAR 可能把旁瓣也检出来。因此仿真点云建议在 `sensorParams.SNR_dB` 中设置观测 SNR，让 `RadarCubeGenerate` 统一加噪声。

如果某些实验仍然需要纯净信号，点云流程保留了可选的 RD 峰值后处理参数：

```matlab
cfgDOA.MinPeakSNR_dB = 30;
cfgDOA.MaxDetections = length(targetParams.range);
cfgDOA.PeakRelativeThreshold_dB = 15;
```

实测数据通常按场景调低或不设置这些字段。

## CFAR Modes

`CFAR_2D` 保留 legacy 模式，并新增轻量 separable CA-CFAR：

```matlab
cfgDOA.CFARMethod = 'phased_soca';    % legacy, uses phased.CFARDetector2D
cfgDOA.CFARMethod = 'separable_ca';   % fast CA-CFAR on range and Doppler axes
cfgDOA.L_bound = 1.5;                 % additive threshold for separable_ca
cfgDOA.L_bound_Range = 2.0;           % optional, OpenRadar style per-axis threshold
cfgDOA.L_bound_Doppler = 1.2;         % optional, OpenRadar style per-axis threshold
```

默认不设置 `CFARMethod` 时仍走 `phased_soca`，用于保持旧参考项目等价性。  
`separable_ca` 不调用 `phased.CFARDetector2D`，也不依赖 `imfilter`，适合短距 mmWave
点云场景的性能测试。使用前应通过 `validation/profile_pointcloud_cfar_diagnosis.m`
和目标数据集小样本确认点云数量与虚警水平。

## OpenRadar-Style Peak Options

参考 [OpenRadar](https://github.com/PreSenseRadar/OpenRadar) 的 `mmwave/dsp`
实现（`noise_removal.py::prune_to_peaks`、`angle_estimation.py::peak_search_full_variance`），
点云流程新增了可选的 peak pruning 和 DOA peak search。默认都不开启，保持旧参考项目等价性。

```matlab
cfgDOA.PeakFocusMode = 'legacy_4neighbor';  % default
cfgDOA.PeakFocusMode = 'py_doppler';        % Doppler wrap grouping on CFAR survivors
cfgDOA.ReservePeakNeighbor = false;         % optional, follows PY prune_to_peaks

cfgDOA.DOAPeakSearch = 'legacy_findpeaks';  % default
cfgDOA.DOAPeakSearch = 'py_full_variance';  % gamma + sidelobe threshold
cfgDOA.DOAGamma = 1.2;
cfgDOA.DOASidelobeLevel = 0.251188643150958;
```

这些选项的行为由 `tests/pointcloud/` 下的单元测试固定：

```matlab
runtests('tests/pointcloud')
```

在一组实测 TI cascade 单帧数据上，OpenRadar-style 配置能把点云数从 `10` 提到 `69`，
完整分支耗时约 `0.07 s`。因此这条分支可以作为高效诊断入口；正式接入某个数据集时
仍应单独调阈值。

## Doppler Bin Convention

`GeneratePointCloudFrame` 中速度轴使用：

```matlab
dopplerBin = dopplerIdx - ChirpNum / 2 - 1;
speedVal = dopplerBin * doppler_res;
```

因此 TDM-MIMO Doppler compensation 也使用同一个物理 bin：

```matlab
deltaPhi = 2 * pi * dopplerBin / (numTx * ChirpNum);
```

这和原始参考项目的 `dopplerIdx - ChirpNum / 2` 写法相差 1 个 bin。工具箱这里优先保持速度轴和补偿相位一致。

## Real Data Workflow

实测 DCA1000 数据从 `utils` 进入：

```matlab
[radar_data, adcCubeAll, readerInfo] = readDCA1000Raw(fileName, ADC_samples, numRx, numTx);
adcData = adcCubeAll(:, chirpStart:chirpEnd, :);

[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, IQFlag);
```

`pointcloud/demo_pointcloud_bin.m` 仍然使用这种流程。

## DOA Dependency

`azimuthDOA.m` 和 `elevationDOA.m` 是点云流程里的薄包装器，真正的 DOA 算法在 `doa/`：

```text
doa/DOA_FFT.m
doa/DOA_MUSIC.m
doa/DOA_IAA.m
doa/DOA_L1SVD.m
doa/DOA_ANM.m
```

这样后续如果要改 MUSIC、IAA、ESPRIT 或加入信源数估计，不需要改点云主流程。

## Useful Demos

```matlab
demo_pointcloud_sim
demo_pointcloud_ra_sim
demo_pointcloud_bin
```

点云后的 centroid / EKF 跟踪入口在 `tracking/`：

```matlab
validation/validate_tracking_pointcloud_integration.m
```
