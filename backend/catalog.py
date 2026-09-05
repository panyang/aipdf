"""The UI and engine share this capability catalogue and option defaults."""
import json
from pathlib import Path


def field(key, label, value="", kind="text", choices=None, help=""):
    return dict(key=key, label=label, value=str(value), kind=kind, choices=choices or [], help=help)


PAGES = field("pages", "页面范围", "", help="留空为全部；例如 1-3,5。排列页面时按输入顺序处理。")
DPI = field("dpi", "分辨率", "144", "choice", ["72", "144", "216", "300"])
RECT = [field("x", "左边距（点）", 48, "number"), field("y", "上边距（点）", 72, "number"), field("width", "宽度（点）", 240, "number"), field("height", "高度（点）", 64, "number")]
SIZE = field("fontsize", "字号", 18, "number")
POSITION = field("position", "位置", "bottom-center", "choice", ["top-left", "top-center", "top-right", "center", "bottom-left", "bottom-center", "bottom-right"])
TOOLS = []


def tool(id, name, subtitle, category, icon, fields=None, extensions="pdf", multiple=True, note="", dependency=""):
    TOOLS.append(dict(id=id, name=name, subtitle=subtitle, category=category, icon=icon,
                      fields=fields or [], extensions=extensions.split(","), multiple=multiple, note=note, dependency=dependency))


