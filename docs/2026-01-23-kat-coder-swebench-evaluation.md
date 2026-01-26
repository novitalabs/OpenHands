# kat-coder SWE-bench Verified 评估报告

## 概述

本报告记录 kat-coder 模型在 SWE-bench Verified 评估中的完整实验结果。

**评估配置:**
- 模型: `kat-coder` (通过 PPIO API)
- 数据集: `princeton-nlp/SWE-bench_Verified`
- 实例数量: 500
- 最大迭代: 100
- Workers: 8 (推理) / 4 (测试验证)
- Agent: CodeActAgent

**评估状态:** ✅ 已完成

---

## 第一部分：最终结果

### 1.1 核心指标

| 指标 | kat-coder | Claude Sonnet 4.5 | 差异 |
|------|-----------|-------------------|------|
| **解决率** | **39.2%** (196/500) | **64.5%** (314/487) | **-25.3%** |
| 已提交 | 500 | 500 | - |
| 已完成测试 | 410 | 487 | -77 |
| 已解决 | 196 | 314 | -118 |
| 未解决 | 214 | 173 | +41 |
| 空 Patch | 85 (17%) | ~25 (5%) | +60 |
| 错误实例 | 5 | - | - |

### 1.2 结果分析

**kat-coder 表现:**
- 解决率 39.2%，显著低于 Claude Sonnet 4.5 的 64.5%
- 空 Patch 率 17%，说明模型在部分问题上未能生成有效解决方案
- 410/500 实例完成了测试验证

---

## 第二部分：性能指标

### 2.1 迭代统计

| 指标 | kat-coder | Claude Sonnet 4.5 | 差异 |
|------|-----------|-------------------|------|
| 平均迭代数 | **54.0** | 81.3 | **-33%** |
| 最小迭代 | 7 | 19 | - |
| 最大迭代 | 102 | 100 | - |

**迭代分布:**

| 范围 | kat-coder | Claude Sonnet 4.5 |
|------|-----------|-------------------|
| 1-25 | 72 (14.4%) | 1 (0.3%) |
| 26-50 | 198 (39.6%) | 9 (2.9%) |
| 51-75 | 105 (21.0%) | 126 (40.1%) |
| 76-100 | 54 (10.8%) | 178 (56.7%) |
| 其他 | 71 (14.2%) | - |

**关键发现:** kat-coder 54% 的实例在 50 次迭代内完成（vs Claude Sonnet 4.5 的 3.2%），但解决率却更低。

### 2.2 延迟统计

| 指标 | kat-coder | Claude Sonnet 4.5 | 差异 |
|------|-----------|-------------------|------|
| 总 API 调用次数 | 26,611 | 40,675 | -35% |
| 总延迟时间 | 57.45 小时 | 98.08 小时 | -41% |
| **平均延迟** | **7.77 秒** | **8.68 秒** | **-10%** |

### 2.3 Token 使用

| 指标 | kat-coder | Claude Sonnet 4.5 | 差异 |
|------|-----------|-------------------|------|
| 总 Prompt Tokens | 903,405,938 | 1,764,316,046 | -49% |
| 总 Completion Tokens | 5,485,596 | 11,547,369 | -52% |
| 平均每实例 Prompt | 1,806,812 | 3,528,632 | -49% |
| 平均每实例 Completion | 10,971 | 23,095 | -52% |

---

## 第三部分：效率与准确率权衡

### 3.1 综合对比

| 指标 | kat-coder | Claude Sonnet 4.5 | 差异 |
|------|-----------|-------------------|------|
| **解决率** | 39.2% | 64.5% | -25.3% |
| 平均迭代数 | 54.0 | 81.3 | -33% |
| 平均延迟 | 7.77s | 8.68s | -10% |
| Token 消耗 | 903M | 1,764M | -49% |
| Patch 生成率 | 83% | ~95% | -12% |

### 3.2 关键发现

