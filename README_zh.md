<h1 align="center">FMCW Signal Processing Toolbox</h1>

<p align="center"><a href="README.md">English</a> · <strong>简体中文</strong></p>

<p align="center">
  <strong>一个 MATLAB 工具箱覆盖 FMCW 毫米波雷达整条链路：回波仿真、原始数据、频谱、点云、测角、跟踪、SAR 成像和性能评估。</strong>
</p>

<p align="center">
  <strong>整条链路全覆盖</strong> ·
  <strong>一套参数串起处理链路</strong> ·
  <strong>关键公式与中间结果可见</strong>
</p>

<p align="center">
  <a href="https://github.com/Zhenyu98/FMCW-Signal-Processing-Toolbox/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/Zhenyu98/FMCW-Signal-Processing-Toolbox?style=for-the-badge&logo=github"></a>
  <a href="LICENSE"><img alt="License MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge"></a>
  <a href="https://www.mathworks.com/products/matlab.html"><img alt="MATLAB R2025b" src="https://img.shields.io/badge/MATLAB-R2025b-0076A8?style=for-the-badge&logo=mathworks&logoColor=white"></a>
  <a href="#验证与测试"><img alt="Tests 32 passed" src="https://img.shields.io/badge/tests-32%20passed-brightgreen?style=for-the-badge"></a>
</p>

<p align="center">
  <a href="#快速开始">快速开始</a> ·
  <a href="#示例图集">示例图集</a> ·
  <a href="#模块总览">模块总览</a> ·
  <a href="#数据格式约定">数据格式</a> ·
  <a href="#依赖">依赖</a> ·
  <a href="#路线图">路线图</a> ·
  <a href="#faq">FAQ</a> ·
  <a href="#引用与致谢">引用与致谢</a>
</p>

<p align="center">
  <img src="docs/assets/hero_pipeline.png" alt="signal -> range-Doppler map -> point cloud" width="96%" />
  <br />
  <sub>仿真 3 个目标（TI xWR1843 风格 3Tx4Rx 阵列，SNR 20 dB）：range profile → range-Doppler map → TDM-MIMO 点云，全部由本工具箱生成。</sub>
</p>

## 一个工具箱，覆盖整条链路

多数雷达仓库只做其中一段；这里从回波仿真一直到航迹和图像，全部在同一条 MATLAB 链路里：

| 环节 | 包含的内容 |
| --- | --- |
| 回波仿真 | 点目标、带 chirp 级轨迹的多散射点人体、TI 虚拟阵列，可选 MathWorks 行人与多径场景 |
| 原始数据 | DCA1000 `.bin` 读取、mmWave Studio 采集脚本 |
| 频谱与图 | Range-Doppler、Range-Angle、Range-Time、Doppler-Time、micro-Doppler |
| 点云 | 2D CFAR、峰值分组、TDM Doppler 补偿、RD 与 RA 两条管线 |
| 测角 | FFT、MUSIC、ESPRIT、IAA、L1-SVD、ANM，以及信源数估计 |
| 跟踪 | DBSCAN 质心、GNN 门限与 Hungarian 分配、球坐标 EKF、航迹生命周期 |
| SAR 成像 | 2D RMA 与 Back-Projection |
| 性能评估 | DOA 估计误差的 CRB 与 Ziv-Zakai 下界 |

仿真、频谱、点云和跟踪之间交换的都是同一个 radar cube 和同一种八列点云，仿真数据和实测数据走的是同一份代码。

## 把时间用在算法上

一个距离估计算法跑通之后，往往还要重新拼接信号生成、检测、测角和跟踪，才能回答真正关心的问题：换个阵列、加入运动目标或接入实测数据，结果还成立吗？

毫米波雷达实验中，耗时的部分常常藏在这些接口里：采样与通道维度不一致、参数单位不同、坐标轴和多发射天线时序没有对齐。单个模块各自有结果，串起来却未必对应同一个物理场景。

**FMCW Signal Processing Toolbox 将这些常用环节组织成可检查、可复用的 MATLAB 实验链路。** 它面向调频连续波（FMCW）雷达研究，覆盖回波仿真、原始数据读取、距离与速度谱、三维点云、测角、目标跟踪、SAR 成像和性能评估，适合信号处理方法验证、感知算法原型和科研教学。