tool("merge", "合并 PDF", "把多份文件，整理成一份", "整理页面", "square.stack.3d.up", note="按文件列表顺序合并，可用箭头调整顺序。")
tool("split", "拆分 PDF", "按范围拆分，或一页一份", "整理页面", "scissors", [field("ranges", "拆分范围", "", help="留空逐页拆分；用分号分组，例如 1-3;4-6;7")])
tool("remove", "删除页面", "去掉不再需要的页面", "整理页面", "minus.square", [PAGES], note="必须填写要删除的页码，原文件保持不变。")
tool("extract", "提取页面", "只保留需要的内容", "整理页面", "doc.on.doc", [PAGES])
tool("organize", "排列页面", "调整顺序、重复或挑选页面", "整理页面", "square.grid.2x2", [PAGES], multiple=False, note="可在页面缩略图中调整顺序，或输入 3,1,2。")
tool("scan", "扫描为 PDF", "照片纠偏、增强，整理成文档", "整理页面", "viewfinder", [field("scanMode", "扫描效果", "document", "choice", ["document", "gray", "original"]), field("perspective", "自动识别纸张边缘", "true", "toggle")], extensions="jpg,jpeg,png,tif,tiff,heic,bmp", dependency="vision", note="导入相机或 iPhone 扫描的图片；自动纠正检测到的纸张透视。")
tool("compress", "压缩 PDF", "减小体积，方便保存和分享", "优化文件", "arrow.down.right.and.arrow.up.left", [field("quality", "压缩方式", "balanced", "choice", ["lossless", "balanced", "small"] )], note="无损模式保留内容；均衡和小文件模式降低图片分辨率，保留文字。已优化文件可能不会继续变小。")
tool("repair", "修复 PDF", "重建可以恢复的文档结构", "优化文件", "wrench.and.screwdriver", note="尝试恢复可读取的内容。缺失或被覆盖的原始数据无法重建。")
tool("ocr", "OCR 文字识别", "让扫描文档可搜索、可复制", "优化文件", "text.viewfinder", [PAGES, field("force", "同时识别已有文字的页面", "false", "toggle")], dependency="vision", note="使用 Apple Vision 在本机识别中文和英文，保留原页外观。")
tool("images_to_pdf", "图片转 PDF", "把 JPG、PNG 等图片装订成册", "格式转换", "photo.on.rectangle", [field("pageSize", "页面尺寸", "A4", "choice", ["A4", "Letter", "image"]), field("orientation", "方向", "portrait", "choice", ["portrait", "landscape"]), field("margin", "页边距（点）", 24, "number")], extensions="jpg,jpeg,png,tif,tiff,heic,bmp")
tool("pdf_to_images", "PDF 转图片", "逐页导出，或提取原始图片", "格式转换", "photo.stack", [PAGES, field("mode", "导出内容", "pages", "choice", ["pages", "embedded"]), field("format", "图片格式", "jpg", "choice", ["jpg", "png"]), DPI])
tool("word_to_pdf", "Word 转 PDF", "让文档在任何设备上保持一致", "格式转换", "doc.text", extensions="doc,docx,odt,rtf", dependency="office")
tool("ppt_to_pdf", "PowerPoint 转 PDF", "把演示文稿转换为 PDF", "格式转换", "rectangle.on.rectangle", extensions="ppt,pptx,odp", dependency="office")
tool("excel_to_pdf", "Excel 转 PDF", "把工作表转换为易读的文档", "格式转换", "tablecells", extensions="xls,xlsx,ods,csv", dependency="office", note="遵循源工作簿的打印区域、缩放及分页设置。")
tool("pdf_to_word", "PDF 转 Word", "提取可编辑的文字、表格和图片", "格式转换", "doc.text.below.ecg", [field("mode", "转换方式", "editable", "choice", ["editable", "visual"])], note="可编辑模式重新排版文字与表格；外观模式按页嵌入图片。复杂版式不保证原样还原，扫描件先运行 OCR。")
tool("pdf_to_ppt", "PDF 转 PowerPoint", "每一页都可以成为一张幻灯片", "格式转换", "play.rectangle", [field("mode", "转换方式", "visual", "choice", ["visual", "editable"])], note="外观模式保留页面图像；可编辑模式重建文本框并保留页面图片，复杂图形可能不完整。")
tool("pdf_to_excel", "PDF 转 Excel", "把表格数据带入电子表格", "格式转换", "tablecells.badge.ellipsis", note="按检测到的表格分别建表；没有表格时导出逐行文本。扫描件先运行 OCR。")
tool("html_to_pdf", "HTML 转 PDF", "将本地 HTML 或网页保存为 PDF", "格式转换", "chevron.left.forwardslash.chevron.right", [field("url", "网页地址（可选）", "", help="填写网址后优先转换网页，无需添加文件。")], extensions="html,htm", note="本地 HTML 支持基础 CSS；填写网址时使用系统 WebKit 联网加载网页（含页面脚本与资源），不上传本地文件。长网页按 A4 分页，可能切开跨页元素。")
tool("pdfa", "PDF 转 PDF/A", "生成适合长期保存的文档", "格式转换", "archivebox", [field("pdfaLevel", "归档格式", "2b", "choice", ["1b", "2b", "3b"])], dependency="office", note="经 LibreOffice Draw 导出 PDF/A，版式可能变化。正式归档前应使用 veraPDF 独立验证。")
tool("rotate", "旋转 PDF", "轻松纠正页面方向", "编辑内容", "rotate.right", [PAGES, field("angle", "顺时针旋转", "90", "choice", ["90", "180", "270"])])
tool("numbers", "添加页码", "为长文档加上清晰的页码", "编辑内容", "number.square", [PAGES, field("format", "页码格式", "{n} / {total}"), field("start", "起始编号", 1, "number"), POSITION, field("fontsize", "字号", 11, "number")])
tool("watermark", "添加水印", "用文字或图片标记文档", "编辑内容", "drop", [PAGES, field("text", "水印文字", "内部资料"), field("image", "图片水印（可选）", "", "file"), POSITION, field("opacity", "不透明度（0—1）", "0.2", "number"), field("fontsize", "字号", 42, "number")])
tool("crop", "裁剪 PDF", "保留页面中最重要的区域", "编辑内容", "crop", [PAGES] + RECT, note="在预览页中拖出裁剪框，或输入从左上角起的坐标；1 点 = 1/72 英寸。")
tool("edit", "编辑 PDF", "添加文字、图片、形状和标注", "编辑内容", "pencil.tip.crop.circle", [PAGES, field("mode", "编辑方式", "text", "choice", ["text", "image", "rectangle", "highlight", "ink"]), field("text", "文字内容", "", "textarea"), field("image", "图片文件", "", "file"), SIZE, field("color", "颜色", "#3159D9")] + RECT, note="在预览中框选位置。每次导出后可继续编辑结果。文字覆盖添加，不修改原始文字段落。")
tool("forms", "PDF 表单", "创建交互字段、读取和填写表单", "编辑内容", "checklist", [field("formMode", "操作", "fill", "choice", ["fill", "create"]), field("fieldName", "新字段名称", "name"), field("fieldType", "字段类型", "text", "choice", ["text", "checkbox", "list", "radio"]), field("fieldValue", "新字段默认值", ""), field("choices", "选项（每行一个）", "选项一\n选项二", "textarea")] + RECT, multiple=False, note="导入文件后自动读取字段。填写保留交互性；新建模式在框选位置创建字段。")
tool("unlock", "PDF 解锁", "使用已知密码移除文档保护", "安全保护", "lock.open", note="在下方输入原文件密码。不尝试破解未知密码。")
tool("protect", "PDF 加密", "为重要文件设置打开密码", "安全保护", "lock.shield", [field("newPassword", "新密码", "", "secret"), field("allowPrint", "允许打印", "true", "toggle"), field("allowCopy", "允许复制", "false", "toggle")], note="使用 AES-256 加密。部分阅读器可能忽略打印、复制权限。")
tool("sign", "PDF 签名", "手写、输入姓名或放置签名图片", "安全保护", "signature", [PAGES, field("text", "签名姓名（可选）", ""), field("image", "签名图片（可选）", "", "file")] + RECT, note="在签名板上书写，然后在预览中框选位置。属于可视签名，不是证书数字签名或远程签署服务。")
tool("redact", "永久遮盖", "从导出文件中移除敏感内容", "安全保护", "rectangle.fill", [PAGES, field("text", "匹配文字（可选，每行一项）", "", "textarea")] + RECT, note="按关键词或框选区域删除文字、图片和图形；导出时清理元数据、附件、批注和表单。请复核结果。")
tool("compare", "比较 PDF", "并排看版本，突出视觉和文字差异", "安全保护", "square.split.2x1", note="选择两份 PDF，导出逐页视觉对比 PDF 和文字差异 HTML。按页序比较，不自动对齐插入页。")
tool("markdown", "PDF 转 Markdown", "把文档转换为可复用的笔记", "格式转换", "text.alignleft", [PAGES], note="提取文字、标题、链接、表格和图片；复杂阅读顺序可能需要整理。")
tool("workflow", "工作流程", "保存常用步骤，一次完成处理", "工作流程", "arrow.triangle.branch", multiple=True, note="把多个 PDF 操作按顺序串联，并保存为本机预设；每一步均保留输出副本。")

BY_ID = {t["id"]: t for t in TOOLS}

if __name__ == "__main__":
    Path(__file__).with_name("catalog.json").write_text(json.dumps(TOOLS, ensure_ascii=False, indent=2))
