import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            Sidebar().frame(width: 216)
            Rectangle().fill(Color.black.opacity(0.055)).frame(width: 1)
            VStack(spacing: 0) {
                header
                Divider().opacity(0.5)
                if model.showHistory { HistoryView() }
                else if let tool = model.selected { ToolWorkspace(tool: tool) }
                else { ToolLibrary() }
            }
        }
        .background(Color.canvas)
        .foregroundStyle(Color.ink)
        .tint(.coral)
        .sheet(isPresented: $model.showSettings) { SettingsView() }
        .alert("请检查一下", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error=nil } })) {
            Button("知道了",role: .cancel) { model.error=nil }
        } message: { Text(model.error ?? "") }
    }
    private var header: some View {
        HStack(spacing: 12) {
            if model.selected != nil || model.showHistory {
                Button { model.selected=nil; model.showHistory=false } label: { Image(systemName: "arrow.left") }
                    .buttonStyle(.plain).disabled(model.busy)
            }
            Text(model.showHistory ? "最近处理" : model.selected?.category ?? "工具箱").font(.system(size: 13,weight: .medium))
            Spacer()
            Label("文件只在本机处理",systemImage: "lock.shield").font(.system(size: 11)).foregroundStyle(Color.muted)
            Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1,height: 14).padding(.horizontal, 8)
            Text("AIPDF / 本地版").font(.system(size: 11,weight: .medium)).foregroundStyle(Color.muted)
        }.padding(.horizontal, 30).frame(height: 64)
    }
}

struct Sidebar: View {
    @EnvironmentObject var model: AppModel
    let icons = ["全部工具":"square.grid.2x2", "整理页面":"square.stack", "优化文件":"slider.horizontal.3", "格式转换":"arrow.left.arrow.right", "编辑内容":"pencil.line", "安全保护":"lock.shield", "工作流程":"arrow.triangle.branch"]
    var body: some View {
        VStack(alignment: .leading,spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(Color.coral).frame(width: 38,height: 38)
                    Image(systemName: "doc.on.doc.fill").font(.system(size: 19)).foregroundStyle(.white)
                }
                VStack(alignment: .leading,spacing: 2) {
                    Text("AIPDF").font(.system(size: 22,weight: .bold,design: .rounded))
                    Text("你的本地 PDF 工作台").font(.system(size: 9)).foregroundStyle(Color.muted)
                }
            }.padding(.top, 47).padding(.bottom, 34).padding(.horizontal, 24)
            Text("工作空间").font(.system(size: 10,weight: .medium)).foregroundStyle(Color.muted).padding(.leading, 26).padding(.bottom, 12)
            ForEach(model.categories,id: \.self) { category in
                let active = !model.showHistory && model.category == category
                Button {
                    model.category=category; model.selected=nil; model.showHistory=false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: icons[category] ?? "folder").font(.system(size: 14)).frame(width: 18)
                        Text(category).font(.system(size: 12,weight: active ? .semibold : .regular))
                        Spacer()
                        if category == "全部工具" { Text("\(model.tools.count)").font(.system(size: 10,design: .monospaced)).opacity(0.6) }
                    }.padding(.horizontal, 14).frame(height: 40)
                        .background(active ? Color.coral.opacity(0.09) : .clear)
                        .foregroundStyle(active ? Color.coral : Color.ink.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 3).disabled(model.busy)
            }
            Divider().padding(.horizontal,24).padding(.vertical, 18)
            Button { model.showHistory=true; model.selected=nil } label: {
                Label("最近处理",systemImage: "clock.arrow.circlepath").font(.system(size: 12)).foregroundStyle(Color.ink.opacity(0.8))
            }.buttonStyle(.plain).padding(.leading,26).disabled(model.busy)
            Spacer()
            VStack(alignment: .leading,spacing: 10) {
                HStack(spacing: 6) { Circle().fill(Color(hex: "52987B")).frame(width: 6,height: 6); Text("本地优先，安心处理").font(.system(size: 11,weight: .medium)) }
                Text("无需上传文件\n无需账号，自由使用").font(.system(size: 10)).foregroundStyle(Color.muted).lineSpacing(4)
            }.padding(15).frame(maxWidth: .infinity,alignment: .leading).background(Color(hex: "F0F3F1")).clipShape(RoundedRectangle(cornerRadius: 10)).padding(16)
            Button { model.showSettings=true } label: { Label("设置与本地引擎",systemImage: "gearshape").font(.system(size: 11)).foregroundStyle(Color.muted) }
                .buttonStyle(.plain).padding(.leading,26).padding(.bottom,24)
        }.background(Color(hex: "FDFDFD"))
    }
}

