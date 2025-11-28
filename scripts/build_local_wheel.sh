#!/bin/bash
# 构建包含本地修改的 Playwright Python wheel 包
#
# 使用方法:
#   ./scripts/build_local_wheel.sh [JS_PLAYWRIGHT_PATH] [--platform PLATFORM]
#
# 参数:
#   JS_PLAYWRIGHT_PATH: JS playwright 项目路径 (默认: ../playwright)
#   --platform PLATFORM: 指定目标平台，可选值:
#                        - mac-arm64 (macOS ARM64)
#                        - linux (Linux x86_64)
#                        - all (同时构建 Mac 和 Linux，默认)
#
# 示例:
#   ./scripts/build_local_wheel.sh                           # 构建 Mac + Linux
#   ./scripts/build_local_wheel.sh ../playwright             # 指定 JS 路径
#   ./scripts/build_local_wheel.sh --platform mac-arm64      # 仅构建 Mac
#   ./scripts/build_local_wheel.sh --platform linux          # 仅构建 Linux
#
# 输出:
#   dist/playwright-*-macosx_11_0_arm64.whl  - macOS ARM64 wheel
#   dist/playwright-*-manylinux1_x86_64.whl  - Linux x86_64 wheel

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认参数
TARGET_PLATFORM="all"
JS_PW_ROOT=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            TARGET_PLATFORM="$2"
            shift 2
            ;;
        *)
            if [ -z "$JS_PW_ROOT" ]; then
                JS_PW_ROOT="$1"
            fi
            shift
            ;;
    esac
done

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_PW_ROOT="$(dirname "$SCRIPT_DIR")"

# JS Playwright 项目路径（默认值）
JS_PW_ROOT="${JS_PW_ROOT:-$(dirname "$PYTHON_PW_ROOT")/playwright}"

# 源目录
JS_CORE_DIR="$JS_PW_ROOT/packages/playwright-core"
JS_LIB_DIR="$JS_CORE_DIR/lib"

# Python driver 目录
PYTHON_DRIVER_DIR="$PYTHON_PW_ROOT/playwright/driver"
PYTHON_DRIVER_PACKAGE="$PYTHON_DRIVER_DIR/package"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   构建 Playwright Python Wheel (包含本地修改)              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "JS Playwright 路径: ${GREEN}$JS_PW_ROOT${NC}"
echo -e "Python Playwright 路径: ${GREEN}$PYTHON_PW_ROOT${NC}"
echo -e "目标平台: ${GREEN}$TARGET_PLATFORM${NC}"
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

cd "$PYTHON_PW_ROOT"

# 获取 setup.py 中的 driver_version（兼容 macOS 和 Linux）
DRIVER_VERSION=$(grep 'driver_version = "' setup.py | sed 's/.*driver_version = "\([^"]*\)".*/\1/' | head -1)
if [ -z "$DRIVER_VERSION" ]; then
    DRIVER_VERSION="1.58.0-local"
fi
echo -e "Driver 版本: ${GREEN}$DRIVER_VERSION${NC}"
echo ""

