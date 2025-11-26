# Playwright API 变更指南

本文档介绍如何将 API 变更从 JS Playwright 同步到 Python Playwright。

## 概述

当需要在 Playwright 中添加或修改 API 时，需要同时修改 JS Playwright 和 Python Playwright 两个项目。整个流程包括以下几个主要步骤：

```
┌─────────────────────────────────────────────────────────────────┐
│                      JS Playwright                               │
├─────────────────────────────────────────────────────────────────┤
│  1. protocol.yml      → 定义协议参数                             │
│  2. client/*.ts       → 客户端 API 实现                          │
│  3. server/*.ts       → 服务端处理逻辑                           │
│  4. docs/src/api/*.md → API 文档（用于生成类型定义）              │
│  5. npm run build     → 构建并生成 channels.d.ts & types.d.ts   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Python Playwright                             │
├─────────────────────────────────────────────────────────────────┤
│  6. _api_structures.py    → 添加新类型定义                       │
│  7. _impl/_locator.py 等  → 实现层添加参数                       │
│  8. generate_api.py       → 更新生成脚本的 header                │
│  9. sync_local_js_driver  → 同步 JS driver                       │
│  10. 生成 api.json        → 从 JS 生成 API 定义                  │
│  11. generate_*_api.py    → 生成 Python API                      │
└─────────────────────────────────────────────────────────────────┘
```

## 详细步骤

### 第一部分：JS Playwright 修改

#### 1. 修改 Protocol 定义

**文件**: `packages/protocol/src/protocol.yml`

在这里定义 RPC 协议中的新参数。这是 Playwright 内部客户端和服务端通信的协议定义。

```yaml
# 示例：为 ariaSnapshot 添加 mode 参数
ariaSnapshot:
  title: Aria snapshot
  parameters:
    selector: string
    timeout: float
    mode:                    # 新增参数
      type: enum?            # 可选枚举类型
      literals:
        - expect
        - ai
  returns:
    snapshot: string
```

**注意事项**：
- 可选参数使用 `?` 后缀，如 `enum?`
- 枚举类型需要 `type:` 和 `literals:` 两个字段
- 必须遵循 YAML 缩进格式

#### 2. 修改客户端 API

**文件**: `packages/playwright-core/src/client/locator.ts`

在客户端 API 中添加新参数：

```typescript
// 修改前
async ariaSnapshot(options?: TimeoutOptions): Promise<string> {
  const result = await this._frame._channel.ariaSnapshot({
    ...options, 
    selector: this._selector, 
    timeout: this._frame._timeout(options)
  });
  return result.snapshot;
}

// 修改后
async ariaSnapshot(options?: TimeoutOptions & { mode?: 'expect' | 'ai' }): Promise<string> {
  const result = await this._frame._channel.ariaSnapshot({
    ...options, 
    selector: this._selector, 
    timeout: this._frame._timeout(options),
    mode: options?.mode  // 新增
  });
  return result.snapshot;
}
```

#### 3. 修改 Dispatcher

**文件**: `packages/playwright-core/src/server/dispatchers/frameDispatcher.ts`

在 dispatcher 中传递新参数：

```typescript
async ariaSnapshot(params: channels.FrameAriaSnapshotParams, progress: Progress): Promise<channels.FrameAriaSnapshotResult> {
  return { 
    snapshot: await this._frame.ariaSnapshot(progress, params.selector, { mode: params.mode })  // 传递 mode
  };
}
```

#### 4. 修改服务端实现

**文件**: `packages/playwright-core/src/server/frames.ts`

```typescript
async ariaSnapshot(progress: Progress, selector: string, options?: { mode?: 'expect' | 'ai' }): Promise<string> {
  return await this._retryWithProgressIfNotConnected(
    progress, selector, true, true, 
    handle => progress.race(handle.ariaSnapshot(options))  // 传递 options
  );
}
```

**文件**: `packages/playwright-core/src/server/dom.ts`

```typescript
async ariaSnapshot(options?: { mode?: 'expect' | 'ai' }): Promise<string> {
  const mode = options?.mode || 'expect';
  return await this.evaluateInUtility(
    ([injected, element, mode]) => injected.ariaSnapshot(element, { mode }), 
    mode
  );
}
```

#### 5. 修改 API 文档（重要！）

**文件**: `docs/src/api/class-locator.md`

这是最关键的一步！Python API 生成是基于文档定义的，不是基于 TypeScript 代码。

```markdown
### option: Locator.ariaSnapshot.timeout = %%-input-timeout-%%
* since: v1.49

### option: Locator.ariaSnapshot.timeout = %%-input-timeout-js-%%
* since: v1.49

### option: Locator.ariaSnapshot.mode
* since: v1.50
- `mode` <[AriaSnapshotMode]<"expect"|"ai">>

The mode for generating the aria snapshot. Defaults to `'expect'`.
* `'expect'` - Standard mode for assertions, without viewport position markers.
* `'ai'` - AI mode that includes viewport position markers.
```

**格式说明**：
- `<[TypeName]<"value1"|"value2">>` 定义枚举类型
- `* since: vX.XX` 标记版本号
- 支持 Markdown 格式的文档说明

#### 6. 构建 JS Playwright

```bash
cd /path/to/playwright
npm run build
```

构建会自动生成：
- `packages/protocol/src/channels.d.ts` - 协议类型定义
- `packages/playwright-core/types/types.d.ts` - 公共 API 类型定义

验证生成的类型定义包含新参数：
```bash
grep -A 10 "ariaSnapshot(" packages/playwright-core/types/types.d.ts
```

---

### 第二部分：Python Playwright 修改

#### 7. 添加类型定义

