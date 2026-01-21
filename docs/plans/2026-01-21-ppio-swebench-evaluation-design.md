# PPIO Claude Sonnet 4.5 SWE-bench 评测方案

## 概述

使用 PPIO API 的 `pa/claude-sonnet-4-5-20250929` 模型，通过 OpenHands 在 SWE-bench 上进行评测。

## 目标

1. 获取模型在 SWE-bench 上的 resolve rate
2. 详细分析失败原因和 token 消耗
3. 支持与其他模型对比
4. 验证 PPIO API 与 OpenHands 的集成可行性

## 环境配置

### config.toml

```toml
# 主要评测模型 - PPIO Claude Sonnet 4.5
[llm.ppio_claude_sonnet]
model = "pa/claude-sonnet-4-5-20250929"
base_url = "https://api.ppio.com/openai/v1"
api_key = "YOUR_API_KEY"
temperature = 0.0

# 可选：对比测试其他 PPIO 模型
[llm.ppio_gpt5]
model = "pa/gpt-5.2"
base_url = "https://api.ppio.com/openai/v1"
api_key = "YOUR_API_KEY"
temperature = 0.0

[llm.ppio_claude_opus]
model = "pa/claude-opus-4-5-20251101"
base_url = "https://api.ppio.com/openai/v1"
api_key = "YOUR_API_KEY"
temperature = 0.0
```

## 评测执行流程

### 三阶段渐进式评测

| 阶段 | 数据集 | 实例数 | 目的 | 并发数 |
|------|--------|--------|------|--------|
| 1 | SWE-bench_Lite | 10 | 验证配置、API 连通性 | 1 |
| 2 | SWE-bench_Lite | 300 | 中等规模测试 | 4 |
| 3 | SWE-bench_Verified | 500 | 正式评测 | 4 |

### 执行命令

```bash
# 阶段1：小规模验证 (10个实例)
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh llm.ppio_claude_sonnet HEAD CodeActAgent 10 100 1

# 阶段2：SWE-bench_Lite (300个实例)
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh llm.ppio_claude_sonnet HEAD CodeActAgent 300 100 4 princeton-nlp/SWE-bench_Lite test

# 阶段3：SWE-bench_Verified (500个实例)
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh llm.ppio_claude_sonnet HEAD CodeActAgent 500 100 4 princeton-nlp/SWE-bench_Verified test
```

### 评估生成的 Patch

```bash
./evaluation/benchmarks/swe_bench/scripts/eval_infer.sh \
  evaluation/evaluation_outputs/outputs/princeton-nlp__SWE-bench_Lite/CodeActAgent/pa_claude-sonnet-4-5-20250929_maxiter_100_N_v1.0/output.jsonl
```

### 输出产物

- `output.jsonl` - 每个实例的推理结果和生成的 patch
- `report.json` - 包含 `resolved_ids` 等统计数据
- `README.md` - 可读的评测报告
- `logs/` - 详细的测试日志

## 详细分析

### Token 消耗追踪

OpenHands 在 `output.jsonl` 中记录：
- 输入/输出 token 数
- API 调用次数
- 总迭代轮数

汇总脚本：

```bash
python -c "
import json
total_tokens = 0
with open('output.jsonl') as f:
    for line in f:
        data = json.loads(line)
        metrics = data.get('metrics', {})
        total_tokens += metrics.get('accumulated_cost', 0)
print(f'Total cost: {total_tokens}')
"
```

### 失败原因分类

- `resolved` - 成功修复
- `failed` - patch 未能通过测试
- `error` - 运行时错误（API 超时、格式问题等）

通过 `logs/` 目录逐个分析失败实例。

### 多模型对比

```bash
# 依次运行不同模型
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh llm.ppio_claude_sonnet HEAD CodeActAgent 300 100 4 princeton-nlp/SWE-bench_Lite test
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh llm.ppio_gpt5 HEAD CodeActAgent 300 100 4 princeton-nlp/SWE-bench_Lite test
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh llm.ppio_claude_opus HEAD CodeActAgent 300 100 4 princeton-nlp/SWE-bench_Lite test
```

