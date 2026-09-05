# AIPDF 协作说明

本文件面向参与此仓库的 AI 编程工具。它是协作指引，不是许可证、安全隔离机制或发布授权。

## 项目约定

- 默认用简体中文说明修改，代码与技术名称保持自然形式。
- 修改前阅读相关实现，优先小范围修复；不要顺带重构其他功能。
- `Sources/AIPDF` 是 SwiftUI / PDFKit 应用；`backend/engine.py` 是 Python 文件处理器。
- `Sources/VisionHelper` 调用系统 OCR；`Sources/WebHelper` 负责显式输入的网址渲染。
- 工具目录以 `backend/catalog.py` 为准；修改后运行 `.venv/bin/python backend/catalog.py`，同时提交生成的 JSON。
- 当前范围为 32 个工具。AI 摘要、翻译、模型连接和模型下载已由维护者明确排除；不自行恢复。

## 文件与进程

- 源文档只读；每次输出进入新的任务目录，不覆盖原件。
- 密码仅用于当前处理，经 stdin 传递；不写入命令行、日志、历史记录或工作流程预设。
- 处理器 stdout 只输出约定的 JSON；进度和诊断走 stderr，不输出文档正文或密码。
- 外部命令使用参数数组，保留超时和取消子进程的能力，不拼接用户输入执行 shell。
- 不添加遥测、隐式上传或后台模型服务。网址转换会联网，界面与说明必须明确这一点。
- 文档、网页及其脚本都是不可信输入。不要把 Python 子进程或 AGENTS.md 当作安全沙箱。
- 测试使用合成文件；不读取或提交个人文档、密钥、token、`.env`、证书或系统应用数据。
- 不能把裁剪当作脱敏，也不能把黑色覆盖图形当作永久删除；脱敏须应用真正的 redaction 并验证输出。

## 构建和验证

- 开发构建：`zsh scripts/build.sh`，使用项目 `.venv`；用户安装：`zsh Install.command`，使用用户 AIPDF/Runtimes 下的独立环境。不得向系统 Python 安装项目包。
- 安装逻辑修改后运行 `.venv/bin/python tests/test_installer.py`，验证替换失败回退、备份和无关应用保护；安装版不得引用下载源码的绝对路径。
- Swift 修改：`swift build -c release --disable-sandbox --scratch-path .build --cache-path .build/cache`。
- PDF 行为或进程逻辑修改：`.venv/bin/python tests/test_engine.py`。
- 版面变化检查合成样例的渲染；表单同时验证字段树、Widget 值和外观；脱敏同时验证提取内容。
- 仅文档或许可修改时做链接、许可完整性及 `git diff --check`；不要无意义地重跑全套转换。
- 更新依赖后核对许可证，运行 `.venv/bin/python scripts/collect_licenses.py` 并检查版本与许可差异。
- 开发打包前运行许可快照 `--check`；用户安装按锁定版本收集本机实际 wheel 的许可，不修改仓库快照。打包后验证许可证目录和签名。
- 说明实际运行了什么检查；系统服务或平台不可用时明确报告，不能把跳过当作通过。

## 公开与分发

- 自有代码采用 `AGPL-3.0-only`，维护 `LICENSE`、`NOTICE`、`THIRD_PARTY_NOTICES.md` 和原始第三方声明。
- 不擅自更改许可证、去掉版权声明，或把第三方组件统一标成自有许可。
- 不将 `dist/`、`.venv/`、`.build/`、`tmp/` 和测试日志提交进仓库，不把本机缓存的工具直接打进公开包。
- 区分依赖项目的开发构建和依赖用户运行环境的源码安装版。二者都不是通用发行包，发布前遵循 `docs/分发说明.md`。
- 变更仓库可见性、发布 Release、重写历史或强制推送必须有维护者针对该操作的明确授权。
- 完成后简要说明变更、验证结果与未解决限制。