- **更快搭起完整实验。** 用 `sensorParams` 和 `targetParams` 描述雷达与目标，把回波、检测、点云和航迹接到同一套处理流程中。
- **更容易定位误差。** 保留阵列、时序、单位与坐标约定；核心公式和中间变量可直接查看，方便区分信号模型、参数配置和算法本身的问题。
- **更方便复现实验。** 用共享观测和现有数值检查比较不同方法，减少重复编写信号源、数据转换和验证脚本的工作。

```text
sensorParams / targetParams          DCA1000 adc_data.bin
        |                                     |
        v                                     v
signal/RadarCubeGenerate            utils/readDCA1000Raw
        |                                     |
        +----------------> radar cube <-------+
                              |
        +---------------------+---------------------+
        v                     v                     v
imaging/RDM, RAM, DTM     pointcloud/            imaging/RMA, BP
range-Doppler / angle     GeneratePointCloudFrame   SAR 成像
micro-Doppler                 |
                              v
                     frame_data (8 列点云)
                              |
                              v
                 tracking/TrackPointCloudSequence
                 DBSCAN -> centroid -> GNN -> EKF -> 航迹管理
```

| 之前 | 现在 |
|---|---|
| 每个实验各自写一份信号生成和加噪声 | `RadarParameterGenerate` + `RadarCubeGenerate` 统一生成，`sensorParams.SNR_dB` 一处控制噪声 |
| 仿真点云和实测点云走两套代码 | 仿真 cube 和 `.bin` 读出的 cube 用同一个 `GeneratePointCloudFrame` |
| 阵列布局靠手写相位 | `sensorParams.ArrayType = 'TI_xWRx843'` 或直接画 virtual antenna map |
| 改一个函数不知道会不会影响别的实验 | `tests/` 单元测试 + `validation/` 参考代码等价性脚本 |

## 快速开始