## 实施步骤

1. **准备环境**
   - 确保云服务器安装 Docker，磁盘空间 >= 200GB
   - 克隆 OpenHands 仓库并安装依赖
   - 创建 `config.toml` 配置文件

2. **阶段1：验证 (10 实例)**
   - 运行小规模测试
   - 确认 PPIO API 连通、响应格式正确
   - 检查 `output.jsonl` 是否正常生成

3. **阶段2：中等规模 (300 实例)**
   - 运行 SWE-bench_Lite 完整评测
   - 执行 `eval_infer.sh` 获取通过率

4. **阶段3：正式评测 (500 实例)**
   - 运行 SWE-bench_Verified
   - 生成最终报告

5. **可选：多模型对比**
   - 对其他感兴趣的模型重复上述流程

## 注意事项

| 风险点 | 应对方案 |
|--------|----------|
| API 限流 | 降低 `num_workers` 或添加重试逻辑 |
| 单实例超时 | `max_iter=100` 已是合理上限 |
| 磁盘空间不足 | 定期清理 Docker 镜像 `docker system prune` |
| 评测中断 | OpenHands 支持断点续跑，已完成实例会跳过 |

---

## 评测结果

### Stage 1 验证结果 (2026-01-21)

#### 配置修正

原始设计中的模型名需要添加 `openai/` 前缀以兼容 LiteLLM：

```toml
# 正确配置
[llm.ppio_claude_sonnet]
model = "openai/pa/claude-sonnet-4-5-20250929"  # 添加 openai/ 前缀
base_url = "https://api.ppio.com/openai/v1"
api_key = "YOUR_API_KEY"
temperature = 0.0
```

#### 环境变量

运行命令需要设置代理和 NO_PROXY：

```bash
HTTPS_PROXY=http://172.17.0.1:1081 \
HTTP_PROXY=http://172.17.0.1:1081 \
NO_PROXY=localhost,127.0.0.1 \
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh llm.ppio_claude_sonnet HEAD CodeActAgent 10 100 1
```

#### 结果统计

| 指标 | 数值 |
|------|------|
| 测试实例数 | 10 |
| 补丁生成率 | 100% (10/10) |
| **测试通过率** | **30% (3/10)** |
| 运行时间 | ~3 小时 |

#### 通过的实例

| Instance ID | 修改文件 |
|-------------|----------|
| django__django-16379 | django/core/cache/backends/filebased.py |
| pytest-dev__pytest-6116 | src/_pytest/main.py |
| scikit-learn__scikit-learn-13779 | sklearn/ensemble/voting.py |

#### 未通过的实例

| Instance ID | 修改文件 |
|-------------|----------|
| astropy__astropy-7746 | astropy/wcs/wcs.py |
| django__django-11019 | django/forms/widgets.py |
| psf__requests-2317 | requests/models.py |
| scikit-learn__scikit-learn-25500 | sklearn/calibration.py |
| sympy__sympy-12171 | sympy/printing/mathematica.py |
| sympy__sympy-13146 | sympy/core/numbers.py |
| sympy__sympy-18189 | sympy/solvers/diophantine |

#### 输出文件

```
evaluation/evaluation_outputs/outputs/princeton-nlp__SWE-bench_Lite-test/CodeActAgent/claude-sonnet-4-5-20250929_maxiter_100_N_v1.2.1-no-hint-run_1/
├── output.jsonl              # 推理结果
├── output.swebench.jsonl     # SWE-bench 格式
├── report.json               # 评估报告
├── eval_outputs/             # 测试日志
└── llm_completions/          # LLM 调用日志
```

### 已解决的技术问题

1. **Docker 构建失败** - 配置 `~/.docker/config.json` 代理
2. **LiteLLM 提供商识别** - 使用 `openai/` 前缀
3. **Runtime 503 错误** - 添加 `NO_PROXY=localhost,127.0.0.1`

### 下一步

- [ ] Stage 2: 300 实例中等规模测试
- [ ] Stage 3: 500 实例 SWE-bench_Verified 完整评测
