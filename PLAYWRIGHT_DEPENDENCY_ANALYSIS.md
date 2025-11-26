# Playwright-Python 依赖关系分析

## 1. 依赖关系概述

**是的，playwright-python 确实依赖了 JS 的 playwright 项目。**

playwright-python 并不是一个完全独立的实现，而是作为 JS playwright 的 Python 绑定层。它通过以下方式依赖 JS playwright：

## 2. 依赖方式详解

### 2.1 Driver 包机制

playwright-python 通过下载和打包 **Driver 包** 来获取 JS playwright 的运行时：

1. **Driver 版本定义**：在 `setup.py` 中定义了 `driver_version` 变量
   ```python
   driver_version = "1.57.0-beta-1763718928000"
   ```

2. **Driver 下载**：构建时会从 CDN 下载预编译的 driver 包
   - URL 格式：`https://cdn.playwright.dev/builds/driver/playwright-{version}-{platform}.zip`
   - 支持的平台包括：mac、mac-arm64、linux、linux-arm64、win32_x64、win32_arm64

3. **Driver 内容**：每个 driver 包包含：
   - Node.js 可执行文件（`node` 或 `node.exe`）
   - JS playwright 的代码（`package/cli.js` 等）
   - API JSON 定义文件（`package/api.json`）

### 2.2 运行时交互

playwright-python 通过以下方式与 JS playwright 交互：

1. **进程调用**：Python 代码通过 `subprocess` 调用 Node.js 执行 driver 中的 `cli.js`
   - 参考：`playwright/__main__.py` 和 `playwright/_impl/_driver.py`

2. **通信协议**：使用 JSON-RPC 或类似的协议进行进程间通信
   - Python 端作为客户端，JS driver 作为服务器

3. **API 生成**：Python API 通过以下方式生成：
   - 从 driver 的 `api.json` 文件读取 API 定义
   - 使用 `scripts/generate_sync_api.py` 和 `scripts/generate_async_api.py` 生成 Python 代码
   - 参考：`scripts/documentation_provider.py` 中的 `print-api-json` 命令

## 3. 如何基于修改后的 playwright 项目重新编译

### 3.1 前提条件

1. **修改 JS playwright 项目**：
   - 克隆并修改 [playwright](https://github.com/microsoft/playwright) 项目
   - 进行你需要的修改

2. **构建 JS playwright driver**：
   - 在 playwright 项目中构建 driver 包
   - 通常需要运行 `npm run build` 或类似的构建命令
   - 生成对应平台的 driver zip 包

### 3.2 方法一：使用本地构建的 driver（推荐用于开发）

1. **构建本地 driver**：
   ```bash
   # 在 playwright 项目中
   npm run build
   # 这会生成 driver 包，通常位于 packages/playwright-core/bundles/ 目录
   ```

2. **修改 playwright-python 的构建流程**：
   - 修改 `setup.py` 中的 `download_driver` 函数，使其从本地路径读取而不是从 CDN 下载
   - 或者设置环境变量指向本地 driver 路径

3. **手动放置 driver**：
   ```bash
   # 将构建好的 driver zip 包放到 playwright-python/driver/ 目录
   # 文件名格式：playwright-{version}-{platform}.zip
   ```

4. **构建 Python 包**：
   ```bash
   python -m build --wheel
   ```

### 3.3 方法二：使用自定义 driver 版本（推荐用于发布）

1. **上传自定义 driver 到 CDN**（如果有权限）：
   - 将构建好的 driver 包上传到 `https://cdn.playwright.dev/builds/driver/`
   - 使用新的版本号

2. **修改 setup.py**：
   ```python
   driver_version = "你的自定义版本号"
   ```

3. **构建 Python 包**：
   ```bash
   python -m build --wheel
   ```

### 3.4 方法三：使用本地 driver 路径（临时方案）

1. **修改 `playwright/_impl/_driver.py`**：
   - 修改 `compute_driver_executable()` 函数，使其指向你的本地 playwright 构建

2. **设置环境变量**：
   ```bash
   export PLAYWRIGHT_NODEJS_PATH=/path/to/your/node
   export PLAYWRIGHT_DRIVER_PATH=/path/to/your/playwright/driver
   ```

### 3.5 更新 API 定义

如果修改了 JS playwright 的 API，需要更新 Python API：

1. **生成新的 API JSON**（在 playwright 项目中）：
   ```bash
   cd playwright
   API_JSON_MODE=1 node utils/doclint/generateApiJson.js > ../playwright-python/playwright/driver/package/api.json
   ```

2. **重新生成 Python API**：
   ```bash
   cd playwright-python
   ./scripts/update_api.sh
   ```

3. **验证更改**：
   ```bash
   pre-commit run --all-files
   ```

## 4. 构建流程总结

完整的重新编译流程：

```bash
# 1. 在 playwright 项目中构建 driver
cd playwright
npm install
npm run build
# 生成 driver 包到相应目录

# 2. 在 playwright-python 中
cd playwright-python

# 3. 更新 driver 版本（如果需要）
# 编辑 setup.py，修改 driver_version

# 4. 放置或配置本地 driver
# 方法 A: 将 driver zip 放到 driver/ 目录
# 方法 B: 修改 setup.py 使用本地路径

# 5. 更新 API（如果 API 有变化）
# 从 playwright 项目生成 api.json 并更新
API_JSON_MODE=1 node ../playwright/utils/doclint/generateApiJson.js > playwright/driver/package/api.json
./scripts/update_api.sh

# 6. 构建 Python wheel
python -m build --wheel

# 7. 安装并测试
pip install dist/playwright-*.whl
playwright install
pytest --browser chromium
```

## 5. 关键文件说明

- **`setup.py`**：定义 driver 版本和构建流程
- **`playwright/_impl/_driver.py`**：driver 可执行文件的路径计算
- **`playwright/__main__.py`**：CLI 入口，调用 driver
- **`scripts/generate_sync_api.py`**：生成同步 API
- **`scripts/generate_async_api.py`**：生成异步 API
- **`scripts/documentation_provider.py`**：从 driver 获取 API JSON
- **`ROLLING.md`**：更新到新版本的指南

## 6. 注意事项

1. **版本匹配**：确保 driver 版本与 playwright-python 代码兼容
2. **平台支持**：需要为所有目标平台构建 driver
3. **API 兼容性**：修改 JS API 后需要同步更新 Python API 生成脚本
4. **测试**：重新编译后务必运行完整的测试套件
