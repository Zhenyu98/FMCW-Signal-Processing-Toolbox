# tracking

`tracking/` 只负责标准点云之后的目标跟踪流程，不读取 ADC，也不做 CFAR / DOA。

输入点云格式沿用 `pointcloud/`：

```matlab
% frame_data: X, Y, Z, Range, Azimuth, Elevation, Doppler, SNR
frame_data = [XData, YData, ZData, range, azimuth, elevation, doppler, snr];
```

## Pipeline

```text
TrackPointCloudSequence
    -> preprocessing/TransformPointCloudFrame(optional)
    -> clustering/GenerateCentroidMeasurement
    -> association/AssociateGNN
    -> filtering/EKFPredict / filtering/EKFUpdateSphere4
    -> management/UpdateTrackLifecycle
    -> visualization/VisualizeTrackingResult
```

## Folder Layout

```text
tracking/
    ConfigureTrackingParameter.m    % default tracking / EKF parameters
    TrackPointCloudSequence.m       % main top-level tracking flow
    preprocessing/                  % coordinate transform and frame cleanup
    clustering/                     % DBSCAN and centroid measurement
    association/                    % GNN gate, Hungarian, assignment solver
    filtering/                      % EKF, measurement model and coordinate conversion
    management/                     % track lifecycle / state machine
    visualization/                  % plotting and result display
```

这些子目录是普通 MATLAB path folder，不是 `+package`。函数调用方式保持不变：

```matlab
[trackResult, measurementSeq] = TrackPointCloudSequence(frameDataSeq, trackingParams, ekfParams);
```

## Main Entry

```matlab
[trackingParams, ekfParams] = ConfigureTrackingParameter(sensorParams, radarParams);
[trackResult, measurementSeq] = TrackPointCloudSequence(frameDataSeq, trackingParams, ekfParams);
```

`frameDataSeq` 是 cell：

```matlab
frameDataSeq{tIdex} = frame_data;
```

`trackResult.tracks` 和 `trackResult.finishedTracks` 中每条航迹包含：

```matlab
track.id
track.state                       % tentative / confirmed / deleted
track.x_cart                      % [X; Y; Z; Vx; Vy; Vz]
track.P_cart
track.totalVisibleCount
track.consecutiveInvisibleCount
track.detect2activeCount
track.detect2freeCount
track.active2freeCount
track.historyState
track.historyGateDistance
track.historyNIS
```

## Track Lifecycle

航迹生命周期采用接近 TI GTRACK 的状态机，同时保留工具箱里更直观的状态名：

```text
tentative  -> confirmed -> deleted
DETECTION  -> ACTIVE    -> FREE
```

核心入口：

```matlab
[tracks, finishedTracks, lifecycleInfo] = ...
    UpdateTrackLifecycle(tracks, finishedTracks, trackingParams.Track);
```

常用参数：

```matlab
trackingParams.Track.Detect2ActiveThreshold = 2;  % tentative hits before confirmed
trackingParams.Track.Detect2FreeThreshold = 2;    % tentative misses before deleted
trackingParams.Track.Active2FreeThreshold = [];   % empty: use MaxCoast
trackingParams.Track.MaxCoast = 5;                % confirmed misses before deleted
trackingParams.Track.MinAssociatedPoints = 1;     % point count needed as a valid hit
```

`UpdateTrackLifecycle` 同时保留 `updateTrackStates.m` 里的 visibility 思路：

```matlab
trackingParams.Track.UseVisibilityDelete = true;
trackingParams.Track.AgeThreshold = 5;
trackingParams.Track.MinTentativeVisibility = 0.34;
trackingParams.Track.MinConfirmedVisibility = 0.20;
```

也就是说，短暂虚警不会太快变成 confirmed，已经 confirmed 的航迹可以短时 coast，
但长期低可见率的航迹会被移入 `finishedTracks`。

## Clustering And Centroid

当前默认聚类方法是 DBSCAN：

```matlab
trackingParams.Cluster.Method = 'DBSCAN';
trackingParams.Cluster.Dimension = 'XY';
trackingParams.Cluster.DBSCAN_epsilon = 0.75;
trackingParams.Cluster.DBSCAN_MinPts = 2;
```

centroid 默认使用 SNR 线性权重：

```matlab
trackingParams.Centroid.WeightMode = 'SNR';
```

`GenerateCentroidMeasurement` 输出的 `centroidList` 保留 cluster 离散度：

```matlab
centroid.rangeVar
centroid.azimuthVar
centroid.elevationVar
centroid.dopplerVar
```

这些量会进入 `ekfParams.RMode = 'clusterVar'` 的 measurement noise。

## EKF State And Measurement

EKF 状态：

```matlab
x = [X; Y; Z; Vx; Vy; Vz];
```

量测：

```matlab
z = [range; azimuth; elevation; doppler];
```

其中 `doppler` 在 EKF 中按 radial velocity 使用：

```matlab
doppler = (position' * velocity) / range;
```

角度单位约定：

- `frame_data(:,5:6)` 使用 degree。
- `centroid.sphere_position(2:3)` 和 EKF 内部使用 radian。

## R Interface

工具箱核心不内化 Phase-CRB。`R` 只提供通用接口：

```matlab
ekfParams.RMode = 'fixed';       % use ekfParams.RFixed
ekfParams.RMode = 'clusterVar';  % use centroid variance
ekfParams.RMode = 'custom';      % use ekfParams.RBuilder
```

自定义方法可以这样接入：

```matlab
ekfParams.RMode = 'custom';
ekfParams.RBuilder = @(candidate, ekfParams) myBuildR(candidate, ekfParams);
```

后续 Phase-CRB、Point-SNR-R、JPDA 自适应噪声都应该从这个接口外挂，不写进 tracking core。

## Association And Gate

当前数据关联是 GNN-style gated nearest assignment：

```matlab
trackingParams.Association.Method = 'GNN';
trackingParams.Association.GateProbability = 0.99;
trackingParams.Association.GateThreshold = ChiSquareGate(0.99, 4);
trackingParams.Association.Solver = 'hungarian';
trackingParams.Association.CostOfNonAssignment = [];
```

cost 使用：

```matlab
cost = d2 + log(det(S));
```

其中：

```matlab
d2 = innovation' / S * innovation;
S = H * P * H' + R;
```

`Solver = 'global'` 会在小规模目标集上做全局最小 cost 分配；目标数量超过
`MaxExactAssignmentSize` 时退回 Hungarian，避免指数级搜索。

`Solver = 'hungarian'` 是默认分支，用自包含 Hungarian / Munkres 求解器，不调用
`assignDetectionsToTracks` 或其它 MATLAB toolbox 函数。它保证每个 track 最多分配
一个 detection，每个 detection 最多分给一个 track，避免多个 tracker 抢同一个点。

`CostOfNonAssignment = []` 时，solver 会优先保留 gate 内有限匹配，行为接近原来的
最大匹配数 exact solver。若设置为具体数值，则 cost 太差的匹配可以主动留空。
后续如果要加入 JPDA，优先替换 `AssociateGNN.m` 的关联策略，不要改 EKF 主体。

## Validation

轻量核心验证：

```matlab
validation/validate_tracking_core.m
validation/validate_tracking_lifecycle.m
validation/validate_tracking_assignment_solver.m
validation/validate_tracking_pointcloud_integration.m
```

这个验证直接构造标准 `frame_data` 序列，用于检查 centroid、GNN gate 和 EKF 航迹管理是否能稳定跑通。