# ========== 步骤 1: 清理旧的构建产物 ==========
echo -e "${YELLOW}[1/4] 清理旧的构建产物...${NC}"
rm -rf dist/ build/ *.egg-info wheelhouse/ 2>/dev/null || true
rm -rf driver/*.zip 2>/dev/null || true
mkdir -p dist driver
echo -e "      ${GREEN}✓ 清理完成${NC}"

# ========== 步骤 2: 创建本地 driver zip 包 ==========
echo -e "${YELLOW}[2/4] 创建本地 driver zip 包（包含修改后的代码）...${NC}"

# 函数：创建指定平台的 driver zip
create_driver_zip() {
    local ZIP_NAME=$1
    local ZIP_FILE="driver/playwright-${DRIVER_VERSION}-${ZIP_NAME}.zip"
    
    echo -e "      创建 ${BLUE}$ZIP_FILE${NC}..."
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    
    # 复制 package 目录结构
    mkdir -p "$TEMP_DIR/package"
    
    # 复制修改后的 lib 目录（关键！）
    cp -r "$JS_LIB_DIR" "$TEMP_DIR/package/lib"
    
    # 复制其他必要文件
    cp "$JS_CORE_DIR/browsers.json" "$TEMP_DIR/package/"
    cp "$JS_CORE_DIR/cli.js" "$TEMP_DIR/package/" 2>/dev/null || true
    cp "$JS_CORE_DIR/index.js" "$TEMP_DIR/package/" 2>/dev/null || true
    cp "$JS_CORE_DIR/index.mjs" "$TEMP_DIR/package/" 2>/dev/null || true
    cp "$JS_CORE_DIR/index.d.ts" "$TEMP_DIR/package/" 2>/dev/null || true
    cp "$JS_CORE_DIR/package.json" "$TEMP_DIR/package/" 2>/dev/null || true
    
    # 复制 bin 目录
    if [ -d "$JS_CORE_DIR/bin" ]; then
        cp -r "$JS_CORE_DIR/bin" "$TEMP_DIR/package/"
    fi
    
    # 复制 types 目录
    if [ -d "$JS_CORE_DIR/types" ]; then
        cp -r "$JS_CORE_DIR/types" "$TEMP_DIR/package/"
    fi
    
    # 复制目标平台对应的 node 可执行文件（关键！修复跨平台构建问题）
    # 根据 ZIP_NAME 选择正确的平台目录
    local PLATFORM_DIR="$PYTHON_PW_ROOT/driver/$ZIP_NAME"
    if [ -f "$PLATFORM_DIR/node" ]; then
        echo -e "      使用平台目录 ${BLUE}$PLATFORM_DIR${NC} 中的 node"
        cp "$PLATFORM_DIR/node" "$TEMP_DIR/"
    elif [ -f "$PYTHON_DRIVER_DIR/node" ]; then
        echo -e "      ${YELLOW}警告: 未找到 $ZIP_NAME 平台的 node，使用本地 node（可能导致跨平台问题）${NC}"
        cp "$PYTHON_DRIVER_DIR/node" "$TEMP_DIR/"
    else
        echo -e "      ${RED}错误: 未找到 node 可执行文件！${NC}"
        echo -e "      请确保 driver/$ZIP_NAME/node 存在"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # 创建 zip 文件
    rm -f "$ZIP_FILE" 2>/dev/null || true
    (cd "$TEMP_DIR" && zip -rq "$PYTHON_PW_ROOT/$ZIP_FILE" . -x "*.DS_Store" -x "*__pycache__*")
    
    # 清理临时目录
    rm -rf "$TEMP_DIR"
    
    echo -e "      ${GREEN}✓ 已创建: $ZIP_FILE${NC}"
}

# 根据目标平台创建 zip
case "$TARGET_PLATFORM" in
    mac-arm64)
        create_driver_zip "mac-arm64"
        ;;
    mac)
        create_driver_zip "mac"
        ;;
    linux)
        create_driver_zip "linux"
        ;;
    linux-arm64)
        create_driver_zip "linux-arm64"
        ;;
    all)
        create_driver_zip "mac-arm64"
        create_driver_zip "linux"
        ;;
    *)
        echo -e "${RED}错误: 不支持的平台: $TARGET_PLATFORM${NC}"
        echo -e "支持的平台: mac-arm64, mac, linux, linux-arm64, all"
        exit 1
        ;;
esac

# ========== 步骤 3: 安装构建依赖 ==========
echo -e "${YELLOW}[3/4] 安装构建依赖...${NC}"
pip3 install build wheel setuptools setuptools-scm auditwheel -q 2>/dev/null || true
echo -e "      ${GREEN}✓ 依赖安装完成${NC}"

# ========== 步骤 4: 构建 wheel ==========
echo -e "${YELLOW}[4/4] 构建 wheel 包...${NC}"

# 函数：构建指定平台的 wheel
build_wheel_for_platform() {
    local PLATFORM_NAME=$1
    local WHEEL_TAG=$2
    
    echo ""
    echo -e "      ${BLUE}>>> 构建 $PLATFORM_NAME wheel...${NC}"
    
    # 使用环境变量指定目标 wheel
    PLAYWRIGHT_TARGET_WHEEL="$WHEEL_TAG" python3 -m build --wheel 2>&1 | grep -E "(Building|Successfully|Created)" || true
    
    # 清理中间产物
    rm -rf build/ *.egg-info 2>/dev/null || true
    
    echo -e "      ${GREEN}✓ $PLATFORM_NAME wheel 构建完成${NC}"
}

# 根据目标平台构建
case "$TARGET_PLATFORM" in
    mac-arm64)
        build_wheel_for_platform "macOS ARM64" "macosx_11_0_arm64.whl"
        ;;
    mac)
        build_wheel_for_platform "macOS x86_64" "macosx_10_13_x86_64.whl"
        ;;
    linux)
        build_wheel_for_platform "Linux x86_64" "manylinux1_x86_64.whl"
        ;;
    linux-arm64)
        build_wheel_for_platform "Linux ARM64" "manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        ;;
    all)
        build_wheel_for_platform "macOS ARM64" "macosx_11_0_arm64.whl"
        build_wheel_for_platform "Linux x86_64" "manylinux1_x86_64.whl"
        ;;
esac

# ========== 验证 wheel 包含修改 ==========
echo ""
echo -e "${YELLOW}[验证] 检查 wheel 是否包含自定义修改...${NC}"

WHEEL_FILE=$(ls -1 dist/*.whl 2>/dev/null | head -1)
if [ -n "$WHEEL_FILE" ]; then
    # 解压 wheel 检查是否包含修改
    VERIFY_DIR=$(mktemp -d)
    unzip -q "$WHEEL_FILE" -d "$VERIFY_DIR"
    
    if grep -q "CUSTOM_DEV_TEST" "$VERIFY_DIR/playwright/driver/package/lib/server/frames.js" 2>/dev/null; then
        echo -e "      ${GREEN}✓ 验证通过！wheel 包含自定义修改${NC}"
    else
        echo -e "      ${RED}✗ 警告：wheel 可能不包含自定义修改${NC}"
        echo -e "      ${YELLOW}请检查 JS Playwright 是否已正确构建${NC}"
    fi
    
    rm -rf "$VERIFY_DIR"
fi

# ========== 显示结果 ==========
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    构建成功！                               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}生成的 Wheel 文件:${NC}"
echo ""

for whl in dist/*.whl; do
    if [ -f "$whl" ]; then
        WHEEL_SIZE=$(du -h "$whl" | cut -f1)
        echo -e "  ${BLUE}$whl${NC}"
        echo -e "  大小: $WHEEL_SIZE"
        echo ""
    fi
done

echo -e "${YELLOW}安装命令:${NC}"
echo ""
echo -e "  # macOS ARM64:"
echo -e "  ${GREEN}pip3 install dist/playwright-*-macosx_11_0_arm64.whl${NC}"
echo ""
echo -e "  # Linux x86_64:"
echo -e "  ${GREEN}pip3 install dist/playwright-*-manylinux1_x86_64.whl${NC}"
echo ""
echo -e "${YELLOW}安装后首次使用需要安装浏览器:${NC}"
echo -e "  ${GREEN}playwright install chromium${NC}"
echo ""
echo -e "${YELLOW}验证安装（应该看到 [CUSTOM_DEV_TEST] 日志）:${NC}"
echo -e "  ${GREEN}DEBUG=pw:api python3 -c \"from playwright.sync_api import sync_playwright; p=sync_playwright().start(); b=p.chromium.launch(); page=b.new_page(); page.goto('https://baidu.com'); print(page.url); b.close(); p.stop()\"${NC}"

# ========== 恢复本地开发 driver ==========
echo ""
echo -e "${YELLOW}[后处理] 恢复本地开发 driver...${NC}"

# 同步 JS driver 到 Python（供本地开发使用）
if [ -d "$PYTHON_DRIVER_PACKAGE/lib" ]; then
    rm -rf "$PYTHON_DRIVER_PACKAGE/lib"
fi
cp -r "$JS_LIB_DIR" "$PYTHON_DRIVER_PACKAGE/lib"
cp "$JS_CORE_DIR/browsers.json" "$PYTHON_DRIVER_PACKAGE/browsers.json"

echo -e "      ${GREEN}✓ 本地 driver 已恢复，可以继续开发测试${NC}"
