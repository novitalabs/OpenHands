# PPIO Claude Sonnet 4.5 SWE-bench 评估报告 - Stage 3

## 评估概述

| 项目 | 值 |
|------|-----|
| **模型** | `pa/claude-sonnet-4-5-20250929` (通过 PPIO API) |
| **数据集** | `princeton-nlp/SWE-bench_Verified` |
| **实例数量** | 500 |
| **Agent** | CodeActAgent |
| **最大迭代** | 100 |
| **并行 Workers** | 8 |
| **开始时间** | 2026-01-22 02:29 CST |
| **API 端点** | `https://api.ppio.com/openai/v1` |

## 最终结果

| 指标 | 值 |
|------|-----|
| **推理完成** | 500/500 (100%) |
| **评估完成** | 494/500 |
| **有效评估** | 487 个实例 |
| **解决成功 (Resolved)** | **314** |
| **解决失败** | 173 |
| **准确率 (Pass Rate)** | **64.5%** (314/487) |
| **总耗时** | ~16 小时 |
| **结束时间** | 2026-01-22 19:00 CST |

### 与其他模型的对比

| 模型 | SWE-bench Verified 准确率 |
|------|---------------------------|
| **PPIO Claude Sonnet 4.5** | **64.5%** |
| Claude 3.5 Sonnet (官方) | ~49% |
| GPT-4o | ~33% |
| Claude 3 Opus | ~22% |

**注**: PPIO Claude Sonnet 4.5 的表现显著优于之前的模型版本。

## 配置文件

```toml
# config.toml
[sandbox]
timeout = 300
use_host_network = true
enable_auto_lint = true
platform = "linux/amd64"

[llm.ppio_claude_sonnet]
model = "openai/pa/claude-sonnet-4-5-20250929"
base_url = "https://api.ppio.com/openai/v1"
api_key = "sk_jBm8G4CucFaufxrzfmqheXYSpxF-sF30lgXXR1X-0xc"
temperature = 0.0
```

## 运行命令

```bash
HTTPS_PROXY=http://172.17.0.1:1081 \
HTTP_PROXY=http://172.17.0.1:1081 \
NO_PROXY=localhost,127.0.0.1 \
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh \
  llm.ppio_claude_sonnet \
  HEAD \
  CodeActAgent \
  500 \
  100 \
  8 \
  princeton-nlp/SWE-bench_Verified \
  test
```

## 遇到的问题及解决方案

### 1. Docker Buildx 构建失败

**问题**: 多个 worker 同时构建相同的 runtime 镜像时发生冲突。

**解决方案**:
- 手动预构建一个 runtime 镜像
- 将 worker 数量从 16 减少到 8
- 清理 Docker 资源后重试

### 2. 磁盘空间不足 (关键问题)

**问题**: Docker build cache 持续增长，从几十GB增长到超过 1.4TB，最终导致磁盘满 (100%)，评估进程崩溃。

**原因分析**:
- 每个 SWE-bench 实例需要构建独立的 runtime Docker 镜像
- OpenHands 使用 `docker buildx build` 构建镜像
- 默认情况下，buildx 使用 Docker daemon 的 build cache，不会自动清理
- 500 个实例 × 每个镜像 ~10GB 的构建层 = 大量缓存累积

**相关代码** (`openhands/runtime/builder/docker.py:135-162`):
```python
buildx_cmd = [
    'docker', 'buildx', 'build',
    '--progress=plain',
    f'--build-arg=OPENHANDS_RUNTIME_VERSION={get_version()}',
    f'--build-arg=OPENHANDS_RUNTIME_BUILD_TIME={datetime.datetime.now().isoformat()}',
    f'--tag={target_image_hash_name}',
    '--load',
]

# 可选的本地缓存 (默认未启用)
cache_dir = '/tmp/.buildx-cache'
if use_local_cache and self._is_cache_usable(cache_dir):
    buildx_cmd.extend([
        f'--cache-from=type=local,src={cache_dir}',
        f'--cache-to=type=local,dest={cache_dir},mode=max',
    ])
```

**临时解决方案**: 定期执行清理命令
```bash
# 每小时执行一次
docker container prune -f
docker image prune -f
docker builder prune -f --keep-storage=50GB
```

### 3. 优化建议

#### 方案 A: 修改 OpenHands 代码限制 build cache

在 `docker.py` 中添加 `--cache-to` 限制:
```python
buildx_cmd.extend([
    '--cache-to=type=inline',  # 只保存内联缓存，不累积
])
```

或使用外部缓存目录并定期清理:
```python
buildx_cmd.extend([
    f'--cache-to=type=local,dest=/tmp/buildx-cache,mode=min',
])
```

#### 方案 B: 使用独立的 buildx builder 并限制大小

```bash
# 创建带大小限制的 builder
docker buildx create --name limited-builder \
  --driver docker-container \
  --driver-opt "env.BUILDKIT_GC_POLICY=keep_storage=50GB"

docker buildx use limited-builder
```

#### 方案 C: 评估脚本中添加自动清理

修改 `run_infer.sh` 或创建包装脚本:
```bash
#!/bin/bash
# 每处理 N 个实例后清理一次
cleanup_interval=50

while true; do
    sleep 1800  # 30分钟
    docker builder prune -f --keep-storage=50GB
    docker image prune -f --filter "until=2h"
done &

# 运行评估
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh "$@"
```

#### 方案 D: 配置 Docker daemon 的垃圾回收

在 `/etc/docker/daemon.json` 中添加:
```json
{
  "builder": {
    "gc": {
      "enabled": true,
      "defaultKeepStorage": "50GB",
      "policy": [
        {"keepStorage": "50GB", "filter": ["unused-for=24h"]}
      ]
    }
  }
}
```

## 资源使用情况

| 资源 | 峰值使用 | 建议 |
|------|---------|------|
| 磁盘 | 100% (3.5TB) | 预留至少 500GB，启用自动清理 |
| Docker Images | ~400GB | 定期清理旧镜像 |
| Docker Build Cache | ~1.4TB | **必须限制或定期清理** |
| 内存 | ~50GB | 8 workers 需要足够内存 |

## 结论

1. **模型性能**: PPIO Claude Sonnet 4.5 在 SWE-bench Verified 上达到了 **64.5%** 的准确率，表现出色
2. **API 稳定性**: PPIO API 稳定，能够支持 500 实例的长时间评估（~16小时）
3. **主要瓶颈**: Docker build cache 累积是最大问题，需要在 OpenHands 框架层面解决
4. **建议**:
   - 短期: 使用定时清理脚本
   - 长期: 向 OpenHands 提交 PR 增加 build cache 管理功能

## 评估完成情况

- **Stage 1** (10 实例测试): 30% 准确率 - 用于验证配置
- **Stage 3** (500 实例完整评估): **64.5%** 准确率 - 最终结果

## 输出文件位置

```
evaluation/evaluation_outputs/outputs/princeton-nlp__SWE-bench_Verified-test/CodeActAgent/claude-sonnet-4-5-20250929_maxiter_100_N_v1.2.1-no-hint-run_1/
├── output.jsonl          # 主要结果文件
├── metadata.json         # 元数据
├── infer_logs/           # 推理日志
└── llm_completions/      # LLM 完成记录
```
