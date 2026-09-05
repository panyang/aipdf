# 参与开发

欢迎提交问题与改进。请先阅读 [README](README.md)、[功能对照](docs/功能对照.md) 和 [安全说明](SECURITY.md)。

1. 安装 Xcode Command Line Tools 和 Python 3.12+，运行 `zsh scripts/build.sh`。
2. 保持修改范围集中，说明原来的问题及改进后的行为。
3. 修改 PDF 逻辑后运行 `.venv/bin/python tests/test_engine.py`；Swift 修改需完成编译。仅修改文档无需运行全套转换。
   修改安装逻辑还需运行 `.venv/bin/python tests/test_installer.py`，并验证源码安装版不依赖下载目录。
4. 工具定义变更要重新生成 `backend/catalog.json`；依赖变更要更新锁定版本、第三方许可快照及说明。
5. 提交说明中列出实际验证结果和限制；仅使用合成测试样例。

贡献的原创部分应按本项目 `AGPL-3.0-only` 许可提供。请确认有权提交相关内容；引用或引入第三方代码时，保留原版权和许可，说明来源及兼容性。提交补丁不代表转让你的版权。

使用 AI 工具协作时请遵循 [AGENTS.md](AGENTS.md)。它不能代替人工审查、自动测试或安全机制。
