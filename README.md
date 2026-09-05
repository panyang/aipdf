# AIPDF · 本地 PDF 工作台

参照 iLovePDF 的工具分类与操作需求构建的中文原生 Mac 应用。SwiftUI 界面、PDFKit 预览、PyMuPDF 处理引擎、Apple Vision OCR 与 LibreOffice 格式转换。

**这是可运行的本地初版，覆盖 32 个工具入口；不是网站全部能力的 1:1 等价替代。** 完整范围和差距见 [功能对照](docs/功能对照.md)。

## 在这台 Mac 上打开

双击 `dist/AIPDF.app`。当前为本机签名构建，依赖此项目中的 `.venv`，请保留项目目录。无需启动终端服务，不需要账号。

1. 选择工具，将文件拖入窗口或点击“添加文件”。
2. 调整右侧参数；编辑、签名、裁剪和遮盖可直接在 PDF 预览中框选位置。
3. 选择输出文件夹并开始处理。每次生成新的 `AIPDF-日期-编号` 目录，不覆盖源文件。
4. 从结果栏打开文件、在 Finder 定位，或继续处理刚生成的文件。

快捷键：`⌘O` 添加文件，工具箱中 `⌘F` 搜索，`⌘,` 打开设置。

## 工具范围

- 页面整理：合并、拆分、删除、提取、排序、扫描图片。
- 优化：无损/图片压缩、修复结构、中文与英文 OCR。
- 转换：图片、Word、PowerPoint、Excel、HTML/网址、PDF/A、Markdown。
- 编辑：旋转、页码、文字/图片水印、裁剪、文字/图片/形状/手绘、交互表单。
- 安全：已知密码解锁、AES-256 加密、可视签名、永久遮盖、版本比较。
- 流程：可保存多步骤预设、批量执行、查看本机处理记录。

按用户要求，不提供 AI 摘要与翻译，不连接本地模型服务，也不下载模型。Markdown 导出保留在“格式转换”分类。

## 构建与依赖

要求 macOS 14+、Xcode Command Line Tools、Python 3.12+。当前已在 Apple Silicon / macOS 15.7.4 验证。

```sh
zsh scripts/build.sh
```

构建脚本会创建 `.venv`、安装 `requirements.lock.txt` 中的锁定版本、编译 Swift 程序、生成并本机签名 `.app`。`requirements.txt` 描述直接依赖的约束范围。打包前会核对第三方许可快照，应用内附带许可与构建源码信息。

许可快照来自当前已验证的 Apple Silicon 环境。不同平台或更换依赖版本后，如果核对失败，运行 `.venv/bin/python scripts/collect_licenses.py`，复核 `licenses/third-party/` 的变化后再构建。

Office / PDF/A 使用 `/Applications/LibreOffice.app`，或本机现有的 Codex LibreOffice 运行环境。也可以通过 `AIPDF_OFFICE` 指定 `soffice` 可执行路径。运行时不会自动安装组件。


网址转 PDF 使用独立、无持久 Cookie 的 WebKit 会话，会联网获取输入网址的页面、脚本和资源。本地文件操作不上传文档。网络页面的跨页排版可能需要检查。

## 验证

```sh
.venv/bin/python tests/test_engine.py
```

测试自行生成示例文件，不读取个人文件，覆盖页面顺序、范围错误、裁剪旋转、文本/图像导出、中文、交互表单字段树、加密解锁、内容永久遮盖、Office 双向转换、PDF/A 标识、工作流程、子进程通信、取消、扫描/OCR 与网页渲染。

Vision、WebKit 及 LibreOffice 需要正常的本机图形/系统服务访问；受限沙箱可能禁止相关服务。

## 重要边界

- `.app` 当前依赖原项目路径和 Python 环境，不能仅复制 `.app` 就在另一台电脑运行。尚未制作自包含安装包或进行 Apple 公证。
- PDF 转 Word/PPT 可选择“保留外观”或“可编辑内容”；复杂版式无法保证复原。
- 签名是手写/图片可视签名，不是证书数字签名，也没有邀请他人签署、身份认证和签署审计。
- PDF/A 检查导出标识，但还未接入 veraPDF 的完整合规校验。
- 裁剪仅改变可视区域。移除敏感内容应使用“永久遮盖”，并检查所有相关页面的结果。
- 没有云端账户、付费系统、手机二维码传输及外部存储集成。

## 开源许可与分发

Copyright (C) 2026 AIPDF contributors。

项目自有代码、文档及原创图标按 **GNU Affero General Public License v3.0 only（AGPL-3.0-only）** 提供。你可以按该许可使用、修改和分发，包括商业用途；分发及相应网络服务场景的源码义务以 [LICENSE](LICENSE) 全文为准。项目按原样提供，在法律允许范围内不提供适销性、特定用途等担保。授权范围见 [NOTICE](NOTICE)。

PyMuPDF/MuPDF 等第三方组件保留自己的许可与版权，详见 [第三方声明](THIRD_PARTY_NOTICES.md)。AIPDF 是独立项目，与 iLovePDF 或依赖厂商没有隶属、赞助或背书关系。

目前建议分享源码和自行构建步骤。发布二进制前阅读 [分发说明](docs/分发说明.md)，处理本机路径、依赖打包、对应源码、签名/公证与旧提交邮箱。仅添加许可证不能消除这些风险。

参与开发见 [CONTRIBUTING.md](CONTRIBUTING.md)，AI 协作约定见 [AGENTS.md](AGENTS.md)，安全问题见 [SECURITY.md](SECURITY.md)。`AGENTS.md` 是可选协作指引，不是开源或使用应用的前置条件。

## 目录

`Sources/AIPDF` 原生应用；`Sources/VisionHelper` OCR/扫描；`Sources/WebHelper` 网页渲染；`backend` 工具目录与处理引擎；`tests` 自动验证；`scripts` 构建打包与视觉验证；`docs` 研究及范围。
