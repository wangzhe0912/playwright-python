#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
测试 aria_snapshot 视口位置标记功能。

该功能在 mode='ai' 时会为元素添加视口位置标记：
- [visible] - 元素在当前浏览器视口内（至少部分可见）
- [offscreen:above] - 元素完全在视口上方
- [offscreen:below] - 元素完全在视口下方
- [offscreen:left] - 元素完全在视口左侧
- [offscreen:right] - 元素完全在视口右侧
- [offscreen:above-left] 等 - 元素在视口的对角方向
"""

import pytest
from playwright.sync_api import Page


# 测试页面 HTML
TEST_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>视口位置测试页面</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            height: 3000px;
        }
        .visible-section {
            background: lightgreen;
            padding: 20px;
            margin-bottom: 20px;
        }
        .offscreen-section {
            position: absolute;
            top: 2000px;
            background: lightcoral;
            padding: 20px;
        }
    </style>
</head>
<body>
    <h1>视口位置测试页面</h1>
    
    <div class="visible-section">
        <button id="btn-visible-1">可见按钮1</button>
        <div>
            <button id="btn-visible-2">可见按钮2</button>
            <a href="/link1" id="link-visible">可见链接</a>
        </div>
    </div>
    
    <button id="btn-offscreen" style="position:absolute; top:1500px;">视口下方按钮</button>
    
    <div class="offscreen-section">
        <button id="btn-far-offscreen">更远的按钮</button>
        <a href="/link2" id="link-offscreen">视口下方链接</a>
    </div>
</body>
</html>
"""


class TestViewportPositionMarker:
    """测试视口位置标记功能"""

    def test_ai_mode_includes_visible_marker(self, page: Page) -> None:
        """测试 AI 模式包含 [visible] 标记"""
        page.set_content(TEST_HTML)
        
        # 使用 mode='ai' 获取 aria snapshot
        snapshot = page.locator("body").aria_snapshot(mode="ai")
        
        # 验证包含 [visible] 标记
        assert "[visible]" in snapshot, f"快照应包含 [visible] 标记，实际输出:\n{snapshot}"
        
        # 验证可见按钮1有 [visible] 标记
        assert 'button "可见按钮1"' in snapshot
        # 按钮应该有 ref 和 visible 标记
        lines = snapshot.split("\n")
        btn1_line = [l for l in lines if '可见按钮1' in l][0]
        assert "[visible]" in btn1_line, f"可见按钮1 应该有 [visible] 标记: {btn1_line}"

    def test_ai_mode_includes_offscreen_marker(self, page: Page) -> None:
        """测试 AI 模式包含 [offscreen:xxx] 标记"""
        page.set_content(TEST_HTML)
        
        # 使用 mode='ai' 获取 aria snapshot
        snapshot = page.locator("body").aria_snapshot(mode="ai")
        
        # 验证包含 [offscreen:below] 标记（视口下方的元素）
        assert "[offscreen:below]" in snapshot, f"快照应包含 [offscreen:below] 标记，实际输出:\n{snapshot}"
        
        # 验证视口下方按钮有 [offscreen:below] 标记
        lines = snapshot.split("\n")
        btn_offscreen_line = [l for l in lines if '视口下方按钮' in l][0]
        assert "[offscreen:below]" in btn_offscreen_line, \
            f"视口下方按钮应该有 [offscreen:below] 标记: {btn_offscreen_line}"

    def test_scroll_changes_visibility_markers(self, page: Page) -> None:
        """测试滚动后视口位置标记会改变"""
        page.set_content(TEST_HTML)
        
        # 初始状态
        snapshot1 = page.locator("body").aria_snapshot(mode="ai")
        
        # 验证初始状态：可见按钮在视口内，远处按钮在视口下方
        lines1 = snapshot1.split("\n")
        btn1_line = [l for l in lines1 if '可见按钮1' in l][0]
        btn_offscreen_line = [l for l in lines1 if '视口下方按钮' in l][0]
        
        assert "[visible]" in btn1_line, "初始状态: 可见按钮1 应该在视口内"
        assert "[offscreen:below]" in btn_offscreen_line, "初始状态: 视口下方按钮应该在视口下方"
        
        # 滚动到页面底部
        page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
        page.wait_for_timeout(100)  # 等待滚动完成
        
        # 滚动后状态
        snapshot2 = page.locator("body").aria_snapshot(mode="ai")
        
        # 验证滚动后：之前可见的元素可能在视口上方
        lines2 = snapshot2.split("\n")
        btn1_line_after = [l for l in lines2 if '可见按钮1' in l][0]
        
        # 滚动到底部后，之前可见的按钮应该在视口上方
        assert "[offscreen:above]" in btn1_line_after, \
            f"滚动后: 可见按钮1 应该在视口上方，实际: {btn1_line_after}"

    def test_expect_mode_no_visibility_markers(self, page: Page) -> None:
        """测试 expect 模式（默认模式）不包含视口位置标记"""
        page.set_content(TEST_HTML)
        
        # 使用默认模式（expect）获取 aria snapshot
        snapshot = page.locator("body").aria_snapshot()
        
        # 验证不包含视口位置标记
        assert "[visible]" not in snapshot, \
            f"expect 模式不应包含 [visible] 标记，实际输出:\n{snapshot}"
        assert "[offscreen:" not in snapshot, \
            f"expect 模式不应包含 [offscreen:xxx] 标记，实际输出:\n{snapshot}"

    def test_explicit_expect_mode_no_visibility_markers(self, page: Page) -> None:
        """测试显式指定 mode='expect' 不包含视口位置标记"""
        page.set_content(TEST_HTML)
        
        # 显式指定 mode='expect'
        snapshot = page.locator("body").aria_snapshot(mode="expect")
        
        # 验证不包含视口位置标记
        assert "[visible]" not in snapshot, \
            f"显式 expect 模式不应包含 [visible] 标记，实际输出:\n{snapshot}"
        assert "[offscreen:" not in snapshot, \
            f"显式 expect 模式不应包含 [offscreen:xxx] 标记，实际输出:\n{snapshot}"


class TestViewportPositionMarkerAsync:
    """测试异步 API 的视口位置标记功能"""

    @pytest.mark.asyncio
    async def test_async_ai_mode_includes_markers(self, page) -> None:
        """测试异步 API 的 AI 模式包含视口位置标记"""
        await page.set_content(TEST_HTML)
        
        # 使用 mode='ai' 获取 aria snapshot
        snapshot = await page.locator("body").aria_snapshot(mode="ai")
        
        # 验证包含视口位置标记
        assert "[visible]" in snapshot, f"快照应包含 [visible] 标记，实际输出:\n{snapshot}"
        assert "[offscreen:below]" in snapshot, f"快照应包含 [offscreen:below] 标记，实际输出:\n{snapshot}"


# 为 pytest 提供 fixture
@pytest.fixture(scope="function")
def page(browser):
    """创建一个新页面，设置固定视口大小"""
    context = browser.new_context(viewport={"width": 800, "height": 600})
    page = context.new_page()
    yield page
    context.close()

