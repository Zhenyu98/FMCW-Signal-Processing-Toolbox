# 来源与第三方声明

根目录 [LICENSE](LICENSE) 是本项目自有代码的 MIT 许可。下表列出的第三方参考实现来自公开发布的开源项目或论文配套代码，本项目在其基础上做二次开发；这些文件继续受原作者条款约束，文件头中的作者、版权和引用说明均已保留，根目录 MIT 文本不覆盖它们。

| 范围 | 来源 | 保留的说明 / 使用要求 |
| --- | --- | --- |
| `pointcloud/` 底层 FFT、CFAR、峰值聚焦、Doppler 补偿、DOA 包装，`doa/DOA_*.m` | [DingdongD/TDMA-MIMO](https://github.com/DingdongD/TDMA-MIMO)（Xuliang Yu 等） | 使用相关代码请引用 X. Yu et al., "A Novel Potential Drowning Detection System Based on Millimeter-Wave Radar," *ICARCV 2022*, doi: 10.1109/ICARCV57592.2022.10004245 |
| `pointcloud/` 的 `separable_ca`、`py_doppler`、`py_full_variance` 分支 | [OpenRadar](https://github.com/PreSenseRadar/OpenRadar)（Apache-2.0） | 行为参考并用 MATLAB 重写，未复制源码 |
| `utils/readDCA1000Raw.m` | 由 TI DCA1000 参考读取脚本整理、泛化 | 保留原始格式约定说明 |
| `utils/DCA_Connet/` | TI mmWave Studio 官方 Lua 示例；MATLAB 封装由 Xuliang 编写 | 保留文件头署名；需按本机修改 TI 安装路径 |
| `imaging/` 的 RMA / BP / RTM | 本项目作者（Zhenyu Wu）早期代码 | 文件头保留版权与联系方式 |
| `tracking/` | 参考 TI GTRACK 生命周期思路和通用 EKF / GNN / 质心公式自行实现 | 只借鉴算法思想，未复制实现 |
| `performance/` | Zongyu Zhang 的 ZZB 论文配套代码 | 使用请引用 Z. Zhang, Z. Shi, Y. Gu, "Ziv-Zakai bound for DOAs estimation," *IEEE TSP*, vol. 71, 2023 |
| `source-number-estimation/` | Jerry Yang 的牛顿插值信源数估计脚本 | 保留文件头署名 |
| `signal/RadarCubeGenerateMathWorks*.m` | 调用已安装的 MathWorks Radar Toolbox 接口 | 不分发任何工具箱文件 |
| `doa/DOA_ANM.m`、`doa/DOA_L1SVD.m` | 依赖 [CVX](http://cvxr.com/cvx/)（ANM 使用 SDPT3） | 用户自行安装求解器，本仓库不附带 |

如果你是上述任一来源的作者并希望调整署名或使用方式，请通过 issue 联系维护者。

参考工程原件、厂商文档、实测原始数据不纳入仓库。