struct ToolLibrary: View {
    @EnvironmentObject var model: AppModel
    @FocusState private var searchFocused: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 26) {
                VStack(alignment: .leading,spacing: 12) {
                    HStack(spacing: 7) {
                        Capsule().fill(Color.coral).frame(width: 18,height: 3)
                        Text("小工具，做好每一份文档").font(.system(size: 11,weight: .medium)).foregroundStyle(Color.muted)
                    }
                    Text("PDF 的事，在这里搞定。").font(.system(size: 31,weight: .semibold)).tracking(-0.7)
                    Text("合并、转换、编辑与更多。你的文件，始终留在你的 Mac。")
                        .font(.system(size: 12)).foregroundStyle(Color.muted)
                }.padding(.top, 10)
                HStack(spacing: 14) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.muted)
                        TextField("搜索工具，例如：压缩、转 Word、OCR",text: $model.search).textFieldStyle(.plain).font(.system(size: 12)).focused($searchFocused)
                        if !model.search.isEmpty { Button { model.search="" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(Color.muted) }
                        Text("⌘ F").font(.system(size: 10)).foregroundStyle(Color.muted).padding(4).background(Color.canvas).cornerRadius(4)
                    }.padding(14).background(.white).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06)))
                    HStack(spacing: 7) { Image(systemName: "checkmark.shield"); Text("离线工具箱") }.font(.system(size: 11)).foregroundStyle(Color(hex: "5F8774"))
                }
                if model.category == "全部工具" && model.search.isEmpty { featured }
                VStack(alignment: .leading,spacing: 16) {
                    HStack {
                        Text(model.search.isEmpty ? model.category : "搜索结果").font(.system(size: 15,weight: .semibold))
                        Text("\(model.filteredTools.count)").font(.system(size: 10,design: .monospaced)).foregroundStyle(Color.muted).padding(.horizontal,7).padding(.vertical,3).background(Color.black.opacity(0.04)).clipShape(Capsule())
                        Spacer()
                        Text("为每一步找到合适的工具").font(.system(size: 10)).foregroundStyle(Color.muted)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210,maximum: 320),spacing: 14)],spacing: 14) {
                        ForEach(model.filteredTools) { tool in ToolCard(tool: tool) }
                    }
                    if model.filteredTools.isEmpty { ContentUnavailableView.search(text: model.search).frame(maxWidth: .infinity).padding(40) }
                }
                HStack { Spacer(); Text("在本地完成，让文档处理简单一点。").font(.system(size: 10)).foregroundStyle(Color.muted); Spacer() }.padding(.vertical,10)
            }.padding(30)
        }
        .background(Button("") { searchFocused=true }.keyboardShortcut("f").hidden())
    }
    private var featured: some View {
        HStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.45)).frame(width: 66,height: 77).rotationEffect(.degrees(-12)).offset(x:-7,y:3)
                RoundedRectangle(cornerRadius: 8).fill(.white).frame(width: 66,height: 77).shadow(color: Color.coral.opacity(0.1),radius: 8,y: 4)
                Image(systemName: "arrow.triangle.merge").font(.system(size: 24,weight: .light)).foregroundStyle(Color.coral)
            }.frame(width: 88,height: 94)
            VStack(alignment: .leading,spacing: 8) {
                Text("从一份更整齐的文档开始").font(.system(size: 17,weight: .semibold))
                Text("把合同、报告和附件合在一起，按你的顺序，轻松归档。")
                    .font(.system(size: 11)).foregroundStyle(Color(hex: "8F776B"))
                HStack(spacing: 12) { Text("拖入文件"); Image(systemName: "arrow.right"); Text("调整顺序"); Image(systemName: "arrow.right"); Text("完成合并") }.font(.system(size: 10)).foregroundStyle(Color(hex: "A48A7F")).padding(.top,4)
            }
            Spacer(minLength: 8)
            Button { if let tool=model.tools.first { model.select(tool) } } label: {
                HStack(spacing: 10) { Text("合并 PDF"); Image(systemName: "arrow.up.right") }.font(.system(size: 12,weight: .medium)).padding(.horizontal,18).padding(.vertical,12)
            }.buttonStyle(.plain).foregroundStyle(.white).background(Color.coral).clipShape(RoundedRectangle(cornerRadius: 8))
        }.padding(.horizontal, 24).padding(.vertical,17).background(LinearGradient(colors: [Color(hex: "F4E5DD"),Color(hex: "FAF0E9")],startPoint: .leading,endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct ToolCard: View {
    @EnvironmentObject var model: AppModel
    let tool: PDFTool
    @State private var hovering=false
    var body: some View {
        Button { model.select(tool) } label: {
            VStack(alignment: .leading,spacing: 12) {
                HStack {
                    Image(systemName: tool.icon).font(.system(size: 21,weight: .regular)).foregroundStyle(tool.color).frame(width: 40,height: 40).background(tool.color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    if !tool.dependency.isEmpty && model.health[tool.dependency] == false {
                        Text("需组件").font(.system(size: 8)).foregroundStyle(Color.muted)
                    }
                    Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(hovering ? tool.color : Color.gray.opacity(0.25))
                }
                VStack(alignment: .leading,spacing: 7) {
                    Text(tool.name).font(.system(size: 13,weight: .semibold))
                    Text(tool.subtitle).font(.system(size: 10)).foregroundStyle(Color.muted).lineLimit(2).frame(height: 28,alignment: .topLeading)
                }
            }.padding(18).frame(maxWidth: .infinity,alignment: .leading)
                .background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(hovering ? tool.color.opacity(0.4) : Color.black.opacity(0.055)))
                .shadow(color: .black.opacity(hovering ? 0.04 : 0),radius: 8,y: 4)
        }.buttonStyle(.plain).onHover { hovering=$0 }
    }
}

struct ToolWorkspace: View {
    @EnvironmentObject var model: AppModel
    let tool: PDFTool
    @State private var dropTarget=false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: tool.icon).font(.system(size: 24)).foregroundStyle(tool.color).frame(width: 48,height: 48).background(tool.color.opacity(0.08)).cornerRadius(12)
                VStack(alignment: .leading,spacing: 6) { Text(tool.name).font(.system(size: 23,weight: .semibold)); Text(tool.subtitle).font(.system(size: 12)).foregroundStyle(Color.muted) }
                Spacer()
                Button { model.chooseFiles() } label: { Label("添加文件",systemImage: "plus") }.disabled(model.busy)
            }.padding(24)
            HSplitView {
                VStack(spacing: 0) {
                    if model.files.isEmpty { dropZone }
                    else {
                        fileList
                        Divider()
                        if tool.id == "organize", let url=model.files.first, model.pageCount>0 { pageOrganizer(url: url) }
                        else if let url=model.previewURL, url.pathExtension.lowercased()=="pdf" {
                            PDFPreview(url: url,password: model.password,page: model.previewPage,selection: ["crop","edit","sign","redact","forms"].contains(tool.id) && model.outputs.isEmpty,onRegion: model.selectRegion)
                                .overlay(alignment: .bottom) {
                                    if ["crop","edit","sign","redact","forms"].contains(tool.id) && model.outputs.isEmpty {
                                        Text("在页面中拖动，选择操作区域").font(.system(size: 10)).padding(.horizontal,12).padding(.vertical,7).background(.regularMaterial).clipShape(Capsule()).padding(12).allowsHitTesting(false)
                                    }
                                }
                        } else if let url=model.previewURL, let image=NSImage(contentsOf: url) {
                            Image(nsImage:image).resizable().scaledToFit().padding(25).frame(maxWidth: .infinity,maxHeight: .infinity)
                        } else {
                            VStack(spacing: 14) { Image(systemName: "doc.text").font(.system(size: 50,weight: .ultraLight)); Text("已准备好转换").font(.system(size: 15)); Text("转换结果将在这里预览").font(.system(size: 11)).foregroundStyle(Color.muted) }.frame(maxWidth: .infinity,maxHeight: .infinity)
                        }
                    }
                }.frame(minWidth: 420).background(Color(hex: "EDEFF2"))
                optionsPanel.frame(width: 300)
            }
            footer
        }
        .onDrop(of: [.fileURL],isTargeted: $dropTarget) { providers in
            guard !model.busy else { return false }
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url,_ in if let url { Task { @MainActor in model.addFiles([url]) } } }
            }
            return true
        }
        .overlay { if dropTarget { RoundedRectangle(cornerRadius:12).stroke(Color.coral,lineWidth:3).padding(8).allowsHitTesting(false) } }
    }
    private var dropZone: some View {
        VStack(spacing: 18) {
            Image(systemName:"doc.badge.plus").font(.system(size:50,weight:.ultraLight)).foregroundStyle(tool.color)
            Text("把文件拖到这里").font(.system(size:22,weight:.medium))
            Text("支持 " + tool.extensions.map { $0.uppercased() }.joined(separator:" · ")).font(.system(size:11)).foregroundStyle(Color.muted)
            Button { model.chooseFiles() } label: { Text("选择文件").font(.system(size:13,weight:.medium)).padding(.horizontal,32).padding(.vertical,13) }.buttonStyle(.plain).foregroundStyle(.white).background(tool.color).clipShape(RoundedRectangle(cornerRadius:8))
            Label("文件留在你的 Mac，不会上传",systemImage:"lock").font(.system(size:10)).foregroundStyle(Color.muted).padding(.top,12)
        }.frame(maxWidth:.infinity,maxHeight:.infinity).padding(30)
    }
    private var fileList: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(Array(model.files.enumerated()),id:\.element) { i,url in
                    HStack(spacing: 8) {
                        Text(String(format:"%02d",i+1)).font(.system(size:10,design:.monospaced)).foregroundStyle(Color.muted).frame(width:22)
                        Image(systemName:"doc").foregroundStyle(tool.color)
                        Button { model.loadPreview(url) } label: { Text(url.lastPathComponent).font(.system(size:11)).lineLimit(1) }.buttonStyle(.plain)
                        Spacer()
                        Button { model.files.swapAt(i,i-1) } label: { Image(systemName:"chevron.up") }.disabled(i==0 || model.busy)
                        Button { model.files.swapAt(i,i+1) } label: { Image(systemName:"chevron.down") }.disabled(i==model.files.count-1 || model.busy)
                        Button {
                            model.files.remove(at:i)
                            if let first=model.files.first { model.loadPreview(first) } else { model.previewURL=nil }
                        } label: { Image(systemName:"xmark") }.disabled(model.busy)
                    }.buttonStyle(.plain).font(.system(size:10)).padding(.horizontal,12).padding(.vertical,9).background(model.previewURL==url ? .white : .white.opacity(0.55)).cornerRadius(6)
                }
            }.padding(10)
        }.frame(maxHeight: min(150,CGFloat(model.files.count)*42+20))
    }
    private func pageOrganizer(url: URL) -> some View {
        ScrollView {
            LazyVGrid(columns:[GridItem(.adaptive(minimum:110))],spacing:16) {
                ForEach(Array(model.pageOrder.enumerated()),id:\.offset) { index,page in
                    VStack(spacing:8) {
                        PageThumbnail(url:url,page:page,password:model.password)
                        HStack(spacing:12) {
                            Button { movePage(index,-1) } label: { Image(systemName:"chevron.left") }.disabled(index==0)
                            Text("\(page)").font(.system(size:11))
                            Button { movePage(index,1) } label: { Image(systemName:"chevron.right") }.disabled(index==model.pageOrder.count-1)
                        }.buttonStyle(.plain).font(.system(size:10))
                    }.padding(10).background(.white.opacity(0.6)).cornerRadius(8)
                }
            }.padding(20)
        }.disabled(model.busy)
    }
    private func movePage(_ index: Int,_ offset: Int) {
        model.pageOrder.swapAt(index,index+offset)
        model.options["pages"]=model.pageOrder.map(String.init).joined(separator:",")
    }
    private var optionsPanel: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                Text("处理设置").font(.system(size:14,weight:.semibold))
                if !tool.note.isEmpty {
                    Text(tool.note).font(.system(size:10)).foregroundStyle(Color.muted).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
                }
                if !tool.dependency.isEmpty && model.health[tool.dependency] == false {
                    Button { model.showSettings=true } label: { Label("检查本地组件",systemImage:"exclamationmark.circle").font(.system(size:11)) }
                }
                if tool.id=="workflow" { WorkflowEditor() }
                if tool.id=="sign" || (tool.id=="edit" && model.options["mode"]=="ink") { SignaturePad(strokes:$model.strokes) }
                ForEach(tool.fields) { field in OptionField(field:field,values:$model.options) }
                if tool.id=="forms" && model.options["formMode"]=="fill" {
                    Button("重新读取表单字段") { model.inspectForm() }
                    if model.formValues.isEmpty { Text("尚未检测到字段。普通扫描表单可用“编辑 PDF”填写，或创建交互字段。").font(.system(size:10)).foregroundStyle(Color.muted) }
                    ForEach($model.formValues) { $field in
                        VStack(alignment:.leading,spacing:5) {
                            Text(field.name).font(.system(size:11,weight:.medium))
                            if field.kind == "CheckBox" {
                                Toggle("选中",isOn:Binding(get:{ ["Yes","true","1"].contains(field.value) },set:{ field.value=$0 ? "true":"false" })).font(.system(size:11))
                            } else if !field.choices.isEmpty {
                                Picker("值",selection:$field.value) { ForEach(field.choices,id:\.self) { Text($0).tag($0) } }.labelsHidden()
                            } else { TextField("字段值",text:$field.value).textFieldStyle(.roundedBorder) }
                        }
                    }
                }
                if tool.extensions.contains("pdf") {
                    Divider()
                    VStack(alignment:.leading,spacing:7) {
                        Text("原文件密码（如有）").font(.system(size:11,weight:.medium))
                        SecureField("仅用于本次处理",text:$model.password).textFieldStyle(.roundedBorder)
                    }
                }
                Divider()
                VStack(alignment:.leading,spacing:7) {
                    Text("保存到").font(.system(size:11,weight:.medium))
                    Button { model.chooseOutput() } label: {
                        HStack { Image(systemName:"folder"); Text(model.outputDirectory.lastPathComponent).lineLimit(1); Spacer(); Image(systemName:"chevron.down") }.font(.system(size:11))
                    }
                    Text("每次创建独立文件夹，保留原始文件。").font(.system(size:9)).foregroundStyle(Color.muted)
                }
            }.padding(20)
        }.background(.white).disabled(model.busy)
    }
    private var footer: some View {
        VStack(spacing:0) {
            Divider()
            if !model.outputs.isEmpty {
                HStack(spacing:10) {
                    Image(systemName:"checkmark.circle.fill").foregroundStyle(Color(hex:"53967B"))
                    Text("已生成 \(model.outputs.count) 个文件").font(.system(size:12,weight:.medium))
                    Menu("打开结果") { ForEach(model.outputs,id:\.self) { url in Button(url.lastPathComponent) { NSWorkspace.shared.open(url) } } }
                    Spacer()
                    Button("在 Finder 中查看") { if let dir=model.lastOutputDirectory { NSWorkspace.shared.open(dir) } }
                    Button("继续处理结果") { model.useResults() }.disabled(!model.outputs.contains { tool.extensions.contains($0.pathExtension.lowercased()) })
                }.padding(16).background(Color(hex:"EFF6F1"))
            }
            HStack(spacing:16) {
                if model.busy {
                    ProgressView().controlSize(.small)
                    VStack(alignment:.leading,spacing:6) { Text(model.message).font(.system(size:11)); ProgressView(value:model.fraction).frame(width:230) }
                    Spacer()
                    Button("取消处理") { model.cancel() }
                } else {
                    Text(model.files.isEmpty ? "选择文件，开始本地处理" : "已选择 \(model.files.count) 份文件").font(.system(size:11)).foregroundStyle(Color.muted)
                    Spacer()
                    Button { model.run() } label: {
                        HStack(spacing:12) { Text("开始处理"); Image(systemName:"arrow.right") }.font(.system(size:13,weight:.semibold)).padding(.horizontal,27).padding(.vertical,12)
                    }.buttonStyle(.plain).foregroundStyle(.white).background(!model.canRun ? Color.gray.opacity(0.4) : tool.color).clipShape(RoundedRectangle(cornerRadius:8)).disabled(!model.canRun)
                }
            }.padding(.horizontal,24).frame(height:72).background(.white)
        }
    }
}

