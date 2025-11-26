#!/usr/bin/env python3
"""
测试用例：验证本地修改的 JS Playwright 是否在 Python 中生效

此测试用例会：
1. 启动 Chromium 浏览器
2. 访问百度页面
3. 验证 URL 和标题
4. 通过 DEBUG=pw:api 环境变量可以看到我们添加的自定义日志 [CUSTOM_DEV_TEST]

运行方式：
    DEBUG=pw:api pytest tests/test_custom_dev_modification.py -v -s
"""

import pytest
from playwright.sync_api import sync_playwright, Page, Browser


class TestCustomDevModification:
    """测试自定义修改是否在 Python Playwright 中生效"""

    @pytest.fixture(scope="class")
    def browser(self):
        """创建浏览器实例"""
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            yield browser
            browser.close()

    @pytest.fixture
    def page(self, browser: Browser):
        """创建页面实例"""
        context = browser.new_context()
        page = context.new_page()
        yield page
        context.close()

    def test_goto_baidu_and_verify_url(self, page: Page):
        """
        测试：访问百度页面并验证 URL
        
        如果设置了 DEBUG=pw:api 环境变量，会看到以下自定义日志：
        [CUSTOM_DEV_TEST] goto() 被调用，目标URL: https://www.baidu.com
        """
        # 访问百度首页 - 这里会触发我们修改的 goto() 方法
        page.goto("https://www.baidu.com")
        
        # 验证 URL 包含 baidu.com
        current_url = page.url
        assert "baidu.com" in current_url, f"URL 应该包含 'baidu.com'，实际为: {current_url}"
        
        print(f"\n✅ 验证通过！当前 URL: {current_url}")

    def test_goto_and_verify_title(self, page: Page):
        """
        测试：访问百度页面并验证标题
        """
        page.goto("https://www.baidu.com")
        
        # 获取页面标题
        title = page.title()
        
        # 验证标题包含 "百度"
        assert "百度" in title, f"标题应该包含 '百度'，实际为: {title}"
        
        print(f"\n✅ 验证通过！页面标题: {title}")

    def test_multiple_navigations(self, page: Page):
        """
        测试：多次导航，验证 goto 日志正常输出
        """
        urls = [
            "https://www.baidu.com",
            "https://www.baidu.com/s?wd=playwright",
        ]
        
        for url in urls:
            page.goto(url)
            assert page.url is not None
            print(f"\n✅ 成功导航到: {page.url}")


class TestLocalDriverIntegration:
    """测试本地 driver 集成是否正常"""

    def test_playwright_version_info(self):
        """
        测试：验证 Playwright 版本信息
        """
        from playwright._repo_version import version
        print(f"\n📌 Playwright Python 版本: {version}")
        assert version is not None

    def test_driver_path_exists(self):
        """
        测试：验证 driver 路径是否正确
        """
        from playwright._impl._driver import compute_driver_executable
        
        node_path, cli_path = compute_driver_executable()
        
        import os
        assert os.path.exists(node_path), f"Node.js 可执行文件不存在: {node_path}"
        assert os.path.exists(cli_path), f"CLI 入口文件不存在: {cli_path}"
        
        print(f"\n📌 Node.js 路径: {node_path}")
        print(f"📌 CLI 路径: {cli_path}")


if __name__ == "__main__":
    # 直接运行此文件时执行简单测试
    print("=" * 60)
    print("运行 Python Playwright 自定义修改验证测试")
    print("=" * 60)
    print()
    print("提示：使用 DEBUG=pw:api 环境变量查看详细日志")
    print("完整命令：DEBUG=pw:api pytest tests/test_custom_dev_modification.py -v -s")
    print()
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        
        print("[1] 测试导航到百度...")
        page.goto("https://www.baidu.com")
        print(f"    当前 URL: {page.url}")
        print(f"    页面标题: {page.title()}")
        
        assert "baidu.com" in page.url
        print("    ✅ URL 验证通过！")
        
        assert "百度" in page.title()
        print("    ✅ 标题验证通过！")
        
        browser.close()
    
    print()
    print("=" * 60)
    print("所有测试通过！如果看到 [CUSTOM_DEV_TEST] 日志，说明修改生效！")
    print("=" * 60)

