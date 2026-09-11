# 发布候选版验证记录

日期：2026-09-11。环境：Windows，MATLAB R2025b Update 1。

先执行 `restoredefaultpath`，切换到不含参考工程、实测数据和本机采集配置的独立候选目录，
再执行 `startup`。`which RadarCubeGenerate` 已确认解析到候选目录中的 `signal/`。

| 检查 | 实际结果 |
| --- | --- |
| `demo_generate_radar_cube` | 输出 `[256 64 4 3]`，元素全部有限 |
| `demo_pointcloud_sim` | 输出 `frame_data` 为 `[3 8]` |
| `runtests('tests', 'IncludeSubfolders', true)` | 32 通过，0 失败，0 未完成；`assertSuccess` 通过 |
| `validate_ra_pointcloud_pipeline` | 2 个检测点；距离误差 `[0.000459309, 0.0302358]` m，角度误差 `[0.0596969, 0.10551]` degree，均满足脚本判据 |
| `validate_tracking_core` | 2 条 confirmed 航迹 |
| `validate_tracking_lifecycle` | 航迹确认、删除、可见率判据通过 |
| `validate_tracking_assignment_solver` | 确定性反例及 50 轮随机对照通过 |
| `validate_tracking_pointcloud_integration` | 24 帧均保持 2 条 confirmed 航迹，最终 coast 为 0 |

复现命令（在项目根目录）：

```matlab
startup
results = runtests('tests', 'IncludeSubfolders', true);
assertSuccess(results)
validate_ra_pointcloud_pipeline;
run('validation/validate_tracking_core.m')
run('validation/validate_tracking_lifecycle.m')
run('validation/validate_tracking_assignment_solver.m')
run('validation/validate_tracking_pointcloud_integration.m')
```

上述基础检查不覆盖实测硬件采集、SAR/RMA/BP 与全部 DOA / 信源数分支。
性能界与可选 MathWorks 两径源的补充验证见本页扩展图集；其他参考工程对照仍需额外输入。
其他模块文档中的旧数值保留为历史记录，不计入本次结果。

通过上述测试代表这些场景的运行与数值判据通过。第三方来源与引用要求见
[来源与第三方声明](../THIRD_PARTY_NOTICES.md)。

## 扩展算法图集

`docs/generate_algorithm_gallery.m` 在 MATLAB R2025b 实际运行完成；未修改底层工具函数。

| 检查 | 结果 |
| --- | --- |
| 同一观测的 FFT / MUSIC / IAA 空间谱 | 均有限；MUSIC 和 IAA 三个主峰的最大角度误差均为 0 degree（0.25 degree 网格） |
| Newton 信源数估计 | 固定 15 dB 场景输出 3，与设置一致；未统计跨场景准确率 |
| 分帧 DTM | 40 列输出；最大速度误差 0.014673 m/s，小于两倍网格间距 0.059386 m/s |
| MathWorks 两径信号 | 三组期望距离峰均对齐 FFT bin，最大 bin 误差为 0 |
| 原始 ZZB 示例 | 1000 次随机角度采样；所有输出有限且为正；低 SNR ZZB/APB 为 0.992209，高 SNR ZZB/CRB 为 1.000000 |

上述扩展不改变此前单元测试结论，也不代表全部 SAR、DOA 分支及历史信源数脚本已经验证。可复现参数和绘图变换见 [图集来源说明](assets/README.md)。