已测试环境为 MATLAB R2025b，配合 Signal Processing Toolbox 和 Phased Array System Toolbox（详见[依赖](#依赖)）。基础仿真无需雷达硬件或实测数据。

```bash
git clone https://github.com/Zhenyu98/FMCW-Signal-Processing-Toolbox.git
cd FMCW-Signal-Processing-Toolbox
```

在 MATLAB 中把当前目录切到仓库根目录，然后：

```matlab
startup                          % 把各模块加入搜索路径
demo_pointcloud_sim              % 仿真 3 个目标并生成点云
```

预期结果：命令行输出 `FMCW Signal Processing Toolbox path is ready.`，弹出 range-Doppler map 和三维点云两张图，点云位于红色真值目标附近，距离、角度与速度存在离散网格误差。

再跑一遍单元测试确认环境正常：

```matlab
results = runtests('tests', 'IncludeSubfolders', true);
assertSuccess(results)
```

预期结果：`Totals: 32 Passed, 0 Failed, 0 Incomplete`。

示例脚本会执行 `clear` 和 `close all`，请先保存工作区与图窗。通过 [agent-setup.md](agent-setup.md) 可让编码智能体辅助检查环境。

### 最小示例：从参数到点云

下面是 `demo_pointcloud_sim.m` 的核心部分，也是整个工具箱最常用的调用方式：

```matlab
%% define parameters
sensorParams.Start_Freq_GHz = 76.5;
sensorParams.Slope_MHzperus = 46.397;
sensorParams.Sampling_Rate_ksps = 6874;
sensorParams.Samples_per_Chirp = 256;
sensorParams.Frame = 64;                    % TDM cycles in one frame
sensorParams.TxNum = 3;
sensorParams.RxNum = 4;
sensorParams.ArrayType = 'TI_xWRx843';      % xWR1843 / xWR6843 ISK style virtual array
sensorParams.SNR_dB = 20;                   % remove this field for clean data

targetParams.amplitude = [20, 20, 10];
targetParams.range = [5, 10, 15];           % m
targetParams.velocity = [0.4, -0.3, 0.1];   % m/s
targetParams.azimuth = [15, -20, 25];       % deg
targetParams.elevation = [0, 8, -5];        % deg

%% generate radar signal
radarParams = RadarParameterGenerate(sensorParams, targetParams);
[data, noiseInfo] = RadarCubeGenerate(targetParams, radarParams);   % SampleNum x ChirpNum x RxNum x TxNum
adcData = RadarCubeToPointCloudInput(data);                         % SampleNum x ChirpNum x ArrayNum

%% point cloud
cfgOut = ConfigurePointCloudParameter(sensorParams, radarParams);
cfgDOA.FFTNum = 180;
cfgDOA.AziMethod = 'FFT';
cfgDOA.EleMethod = 'FFT';
cfgDOA.thetaGrids = linspace(-90, 90, cfgDOA.FFTNum);
cfgDOA.AzisigNum = 1;
cfgDOA.ElesigNum = 1;
cfgDOA.Pfa = 1e-3;
cfgDOA.TestCells = [8, 8];
cfgDOA.GuardCells = [2, 2];

[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, 1);
% frame_data: X, Y, Z, Range, Azimuth, Elevation, Doppler, SNR   (N x 8; N depends on detections)

%% imaging on the same cube
[dopplerFFTOut, range_axis, velocity_axis] = RDM(data, sensorParams, true);
```

多帧点云接跟踪：

```matlab
frameDataSeq{tIdex} = frame_data;           % one cell per frame
[trackingParams, ekfParams] = ConfigureTrackingParameter(sensorParams, radarParams);
[trackResult, measurementSeq] = TrackPointCloudSequence(frameDataSeq, trackingParams, ekfParams);
```

实测 DCA1000 数据：

```matlab
[radar_data, adcCube, readerInfo] = readDCA1000Raw('adc_data.bin', numADCSamples, numRX, numTX);
adcData = adcCube(:, chirpStart:chirpEnd, :);
[frame_data, pointcloudInfo] = GeneratePointCloudFrame(adcData, cfgOut, cfgDOA, 1);
```

## 示例图集

从频谱中的目标，到随时间变化的运动特征，再到连续航迹：同一套工具箱可以支撑不同层次的雷达实验。以下均为工具箱示例生成的仿真结果。

### 从距离–方位角谱得到目标位置

两目标、1Tx8Rx 阵列、35 dB SNR。左侧保留频谱的真实距离与角度坐标，右侧对照检测点与目标真值，便于检查检测和坐标转换是否一致。

![距离–方位角频谱与检测点](docs/assets/gallery_range_azimuth.png)

运行入口：[`demo_pointcloud_ra_sim`](pointcloud/demo_pointcloud_ra_sim.m)。

### 让运动细节出现在微多普勒谱中

14 个动态散射点描述简化人体运动；身体平移与肢体摆动形成不同的速度分量。三个独立的三维姿态以半透明人体轮廓衬托散射点，再与下方频谱对照，直观看到运动如何进入雷达回波。

![人体散射点运动与微多普勒谱](docs/assets/gallery_human_motion.png)

运行入口：[`demo_human_motion_radar_echo`](signal/demo_human_motion_radar_echo.m)。该示例使用简化运动模型，未使用真实人体采集数据。

### 从逐帧检测连接成连续航迹

两目标、24 帧回波仿真，经过点云生成、数据关联与 EKF。两个面板分别放大每个目标附近的检测点、估计航迹与真实轨迹，直接观察整条处理链路的输出。

![双目标检测与 EKF 航迹](docs/assets/gallery_tracking.png)

运行入口：[`validate_tracking_pointcloud_integration`](validation/validate_tracking_pointcloud_integration.m)。

### 同一份观测下，测角方法如何呈现目标

12 阵元、128 快拍、15 dB SNR。FFT、MUSIC 和 IAA 共用同一份含噪观测，各自归一化显示空间谱；右侧展示协方差特征值与 Newton 信源数估计。MUSIC 使用估计得到的信源数，真值只用于峰位检查。

![FFT、MUSIC、IAA 空间谱与信源数估计](docs/assets/gallery_doa_source_count.png)

对应工具：[`DOA_FFT`](doa/DOA_FFT.m)、[`DOA_MUSIC`](doa/DOA_MUSIC.m)、[`DOA_IAA`](doa/DOA_IAA.m)、[`Newton_NOS`](source-number-estimation/Newton_NOS.m)。这是固定场景的接口与行为演示，不代表不同方法的统计性能排名。

### 同时观察目标距离和速度如何变化

同一目标在 40 帧中变速运动。左侧显示逐帧回波的距离谱，右侧由 `DTM` 生成速度–时间图；白色虚线为设置的运动轨迹。每帧保留独立的慢时间采样，帧间时间按 80 ms 组织。

![距离随时间变化与 DTM 速度时间图](docs/assets/gallery_doppler_time.png)

对应工具：[`RadarCubeGenerate`](signal/RadarCubeGenerate.m)、[`DTM`](imaging/DTM.m)。帧内采用常速度近似；左图直接使用距离 FFT，不调用面向旧硬件格式的 `RTM`。

### 一个目标，为什么会出现多个距离峰

直达与地面反射路径组合，会让同一个目标产生不同的表观距离。左侧展示传播几何，右侧用 MathWorks 两径回波对照理论峰位，帮助理解多径对距离检测的影响。

![两径传播几何及多个表观距离峰](docs/assets/gallery_two_ray.png)

对应工具：[`RadarCubeGenerateMathWorksTwoRay`](signal/RadarCubeGenerateMathWorksTwoRay.m)。运行入口：[`validate_mathworks_two_ray_signal_source`](validation/validate_mathworks_two_ray_signal_source.m)。该几何刻意选为路径可分辨的示例，需 Radar Toolbox。

### 看清信噪比对测角误差界的影响

在低信噪比区域，先验范围会显著影响误差界；信噪比升高后，不同界逐步接近。图中给出先验界（APB）、Cramér–Rao 界（CRB）和 Ziv–Zakai 界（ZZB），用于建立性能量级的参考。

![DOA 测角的 APB、CRB 与 ZZB](docs/assets/gallery_doa_bounds.png)

对应工具：[`ZZB_DOAs`](performance/ZZB_DOAs.m)。按 [`Main_ZZB_Demo`](performance/Main_ZZB_Demo.m) 的原始参数运行：20 阵元、5 个非相干信源、40 快拍和 1,000 次随机角度采样。曲线为理论误差界，不是某个估计器的实测 RMSE；原论文引用见下方致谢。

复现图集：前三组运行 `run('docs/generate_readme_gallery.m')`，测角、速度时间图、两径与性能评估运行 `run('docs/generate_algorithm_gallery.m')`。图片写入 `docs/assets/`；运行前请保存工作区与图窗。后一脚本的两径部分需 Radar Toolbox，性能评估部分另需 Statistics and Machine Learning Toolbox 与 Communications Toolbox。

## 模块总览

| 模块 | 作用 | 主要入口 | Demo |
|---|---|---|---|
| [`signal/`](signal/README.md) | FMCW 雷达信号 / radar cube 仿真，支持点目标、笛卡尔散射点、chirp 级动态轨迹、TI 虚拟阵列、可选 MathWorks 官方场景源 | `RadarParameterGenerate`, `RadarCubeGenerate`, `AddNoiseBySNR`, `RadarCubeGenerateMathWorks*` | `demo_generate_radar_cube`, `demo_human_motion_radar_echo`, `demo_mathworks_signal_source_switch` |
| [`pointcloud/`](pointcloud/README.md) | TDM-MIMO 点云：range/Doppler FFT → 非相干积累 → 2D CFAR → 峰值聚焦 → Doppler 补偿 → 方位/俯仰 DOA | `GeneratePointCloudFrame`, `GeneratePointCloudFrameRA`, `ConfigurePointCloudParameter`, `CFAR_2D` | `demo_pointcloud_sim`, `demo_pointcloud_ra_sim`, `demo_pointcloud_bin` |
| [`tracking/`](tracking/README.md) | 点云目标跟踪：DBSCAN 聚类、SNR 加权 centroid、GNN 门限关联 + Hungarian、4D 球坐标 EKF、TI GTRACK 风格航迹生命周期 | `ConfigureTrackingParameter`, `TrackPointCloudSequence` | `validation/validate_tracking_pointcloud_integration` |
| [`imaging/`](imaging/README.md) | Range-Doppler / Range-Angle / Range-Time / Doppler-Time map、micro-Doppler 谱、2D RMA 与 BP SAR 成像 | `RDM`, `RAM`, `RTM`, `DTM`, `MDS`, `SarRMAimaging_2D`, `RAM_BPimaging`, `BPimaging` | `demo_range_doppler_map`, `demo_range_angle_map`, `demo_rma_imaging_2d`, `demo_bp_imaging_2d` |
| `doa/` | 可复用 DOA 算法 | `DOA_FFT`, `DOA_MUSIC`, `DOA_IAA`, `DOA_L1SVD`, `DOA_ANM`, `MUSIC_alg`, `ESPRIT_alg` | 由 `pointcloud/azimuthDOA`, `elevationDOA` 调用 |
| `source-number-estimation/` | 信源数 / 模型阶数估计（特征子空间投影、牛顿插值） | `ES_NOS`, `Newton_NOS` | `DNI_compare_with_others` 等对比脚本 |
| `performance/` | 多信源 DOA 的 Ziv-Zakai 界 / CRB / APB | `ZZB_DOAs` | `Main_ZZB_Demo` |
| [`utils/`](utils/README.md) | 硬件相关：DCA1000 raw bin 读取、mmWave Studio 连接与 Lua 采集脚本 | `readDCA1000Raw`, `DCA_Connet/` | — |
| [`validation/`](validation/README.md) | 与参考代码 / MathWorks 官方模型的等价性验证脚本 | `validate_*.m` | — |
| `tests/` | `runtests` 单元测试（CFAR、peakFocus、DOA 多峰、角度轴） | — | — |

每个模块目录下的 `README.md` 有更完整的参数说明和约定。

## 数据格式约定

**Radar cube**（`signal/` 输出，`imaging/` 输入）：

```matlab
% data: SampleNum x ChirpNum x RxNum x TxNum
data(tIdex, pIdex, rxIdex, txIdex)
```

**点云输入**（`pointcloud/` 输入，`RadarCubeToPointCloudInput` 或 `readDCA1000Raw` 输出）：

```matlab
% adcData: SampleNum x ChirpNum x ArrayNum    (ArrayNum = RxNum * TxNum)
```

**点云输出**（`pointcloud/` 输出，`tracking/` 输入），固定八列：

```matlab
% frame_data: X, Y, Z, Range, Azimuth, Elevation, Doppler, SNR
frame_data = [XData, YData, ZData, range, azimuth, elevation, doppler, snr];
```

坐标约定：`x` 水平（方位向），`y` 雷达视线（距离向），`z` 竖直（俯仰向）；`frame_data` 中角度单位为 degree。

**雷达参数**：`sensorParams` 用硬件配置单位（GHz、MHz/us、ksps），`RadarParameterGenerate` 显式推导出 SI 单位的物理量：

```matlab
radarParams.f_0, K, Fs, Ts, Ta, Tc, TF, B, fc, lambda
radarParams.range_res, doppler_res, angle_res
radarParams.range_axis, doppler_axis
radarParams.VirtualArrayMap, VirtualPos_m
```

TI 常用虚拟阵列可以直接指定，也可以手画：

```matlab
sensorParams.ArrayType = 'TI_xWRx843';       % xWR1843 / xWR6843 ISK
sensorParams.ArrayType = 'TI_xWRx843_ODS';   % xWR6843 ODS / AOP
sensorParams.ArrayType = 'TI_xWRx642';       % xWR1642

sensorParams.VirtualArrayMap = [             % or draw the virtual channel index map by hand
    NaN NaN 8   9   10  11 NaN NaN
    0   1   2   3   4   5   6   7
];
```

## 从回波到航迹

### signal：信号仿真

- 两类目标输入：`range / velocity / azimuth / elevation` 点目标，或 `position_m = ScatterNum x 3 (x PulseNum)` 笛卡尔散射点，后者可直接接人体骨架、手势、STL 点云等动态复杂目标（见 `demo_human_motion_radar_echo`）。
- TDM 发射时序进入信号模型：运动目标在不同 Tx 时刻的距离不同，TDM 运动相位自然出现，补偿放在点云阶段。
- 可选 MathWorks 官方 waveform-level 信号源（`radarTransceiver`、`backscatterPedestrian`、`widebandTwoRayChannel`），输出同样的 radar cube，后续处理不变。这些模型用于算法与场景实验；板级误差和真实硬件校准需根据具体系统补充。
- `sensorParams.SNR_dB` 统一加复高斯白噪声，`noiseInfo` 记录实际噪声功率，方便蒙特卡洛实验保证各方法用同一份观测。

### pointcloud：TDM-MIMO 点云

- 默认 RD 管线：`rdFFT -> incoherent_accumulation -> CFAR_2D -> peakFocus -> compensate_doppler -> azimuthDOA / elevationDOA`。
- RA 管线通过 `cfgDOA.PointCloudPipeline = 'RA'` 开启，先做 range-azimuth map 再检测。
- `CFAR_2D` 两种模式：`phased_soca`（默认，调用 `phased.CFARDetector2D`）和 `separable_ca`（可分离 CA-CFAR；完整链路仍使用 `physconst`）。
- 可选的 OpenRadar 风格峰值分组和多峰 DOA 搜索（`PeakFocusMode = 'py_doppler'`、`DOAPeakSearch = 'py_full_variance'`），默认关闭。

### tracking：点云跟踪

- 只消费八列 `frame_data`，不读 ADC，不做 CFAR / DOA。
- EKF 状态 `[X; Y; Z; Vx; Vy; Vz]`，量测 `[range; azimuth; elevation; doppler]`。
- 量测噪声 `R` 提供 `fixed` / `clusterVar` / `custom` 三种模式，自定义方法通过 `ekfParams.RBuilder` 外挂，不用改核心代码。
- 数据关联为 GNN + 自带 Hungarian 求解器，不依赖 `assignDetectionsToTracks`；航迹状态 `tentative -> confirmed -> deleted` 对应 TI GTRACK 的 `DETECTION -> ACTIVE -> FREE`。

### imaging：成像与时频图

- `RDM` / `RAM` 直接吃 radar cube 和 `sensorParams`，返回真实物理坐标轴（m、m/s、deg）。
- `DTM` 针对分帧采集逐帧给 Doppler 快照；`MDS` 针对连续采集做慢时间 STFT。
- `SarRMAimaging_2D`、`RAM_BPimaging`、`BPimaging` 用于 GB-SAR / 合成孔径成像，demo 会弹出文件选择框读取原始回波。

### utils：硬件与采集

- `readDCA1000Raw(fileName, numADCSamples, numRX, numTX)` 是唯一正式的 DCA1000 raw bin 读取入口，返回 `numADCSamples x loopChirpNum x (numRX*numTX)` 的 cube。
- `utils/DCA_Connet/` 保存通过 mmWave Studio 的 RSTD 接口自动触发 DCA1000 采集的 MATLAB / Lua 脚本，基于 TI 官方 Lua 示例。脚本里的 `C:\ti\mmwave_studio_02_01_01_00` 是 TI 默认安装路径，按本机情况修改。

## 依赖

| 需要 | 用在哪里 | 没有它怎么办 |
|---|---|---|
| MATLAB R2025b | 全部（demo 用到 `subtitle`；源码为 UTF-8 编码，含中文注释） | 其他 MATLAB 版本需验证兼容性 |
| Signal Processing Toolbox | `findpeaks`、`hanning` 等，点云和成像模块 | 必需 |
| Phased Array System Toolbox | `physconst`、`phased.CFARDetector2D`（默认 CFAR） | 切换 CFAR 不会消除完整链路对 `physconst` 的依赖 |
| Radar Toolbox | `RadarCubeGenerateMathWorks*` 官方场景信号源 | 不用这些入口即可，本地 `RadarCubeGenerate` 不依赖 |
| [CVX](http://cvxr.com/cvx/) | `DOA_L1SVD`、`DOA_ANM` 稀疏 DOA | 其余 DOA 方法不依赖 |
| Communications Toolbox | `performance/ZZB_DOAs.m` 中的 `qfunc` | 性能评估示例需要 |
| Statistics and Machine Learning Toolbox | `performance/ZZB_DOAs.m` 中的 `unifrnd` | 不运行该研究示例即可 |
| TI mmWave Studio + DCA1000 | `utils/DCA_Connet/` 采集脚本；录制供 `readDCA1000Raw` 读取的 `adc_data.bin` | 只做仿真时不需要 |

DBSCAN、Hungarian 分配、EKF 等都是工具箱自带实现，不依赖 Statistics and Machine Learning Toolbox 或 Sensor Fusion and Tracking Toolbox。

## 验证与测试

**32 项单元测试覆盖 CFAR 检测、峰值筛选、角度轴与多峰测角行为。** 点云和跟踪验证进一步检查目标位置、全局数据关联与航迹连续性，帮助在改参数或替换模块后发现行为变化。具体场景与数值结果见 [验证记录](docs/verification.md)。

单元测试固定关键函数的行为契约：

```matlab
results = runtests('tests', 'IncludeSubfolders', true);
assertSuccess(results)      % 32 tests
```

`validation/` 下的脚本用同一份输入分别运行参考代码和工具箱代码，比较 raw NMSE、complex-gain aligned NMSE、峰值位置、点云列格式和坐标轴，例如：

```matlab
run('validation/validate_tracking_core.m')
run('validation/validate_tracking_pointcloud_integration.m')
validate_ra_pointcloud_pipeline;
run('validation/validate_mathworks_ideal_point_target_source.m')
results = validate_pointcloud_equivalence(3);      % needs the original reference project locally
```

依赖本地参考工程或原始数据的脚本，需要先配置输入；缺失依赖时可能跳过或报错。跳过不能计为验证通过。

RMA/BP、信源数估计和性能评估脚本作为研究示例提供，验证范围见对应说明。实测成像与参考代码对照需要匹配的数据、采集几何和依赖。数值结果对应文档列出的场景，应用到新系统时应重新验证。

## 目录结构

```text
FMCW-Signal-Processing-Toolbox/
├── README.md                   English
├── README_zh.md                简体中文
├── startup.m                   把各模块加入 MATLAB 搜索路径
├── signal/                     FMCW 信号 / radar cube 仿真
├── pointcloud/                 TDM-MIMO 点云生成
├── tracking/                   点云跟踪（preprocessing / clustering / association / filtering / management / visualization）
├── imaging/                    RDM, RAM, RTM, DTM, MDS, RMA, BP
├── doa/                        DOA 算法
├── source-number-estimation/   信源数估计
├── performance/                Ziv-Zakai 界
├── utils/                      DCA1000 读取、mmWave Studio 采集脚本
├── validation/                 等价性验证脚本
├── tests/                      runtests 单元测试
└── docs/assets/                README 图片
```

## 路线图

工具箱现在的仿真源是理想点散射体，也可以切换到 MathWorks 的波形级场景模型。接下来的方向是让它更贴近真实雷达和真实场景：

- **更可信的物理孪生。** 加入距离衰减、RCS 和更丰富的场景（骑行者、地面杂波、干扰），再用实测 DCA1000 数据做标定，逐步走向板级 digital twin。
- **更多雷达型号。** 在 xWR1843 / xWR6843 / xWR1642 之外增加阵列预设，首先是 TI cascade（AWR2243，12Tx16Rx）和它冗余虚拟通道的相干利用；原始数据读取支持更多 LVDS 排布。
- **多目标跟踪算法适配。** 在 GNN 之外接入 JPDA 等数据关联方法，通过 `RBuilder` 接口做自适应量测噪声，并在实测多帧序列上验证。
- **更聪明的点云。** 用信源数估计自动确定 DOA 峰数；稀疏 DOA 方法去掉对 CVX 的依赖。
- **更容易上手。** 提供实测 demo 用的小样例数据、MATLAB toolbox 打包和英文版模块文档。

欢迎在 issue 里提需求和应用场景。

## FAQ

**没有 Phased Array System Toolbox，点云还能跑吗？**
当前完整链路仍调用 `physconst`。`separable_ca` 只替换 CFAR 检测器；建议按依赖表配置环境，不将这个开关视为完整的无工具箱方案。

**仿真点云一个点都没有，或者点太多？**
干净仿真信号没有噪声地板，CFAR 容易把旁瓣当目标。先设置 `sensorParams.SNR_dB`（例如 20），再调 `cfgDOA.Pfa`、`TestCells`、`GuardCells`；纯净信号可以用 `cfgDOA.MinPeakSNR_dB`、`MaxDetections` 做后处理。

**实测数据的 chirp 数、Tx 顺序和仿真不一样怎么办？**
`readDCA1000Raw` 只负责把 bin 变成 cube，chirp 切片和 Tx 顺序由你在 `adcCube(:, chirpStart:chirpEnd, :)` 和 `sensorParams.VirtualArrayMap` 里指定；`demo_pointcloud_bin.m` 给了一个可改的模板。

**为什么 TDM Doppler 补偿和一些参考代码差 1 个 bin？**
工具箱统一用 `dopplerBin = dopplerIdx - ChirpNum/2 - 1`，让速度轴和补偿相位对应同一个物理 bin。等价性验证里 range/Doppler 前端指标与参考代码一致，角度和 XYZ 会有预期内的微小差别，见 `validation/README.md`。

**想复现旧版一维 ULA 模型？**
不设置 `ArrayType` / `VirtualArrayMap`，并给 `sensorParams.Center_Freq_Hz = 79e9`、`sensorParams.Antenna_Spacing_m = 1e-3`，`signal/README.md` 记录了逐点一致的验证结果。

**代码风格为什么不封装成类？**
这是研究工具箱，目标是让实验脚本从上到下能读懂、能打断点、能和论文公式对照。核心算法保持显式矩阵和循环，只有明显重复的部分才抽成函数。

## 引用与致谢

如果本工具箱对你的研究有帮助，欢迎引用：

```bibtex
@software{wu2026fmcwtoolbox,
  author  = {Zhenyu Wu},
  title   = {FMCW Signal Processing Toolbox},
  year    = {2026},
  url     = {https://github.com/Zhenyu98/FMCW-Signal-Processing-Toolbox}
}
```

本工具箱在整理时吸收并致谢了以下工作，相关文件头保留了原作者信息：

- [TDMA-MIMO](https://github.com/DingdongD/TDMA-MIMO)（Xuliang Yu 等）：点云模块的 range/Doppler FFT、CFAR、峰值聚焦、Doppler 补偿和 DOA 包装的原始参考实现。使用相关代码请同时引用：X. Yu, Z. Cao, Z. Wu, C. Song, J. Zhu and Z. Xu, "A Novel Potential Drowning Detection System Based on Millimeter-Wave Radar," *ICARCV 2022*, doi: 10.1109/ICARCV57592.2022.10004245.
- [OpenRadar](https://github.com/PreSenseRadar/OpenRadar)：`separable_ca` CFAR、`py_doppler` 峰值分组和 `py_full_variance` DOA 峰值搜索的参考行为。
- [TI mmWave GTRACK](https://www.ti.com/tool/MMWAVE-SDK)：航迹生命周期状态机的设计思路。
- Z. Zhang, Z. Shi, and Y. Gu, "Ziv-Zakai bound for DOAs estimation," *IEEE Trans. Signal Process.*, vol. 71, pp. 136–149, 2023：`performance/` 中的 ZZB 参考实现（作者 Zongyu Zhang）。
- `source-number-estimation/` 中的牛顿插值信源数估计脚本由 Jerry Yang 编写。
- `utils/DCA_Connet/` 中的 mmWave Studio 自动采集脚本基于 TI 官方 Lua 示例，MATLAB 封装由 Xuliang 编写。
- MathWorks Radar Toolbox 的 `radarTransceiver`、`backscatterPedestrian`、`widebandTwoRayChannel` 提供了可选的官方场景信号源。

## 贡献

欢迎提 issue 和 pull request。报告问题时请尽量附上 `sensorParams` / `cfgDOA` 配置和最小复现脚本；涉及实测数据时不要上传原始 `.bin`，说明采集参数即可。

## 许可

项目许可见 [MIT License](LICENSE)。第三方参考实现的版权与适用条款见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)，使用相关代码时请保留原作者声明及引用。

## Star History

<a href="https://star-history.com/#Zhenyu98/FMCW-Signal-Processing-Toolbox&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Zhenyu98/FMCW-Signal-Processing-Toolbox&amp;type=Date&amp;theme=dark&amp;legend=top-left&amp;v=1" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Zhenyu98/FMCW-Signal-Processing-Toolbox&amp;type=Date&amp;legend=top-left&amp;v=1" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=Zhenyu98/FMCW-Signal-Processing-Toolbox&amp;type=Date&amp;legend=top-left&amp;v=1" />
  </picture>
</a>
