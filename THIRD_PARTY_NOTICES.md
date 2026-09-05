# 第三方组件与许可

项目自有内容按 [NOTICE](NOTICE) 中的授权使用；下列组件保留各自的版权和许可，不能统一改标为 AIPDF 的许可。清单针对 `requirements.lock.txt` 中当前已验证的 Python 环境。

## Python 依赖

| 组件 | 版本 | 声明的主要许可 / 注意事项 |
| --- | --- | --- |
| PyMuPDF / MuPDF | PyMuPDF 1.28.2 | AGPLv3 或 Artifex 商业许可；本项目采用开源路线。安装包的 COPYING 是简短双许可声明，AGPLv3 全文另见根目录 LICENSE。 |
| python-docx | 1.2.0 | MIT |
| python-pptx | 1.0.2 | MIT |
| openpyxl | 3.1.5 | MIT |
| Pillow | 12.3.0 | MIT-CMU；其 LICENSE 还列出随 wheel 提供的图像/字体等原生组件声明，须一并保留。 |
| pypdf | 6.17.0 | BSD-3-Clause |
| pdfplumber | 0.11.10 | MIT |
| pdfminer.six | 20260107 | MIT |
| pypdfium2 | 5.13.0 | 包元数据列 BSD-3-Clause、Apache-2.0 与依赖许可；随附 PDFium 及原生依赖材料、文档 CC-BY-4.0 文本，适用范围按各文件。 |
| cryptography | 50.0.1 | Apache-2.0 OR BSD-3-Clause；嵌入的 OpenSSL/Rust 依赖在二进制分发时另行核查。 |
| cffi | 2.1.1 | MIT-0；原生依赖按对应发行材料核查。 |
| charset-normalizer | 3.5.1 | MIT |
| et_xmlfile | 2.0.0 | MIT；保留其 LICENCE.python 和作者声明。 |
| lxml | 6.1.3 | BSD-3-Clause 为主；LICENSES.txt 指向其他来源及例外，嵌入 libxml2/libxslt 等组件另行核查。 |
| pycparser | 3.0 | BSD-3-Clause |
| typing_extensions | 4.16.0 | PSF-2.0 |
| XlsxWriter | 3.2.9 | BSD-2-Clause |

原文位于 [licenses/third-party](licenses/third-party/)，版本、来源 URL、原始路径及 SHA-256 位于 [manifest.json](licenses/third-party/manifest.json)。文件直接复制自已安装发行包，未删除其作者姓名、版权说明或上游联系方式。这些公开许可中的联系方式不是本项目维护者的私人数据。

生成与核对命令：

```sh
.venv/bin/python scripts/collect_licenses.py
.venv/bin/python scripts/collect_licenses.py --check
```

脚本不联网、不下载软件。它要求环境与锁文件版本一致。不同平台的 wheel 可能携带不同许可材料；更新版本或平台后应重新生成、审查快照及本表。不能仅凭包元数据里的一个 SPDX 名称认定所有嵌入组件均已审查完毕。

## 外部程序与系统组件

- **LibreOffice**：按其官网及实际安装包的许可使用，主要为 MPL-2.0，同时包含其他许可证下的组件。当前调用用户本机安装，不在 `.app` 中复制 LibreOffice。若以后捆绑发行，需要实际版本的完整许可材料及其要求的源码提供方式。[官方说明](https://www.libreoffice.org/licenses/)
- **Python**：由用户安装并建立 `.venv`，目前未捆绑独立 Python 运行时。将来打包解释器时应保留该发行版的 Python/PSF 及第三方原文。
- **Apple 系统框架、Swift 运行库和 SF Symbols**：通过系统/工具链使用，适用 Apple 及对应运行库的条款，不由本仓库重新许可；没有把系统字体、SDK 或 SF Symbols 字体文件复制进仓库。
- **Poppler**：只在手工视觉复核中作为外部工具调用，未打入应用；若将来捆绑必须单独复核实际版本的许可和源码义务。
- **本机开发辅助环境**：发现已有转换程序的位置不等于取得其再分发权。不得把 Codex 缓存、账户配置或整套依赖目录作为本项目源码附件发布。

## 说明与来源

当前 `.app` 只携带本项目可执行文件、处理代码和许可材料。开发构建的 Python 依赖在项目 `.venv` 中；`Install.command` 安装版的依赖在当前用户的 AIPDF/Runtimes 中，安装版收集实际安装的 wheel 的许可，不改写仓库快照。随附许可材料用于保留归属并方便核查，不表示 `.app` 已经打包这些二进制，也不是完整的软件物料清单或法律合规认证。

iLovePDF 仅作为需求研究参照；AIPDF 不包含其网站源代码、商标图标或认证材料，也没有得到其背书。[PyMuPDF 官方许可说明](https://pymupdf.readthedocs.io/en/latest/about.html#license-and-copyright)列明了 AGPL 与商业许可两种选择。
