# 用编码智能体配置工具箱

将下面的指令发送给 Codex、Claude Code 或其他编码智能体：

```text
请阅读当前仓库 README.md 和 agent-setup.md，检查 MATLAB 环境并运行基础回波示例及现有 tests。
目标：生成 [256 64 4 3] 回波数据，报告实际测试结果。
先检查文件和依赖，只运行本次授权的仿真与测试；缺少工具箱时报告，不自动安装或购买。
修改文件前说明计划，超出既有授权时先确认。保留未提交改动，不读取凭据、不上传数据、不推送或发布。
不要运行硬件采集脚本，不要递归添加参考工程路径。
```

## 前提

- 本地项目与可用的 MATLAB；本次验证环境为 Windows、R2025b。
- Phased Array System Toolbox、Signal Processing Toolbox；可选官方场景另需 Radar Toolbox。
- 基础仿真无需密钥或真实采集数据。
- 本地若有 `AGENTS.md`，先遵守其中的项目约定。

## 最小步骤

在 MATLAB 中将当前目录设为项目根目录：

```matlab
startup
which RadarCubeGenerate -all
demo_generate_radar_cube
assert(isequal(size(data), [256 64 4 3]))
assert(all(isfinite(data(:))))
results = runtests('tests', 'IncludeSubfolders', true);
assertSuccess(results)
```

`RadarCubeGenerate` 应来自 `signal/`。示例输出 `Data generation completed!` 与
`data size: [256 64 4 3]`，并显示距离谱图。测试通过时 `assertSuccess` 无报错。
报告 MATLAB 版本、实际命令、通过/失败/未完成数量，不能把跳过测试记为通过。

## 运行边界

示例会清空工作区并关闭图窗，先保存已有工作；自动验证宜用独立 MATLAB 会话。
只通过 `startup` 添加模块路径，避免将旧工程递归加入路径。缺少函数时先检查 `which`、`ver` 和许可证。
缺少参考数据时标记未验证，不替换测试判据。硬件控制、凭据使用、发布、推送与删除需相应明确授权。