1. **效率 vs 准确率权衡**: kat-coder 使用更少的迭代和 tokens，但准确率显著降低
2. **早期终止问题**: 54% 的实例在 50 次迭代内完成，可能过早放弃
3. **Patch 生成能力**: 17% 的实例未能生成 patch，高于 Claude Sonnet 4.5
4. **延迟优势**: 平均 API 延迟快 10%，但总体优势被低解决率抵消

### 3.3 每解决实例成本对比

| 指标 | kat-coder | Claude Sonnet 4.5 |
|------|-----------|-------------------|
| 总 Tokens | ~909M | ~1,776M |
| 解决实例数 | 196 | 314 |
| **每解决实例 Tokens** | **4.64M** | **5.66M** |

尽管 kat-coder 总 token 消耗低 49%，但由于解决率低，每解决实例的 token 消耗只低 18%。

---

## 第四部分：问题与挑战

### 4.1 评估中断记录

| 时间 | 中断点 | 原因 | 处理 |
|------|--------|------|------|
| 第1次 | 108/500 | `django__django-10914` 重试耗尽 | 重启，自动恢复 |
| 第2次 | 140/500 | `django__django-16454` 重试耗尽 | 重启，自动恢复 |

### 4.2 Docker 资源管理

评估期间实施了定时清理守护进程：

```bash
#!/bin/bash
# cleanup_docker.sh - 每 20 分钟清理
while true; do
    sleep 1200
    docker container prune -f
    docker image prune -f --filter "until=1h"
    docker builder prune -f --keep-storage=30GB
    docker images --format "{{.ID}} {{.Repository}}" | \
        grep "ghcr.io/openhands/runtime" | \
        awk '{print $1}' | head -50 | xargs -r docker rmi -f
done
```

### 4.3 测试验证问题

部分实例在测试验证阶段出现问题：
- Patch 应用失败 (格式问题)
- 测试超时 (3600 秒限制)
- 5 个错误实例

---

## 第五部分：结论与建议

### 5.1 结论

1. **kat-coder 在 SWE-bench Verified 上的表现 (39.2%) 显著低于 Claude Sonnet 4.5 (64.5%)**
2. 模型倾向于更快决策，但牺牲了准确率
3. Token 效率高，但无法弥补解决率的差距
4. 空 Patch 率较高，表明模型在部分复杂问题上能力不足

### 5.2 可能的改进方向

1. **增加迭代限制**: 当前模型可能过早放弃，考虑增加到 150 次迭代
2. **调整温度参数**: 尝试非零温度以增加探索性
3. **优化 prompt**: 针对 SWE-bench 任务优化系统提示词
4. **分析失败案例**: 深入分析 214 个未解决实例的失败原因

---

## 第六部分：配置参考

### 6.1 模型配置 (config.toml)

```toml
[llm.kat_coder]
model = "openai/kat-coder"
base_url = "https://api.ppio.com/openai/v1"
api_key = "sk_xxx"
temperature = 0.0
```

### 6.2 运行命令

```bash
# 推理阶段
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh \
  llm.kat_coder \
  HEAD \
  CodeActAgent \
  500 \
  100 \
  8 \
  princeton-nlp/SWE-bench_Verified \
  test

# 测试验证阶段
./evaluation/benchmarks/swe_bench/scripts/eval_infer.sh \
  output.jsonl \
  "" \
  princeton-nlp/SWE-bench_Verified \
  test \
  local
```

### 6.3 输出文件

- 推理结果: `output.jsonl`
- 测试报告: `report.json`
- 日志目录: `infer_logs/`, `logs/`

---

## 附录：模型对比总结

| 模型 | 解决率 | 平均迭代 | 平均延迟 | Token消耗 | 备注 |
|------|--------|----------|----------|-----------|------|
| Claude Sonnet 4.5 | **64.5%** | 81.3 | 8.68s | 1,764M | 基准模型 |
| kat-coder | 39.2% | 54.0 | 7.77s | 903M | 效率高但准确率低 |

---

**报告生成时间:** 2026-01-25 01:20 CST
**评估模型:** kat-coder (通过 PPIO API)
**数据集:** princeton-nlp/SWE-bench_Verified
**状态:** ✅ 已完成