**文件**: `playwright/_impl/_api_structures.py`

```python
# 添加新的类型别名
AriaSnapshotMode = Literal[
    "expect",
    "ai",
]
```

#### 8. 修改实现层

**文件**: `playwright/_impl/_locator.py`

```python
# 导入新类型
from playwright._impl._api_structures import (
    AriaRole,
    AriaSnapshotMode,  # 新增
    # ...
)

# 修改方法签名
async def aria_snapshot(
    self,
    timeout: float = None,
    mode: AriaSnapshotMode = None,  # 新增参数
) -> str:
    return await self._frame._channel.send(
        "ariaSnapshot",
        self._frame._timeout,
        {
            "selector": self._selector,
            **locals_to_params(locals()),  # 自动包含所有参数
        },
    )
```

#### 9. 修改生成脚本

**文件**: `scripts/generate_api.py`

在 `header` 字符串中添加新类型的导入：

```python
header = """
# ...
from playwright._impl._api_structures import AriaSnapshotMode, Cookie, SetCookieParam, ...
# ...
"""
```

#### 10. 同步 JS Driver

```bash
cd /path/to/playwright-python

# 使用同步脚本（如果有）
./scripts/sync_local_js_driver.sh /path/to/playwright

# 或手动复制
cp -r /path/to/playwright/packages/playwright-core/lib playwright/driver/package/
cp /path/to/playwright/packages/playwright-core/browsers.json playwright/driver/package/
```

#### 11. 生成 API JSON

```bash
cd /path/to/playwright
API_JSON_MODE=1 node utils/doclint/generateApiJson.js > /path/to/playwright-python/playwright/driver/package/api.json
```

#### 12. 重新生成 Python API

```bash
cd /path/to/playwright-python

# 可能需要创建 python 符号链接
ln -sf $(which python3) /tmp/python

# 生成同步和异步 API
PATH="/tmp:$PATH" python3 scripts/generate_sync_api.py > playwright/sync_api/_generated.py
PATH="/tmp:$PATH" python3 scripts/generate_async_api.py > playwright/async_api/_generated.py
```

验证生成的 API 包含新参数：
```bash
grep -A 5 "def aria_snapshot" playwright/sync_api/_generated.py
```

---

## 完整命令速查

```bash
# ===== JS Playwright =====
cd /path/to/playwright

# 1. 修改代码（手动）
# - packages/protocol/src/protocol.yml
# - packages/playwright-core/src/client/locator.ts
# - packages/playwright-core/src/server/dispatchers/frameDispatcher.ts
# - packages/playwright-core/src/server/frames.ts
# - packages/playwright-core/src/server/dom.ts
# - docs/src/api/class-locator.md

# 2. 构建
npm run build

# 3. 验证
node dev-test/test-viewport-position.js

# ===== Python Playwright =====
cd /path/to/playwright-python

# 4. 修改代码（手动）
# - playwright/_impl/_api_structures.py
# - playwright/_impl/_locator.py
# - scripts/generate_api.py

# 5. 同步 driver
./scripts/sync_local_js_driver.sh /path/to/playwright

# 6. 生成 api.json
cd /path/to/playwright
API_JSON_MODE=1 node utils/doclint/generateApiJson.js > /path/to/playwright-python/playwright/driver/package/api.json

# 7. 生成 Python API
cd /path/to/playwright-python
ln -sf $(which python3) /tmp/python
PATH="/tmp:$PATH" python3 scripts/generate_sync_api.py > playwright/sync_api/_generated.py
PATH="/tmp:$PATH" python3 scripts/generate_async_api.py > playwright/async_api/_generated.py

# 8. 安装并测试
pip3 install -e .
pytest tests/test_viewport_position_marker.py -v
```

---

## 常见问题

### Q1: "Parameter not implemented" 错误

**原因**: api.json 中有参数定义，但 Python 实现层没有该参数。

**解决**: 在 `_impl/_locator.py` 等文件中添加对应参数。

### Q2: "Parameter not documented" 错误

**原因**: Python 代码中有参数，但 api.json 中没有定义。

**解决**: 检查 `docs/src/api/*.md` 文档是否正确定义了参数。

### Q3: 类型不匹配错误

**原因**: Python 代码中的类型与文档定义的类型不一致。

**解决**: 
1. 检查 `_api_structures.py` 中的类型定义
2. 检查文档中的类型表达式格式

### Q4: 新类型未出现在生成的 API 中

**原因**: `generate_api.py` 的 header 中没有导入新类型。

**解决**: 在 `scripts/generate_api.py` 的 header 字符串中添加新类型的导入。

### Q5: FileNotFoundError: 'python' not found

**原因**: 某些脚本使用 `python` 而不是 `python3`。

**解决**: 创建符号链接 `ln -sf $(which python3) /tmp/python` 并添加到 PATH。

---

## 文件修改清单

| 项目 | 文件 | 说明 |
|------|------|------|
| JS | `packages/protocol/src/protocol.yml` | 协议定义 |
| JS | `packages/playwright-core/src/client/*.ts` | 客户端 API |
| JS | `packages/playwright-core/src/server/dispatchers/*.ts` | Dispatcher |
| JS | `packages/playwright-core/src/server/*.ts` | 服务端实现 |
| JS | `docs/src/api/*.md` | **API 文档（关键！）** |
| Python | `playwright/_impl/_api_structures.py` | 类型定义 |
| Python | `playwright/_impl/*.py` | 实现层 |
| Python | `scripts/generate_api.py` | 生成脚本 header |

---

## 版本说明

- 本文档基于 Playwright v1.50+ 编写
- 适用于添加新参数、新方法等 API 变更场景
- 最后更新: 2025-11-26

