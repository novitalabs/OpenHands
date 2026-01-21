# PPIO Claude Sonnet 4.5 SWE-bench Evaluation Report

**Date:** 2026-01-21
**Model:** Claude Sonnet 4.5 (`pa/claude-sonnet-4-5-20250929`)
**API Provider:** PPIO
**Evaluation Framework:** OpenHands v1.2.1

---

## Stage 1 Validation Results

### Summary

| Metric | Value |
|--------|-------|
| **Total Instances** | 10 |
| **Patches Generated** | 10 (100%) |
| **Tests Passed (Resolved)** | 3 (30%) |
| **Tests Failed (Unresolved)** | 7 (70%) |
| **Errors** | 0 |
| **Total Runtime** | ~3 hours |

### Resolved Instances (Tests Passed)

| Instance ID | Modified File |
|-------------|---------------|
| django__django-16379 | django/core/cache/backends/filebased.py |
| pytest-dev__pytest-6116 | src/_pytest/main.py |
| scikit-learn__scikit-learn-13779 | sklearn/ensemble/voting.py |

### Unresolved Instances (Tests Failed)

| Instance ID | Modified File |
|-------------|---------------|
| astropy__astropy-7746 | astropy/wcs/wcs.py |
| django__django-11019 | django/forms/widgets.py |
| psf__requests-2317 | requests/models.py |
| scikit-learn__scikit-learn-25500 | sklearn/calibration.py |
| sympy__sympy-12171 | sympy/printing/mathematica.py |
| sympy__sympy-13146 | sympy/core/numbers.py |
| sympy__sympy-18189 | sympy (diophantine) |

---

## Configuration

### config.toml

```toml
# PPIO Claude Sonnet 4.5 SWE-bench Evaluation Config

[sandbox]
timeout = 300
use_host_network = true
enable_auto_lint = true
platform = "linux/amd64"

[llm.ppio_claude_sonnet]
model = "openai/pa/claude-sonnet-4-5-20250929"
base_url = "https://api.ppio.com/openai/v1"
api_key = "<YOUR_API_KEY>"
temperature = 0.0
```

### Docker Proxy Configuration (~/.docker/config.json)

```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://172.17.0.1:1081",
      "httpsProxy": "http://172.17.0.1:1081",
      "noProxy": "docker.sandbox.ppio.cn,localhost,127.0.0.1"
    }
  }
}
```

---

## Commands

### 1. Run Inference (Generate Patches)

```bash
# Stage 1: 10 instances validation
HTTPS_PROXY=http://172.17.0.1:1081 \
HTTP_PROXY=http://172.17.0.1:1081 \
NO_PROXY=localhost,127.0.0.1 \
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh \
  llm.ppio_claude_sonnet \
  HEAD \
  CodeActAgent \
  10 \    # EVAL_LIMIT (number of instances)
  100 \   # MAX_ITER (max iterations per instance)
  1       # NUM_WORKERS

# Stage 2: 300 instances (medium scale)
HTTPS_PROXY=http://172.17.0.1:1081 \
HTTP_PROXY=http://172.17.0.1:1081 \
NO_PROXY=localhost,127.0.0.1 \
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh \
  llm.ppio_claude_sonnet \
  HEAD \
  CodeActAgent \
  300 \
  100 \
  1

# Stage 3: Full SWE-bench_Verified (500 instances)
HTTPS_PROXY=http://172.17.0.1:1081 \
HTTP_PROXY=http://172.17.0.1:1081 \
NO_PROXY=localhost,127.0.0.1 \
./evaluation/benchmarks/swe_bench/scripts/run_infer.sh \
  llm.ppio_claude_sonnet \
  HEAD \
  CodeActAgent \
  500 \
  100 \
  1
```

### 2. Run Evaluation (Test Patches)

```bash
# Evaluate generated patches
./evaluation/benchmarks/swe_bench/scripts/eval_infer.sh \
  evaluation/evaluation_outputs/outputs/princeton-nlp__SWE-bench_Lite-test/CodeActAgent/claude-sonnet-4-5-20250929_maxiter_100_N_v1.2.1-no-hint-run_1/output.jsonl
```

### 3. View Results

```bash
# View evaluation report
cat evaluation/evaluation_outputs/outputs/princeton-nlp__SWE-bench_Lite-test/CodeActAgent/claude-sonnet-4-5-20250929_maxiter_100_N_v1.2.1-no-hint-run_1/report.json | python3 -m json.tool

# Quick summary of patches
python3 -c "
import json
with open('evaluation/evaluation_outputs/outputs/princeton-nlp__SWE-bench_Lite-test/CodeActAgent/claude-sonnet-4-5-20250929_maxiter_100_N_v1.2.1-no-hint-run_1/output.jsonl') as f:
    for line in f:
        data = json.loads(line)
        instance_id = data['instance_id']
        patch = data.get('test_result', {}).get('git_patch', '')
        resolved = data.get('test_result', {}).get('resolved', False)
        status = 'RESOLVED' if resolved else ('PATCH' if patch else 'NO_PATCH')
        print(f'{instance_id}: {status}')
"
```

---

## Troubleshooting

### Issue 1: Docker Build Failure

**Symptom:** Docker build fails when pulling base images

**Solution:** Configure Docker proxy in `~/.docker/config.json`:
```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://172.17.0.1:1081",
      "httpsProxy": "http://172.17.0.1:1081"
    }
  }
}
```

### Issue 2: LiteLLM Provider Error

**Symptom:** `litellm.BadRequestError: LLM Provider NOT provided`

**Solution:** Use `openai/` prefix for model name:
```toml
model = "openai/pa/claude-sonnet-4-5-20250929"  # NOT "pa/claude-sonnet-4-5-20250929"
```

### Issue 3: Runtime 503 Errors

**Symptom:** Runtime containers fail with 503 Service Unavailable

**Cause:** httpx routes localhost through HTTP_PROXY

**Solution:** Add `NO_PROXY=localhost,127.0.0.1` to environment:
```bash
NO_PROXY=localhost,127.0.0.1 ./evaluation/benchmarks/swe_bench/scripts/run_infer.sh ...
```

---

## Output Files

| File | Description |
|------|-------------|
| `output.jsonl` | Raw inference output with patches |
| `output.swebench.jsonl` | Converted SWE-bench format |
| `report.json` | Evaluation results summary |
| `eval_outputs/` | Per-instance test logs |
| `llm_completions/` | LLM API call logs |

---

## Reference

- **OpenHands Documentation:** https://docs.all-hands.dev/
- **SWE-bench:** https://www.swebench.com/
- **PPIO API:** https://api.ppio.com/