struct OptionField: View {
    let field: ToolField
    @Binding var values: [String:String]
    var value: Binding<String> { Binding(get:{values[field.key] ?? field.value},set:{values[field.key]=$0}) }
    let translations = ["lossless":"无损优化","balanced":"均衡压缩","small":"更小文件","editable":"可编辑内容","visual":"保留页面外观","pages":"每页一张","embedded":"提取嵌入图片","portrait":"纵向","landscape":"横向","image":"图片 / 原图尺寸","document":"文档增强","gray":"灰度","original":"保持原图","ink":"手绘 / 手写","text":"文字","rectangle":"矩形","highlight":"高亮","fill":"填写已有字段","create":"创建新字段","checkbox":"复选框","list":"下拉列表","radio":"单选组","top-left":"左上","top-center":"上方居中","top-right":"右上","center":"页面中央","bottom-left":"左下","bottom-center":"下方居中","bottom-right":"右下"]
    var body: some View {
        VStack(alignment:.leading,spacing:7) {
            if field.kind != "toggle" { Text(field.label).font(.system(size:11,weight:.medium)) }
            switch field.kind {
            case "choice":
                Picker(field.label,selection:value) { ForEach(field.choices,id:\.self) { Text(translations[$0] ?? $0).tag($0) } }.labelsHidden().frame(maxWidth:.infinity,alignment:.leading)
            case "toggle":
                Toggle(field.label,isOn:Binding(get:{value.wrappedValue=="true"},set:{value.wrappedValue=$0 ? "true":"false"})).font(.system(size:11)).toggleStyle(.switch).controlSize(.small)
            case "secret": SecureField(field.label,text:value).textFieldStyle(.roundedBorder)
            case "textarea": TextEditor(text:value).font(.system(size:11)).frame(height:70).padding(4).overlay(RoundedRectangle(cornerRadius:5).stroke(Color.gray.opacity(0.2)))
            case "file":
                HStack {
                    Button(value.wrappedValue.isEmpty ? "选择图片…" : URL(fileURLWithPath:value.wrappedValue).lastPathComponent) {
                        let panel=NSOpenPanel(); panel.allowedContentTypes=[.image]; panel.allowsMultipleSelection=false
                        if panel.runModal() == .OK, let url=panel.url { value.wrappedValue=url.path }
                    }.lineLimit(1)
                    if !value.wrappedValue.isEmpty { Button { value.wrappedValue="" } label: { Image(systemName:"xmark") }.buttonStyle(.plain) }
                }
            default: TextField(field.label,text:value).textFieldStyle(.roundedBorder).font(.system(size:11))
            }
            if !field.help.isEmpty { Text(field.help).font(.system(size:9)).foregroundStyle(Color.muted).lineSpacing(3) }
        }
    }
}

