#!/bin/bash
# 同步本地修改后的 JS Playwright 到 Python Playwright 的 driver 目录
#
# 使用方法:
#   ./scripts/sync_local_js_driver.sh [JS_PLAYWRIGHT_PATH]
#
# 参数:
#   JS_PLAYWRIGHT_PATH: JS playwright 项目路径 (默认: ../playwright)

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_PW_ROOT="$(dirname "$SCRIPT_DIR")"

# JS Playwright 项目路径
JS_PW_ROOT="${1:-$(dirname "$PYTHON_PW_ROOT")/playwright}"

# 源目录和目标目录
JS_CORE_DIR="$JS_PW_ROOT/packages/playwright-core"
JS_LIB_DIR="$JS_CORE_DIR/lib"
PYTHON_DRIVER_DIR="$PYTHON_PW_ROOT/playwright/driver/package"
PYTHON_DRIVER_LIB="$PYTHON_DRIVER_DIR/lib"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}同步 JS Playwright 到 Python Driver${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "JS Playwright 路径: ${GREEN}$JS_PW_ROOT${NC}"
echo -e "Python Playwright 路径: ${GREEN}$PYTHON_PW_ROOT${NC}"
echo ""

# 检查 JS playwright 路径是否存在
if [ ! -d "$JS_PW_ROOT" ]; then
    echo -e "${RED}错误: JS Playwright 项目路径不存在: $JS_PW_ROOT${NC}"
    exit 1
fi

# 检查 JS lib 目录是否存在
if [ ! -d "$JS_LIB_DIR" ]; then
    echo -e "${RED}错误: JS Playwright lib 目录不存在: $JS_LIB_DIR${NC}"
    echo -e "${YELLOW}提示: 请先在 JS Playwright 项目中运行 'npm run build'${NC}"
    exit 1
fi

# 检查 Python driver 目录是否存在
if [ ! -d "$PYTHON_DRIVER_LIB" ]; then
    echo -e "${RED}错误: Python Playwright driver 目录不存在: $PYTHON_DRIVER_LIB${NC}"
    exit 1
fi

# 备份原有的 lib 目录
BACKUP_DIR="$PYTHON_DRIVER_DIR/lib.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${YELLOW}[1/4] 备份原有 lib 目录...${NC}"
cp -r "$PYTHON_DRIVER_LIB" "$BACKUP_DIR"
echo -e "      备份保存到: $BACKUP_DIR"

# 删除旧的 lib 目录
echo -e "${YELLOW}[2/4] 删除旧的 lib 目录...${NC}"
rm -rf "$PYTHON_DRIVER_LIB"

# 复制新的 lib 目录
echo -e "${YELLOW}[3/4] 复制新的 lib 目录...${NC}"
cp -r "$JS_LIB_DIR" "$PYTHON_DRIVER_LIB"

# 同步 browsers.json (确保浏览器版本匹配)
echo -e "${YELLOW}[4/4] 同步 browsers.json...${NC}"
cp "$JS_CORE_DIR/browsers.json" "$PYTHON_DRIVER_DIR/browsers.json"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}同步完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "现在你可以使用 Python Playwright 来测试你的修改了。"
echo -e "使用 DEBUG=pw:api 环境变量可以查看详细日志。"
echo ""
echo -e "${YELLOW}注意：如果浏览器版本有更新，需要运行：${NC}"
echo -e "  ${GREEN}python -m playwright install chromium${NC}"
echo ""
echo -e "示例测试命令:"
echo -e "  ${YELLOW}DEBUG=pw:api python3 tests/test_custom_dev_modification.py${NC}"
echo ""
echo -e "或使用 pytest:"
echo -e "  ${YELLOW}DEBUG=pw:api pytest tests/test_custom_dev_modification.py -v -s${NC}"