struct WorkflowEditor: View {
    @EnvironmentObject var model: AppModel
    let allowed:Set<String>=["merge","split","extract","remove","organize","compress","repair","ocr","rotate","numbers","watermark","crop","unlock","protect","redact"]
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            if !model.presets.isEmpty {
                Menu("载入已保存流程") {
                    ForEach(model.presets) { preset in Button(preset.name) { model.steps=preset.steps } }
                }
            }
            ForEach($model.steps) { $step in
                if let tool=model.tools.first(where:{$0.id==step.toolID}) {
                    DisclosureGroup {
                        ForEach(tool.fields) { field in OptionField(field:field,values:$step.options) }
                        HStack {
                            Button("上移") { if let i=model.steps.firstIndex(where:{$0.id==step.id}),i>0 { model.steps.swapAt(i,i-1) } }
                            Button("移除",role:.destructive) { model.steps.removeAll {$0.id==step.id} }
                        }.padding(.top,8)
                    } label: { Text(tool.name).font(.system(size:12,weight:.medium)) }
                    Divider()
                }
            }
            Menu {
                ForEach(model.tools.filter {allowed.contains($0.id)}) { tool in
                    Button(tool.name) { model.steps.append(WorkflowStep(toolID:tool.id,options:Dictionary(uniqueKeysWithValues:tool.fields.map {($0.key,$0.value)}))) }
                }
            } label: { Label("添加处理步骤",systemImage:"plus") }
            TextField("流程名称",text:$model.presetName).textFieldStyle(.roundedBorder)
            Button("保存为常用流程") { model.savePreset() }.disabled(model.steps.isEmpty)
            Text("流程预设不会保存密码；加密步骤每次需重新输入。").font(.system(size:9)).foregroundStyle(Color.muted)
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment:.leading,spacing:22) {
            HStack {
                Text("最近处理").font(.system(size:27,weight:.semibold))
                Spacer()
                Button("清空记录") { model.history=[]; model.persistHistory() }.disabled(model.history.isEmpty)
            }
            Text("仅在这台 Mac 保存最近 100 次记录。清空记录不会删除输出文件。").font(.system(size:12)).foregroundStyle(Color.muted)
            if model.history.isEmpty { ContentUnavailableView("还没有处理记录",systemImage:"clock",description:Text("完成一次文档处理后，就可以在这里找到结果。")).frame(maxWidth:.infinity,maxHeight:.infinity) }
            else {
                ScrollView {
                    LazyVStack(spacing:10) {
                        ForEach(model.history) { item in
                            HStack(spacing:16) {
                                Image(systemName:"doc.badge.checkmark").font(.system(size:22)).foregroundStyle(Color.coral)
                                VStack(alignment:.leading,spacing:7) { Text(item.tool).font(.system(size:13,weight:.medium)); Text("\(item.count) 份输入 · \(item.outputs.count) 份输出 · \(item.date.formatted(date:.abbreviated,time:.shortened))").font(.system(size:10)).foregroundStyle(Color.muted) }
                                Spacer()
                                Text(String(format:"%.1f 秒",item.elapsed)).font(.system(size:10)).foregroundStyle(Color.muted)
                                Button("查看文件") { NSWorkspace.shared.open(URL(fileURLWithPath:item.directory)) }
                            }.padding(18).background(.white).cornerRadius(10)
                        }
                    }
                }
            }
        }.padding(30)
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment:.leading,spacing:22) {
            HStack { Text("本地引擎与设置").font(.system(size:22,weight:.semibold)); Spacer(); Button("完成") { dismiss() }.keyboardShortcut(.defaultAction) }
            Text("文档处理在本机进行，不上传本地文件；网址转 PDF 会联网加载你输入的网页。").font(.system(size:12)).foregroundStyle(Color.muted)
            VStack(spacing:16) {
                statusRow("PDF 处理引擎",detail:"合并、编辑、密码、转换与表单",ready:model.health["core"]==true)
                statusRow("Apple Vision",detail:"系统自带中文 / 英文识别、纸张纠偏",ready:model.health["vision"]==true)
                statusRow("LibreOffice",detail:"Word、Excel、PowerPoint 与 PDF/A 转换",ready:model.health["office"]==true)
            }.padding(18).background(Color.canvas).cornerRadius(10)
            if model.health["office"] != true { Link("下载 LibreOffice",destination:URL(string:"https://www.libreoffice.org/download/download-libreoffice/")!) }
            HStack { Button("重新检测") { model.refreshHealth() }; Spacer(); Text("AIPDF 0.1 · macOS 14+").font(.system(size:10)).foregroundStyle(Color.muted) }
            Divider()
            Text("本地签名为可视签名；复杂 Office 转换可能改变版式。当前应用依赖项目内的本地运行环境，移动到其他电脑前需重新构建。").font(.system(size:10)).foregroundStyle(Color.muted).lineSpacing(4)
        }.padding(28).frame(width:580).foregroundStyle(Color.ink).preferredColorScheme(.light)
    }
    private func statusRow(_ title:String,detail:String,ready:Bool)->some View {
        HStack(spacing:12) {
            Image(systemName:ready ? "checkmark.circle.fill":"circle.dashed").foregroundStyle(ready ? Color(hex:"52987B"):.orange)
            VStack(alignment:.leading,spacing:4) { Text(title).font(.system(size:12,weight:.medium)); Text(detail).font(.system(size:10)).foregroundStyle(Color.muted) }
            Spacer(); Text(ready ? "可用":"需配置").font(.system(size:10)).foregroundStyle(Color.muted)
        }
    }
}
