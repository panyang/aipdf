"""Create synthetic, non-sensitive examples for manual visual acceptance."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/"backend"))
import pymupdf as fitz
import engine

OUT=ROOT/"tmp/qa"
OUT.mkdir(parents=True,exist_ok=True)
doc=fitz.open()
for number in range(1,4):
    page=doc.new_page()
    page.draw_rect(fitz.Rect(0,0,595,13),color=None,fill=(.84,.4,.3))
    page.insert_text((48,64),"AIPDF / LOCAL DOCUMENT STUDIO",fontsize=11,color=(.5,.55,.58))
    page.insert_text((48,116),f"Project Notes / {number:02d}",fontsize=29,color=(.15,.2,.25))
    page.insert_text((48,156),"本地文档处理示例",fontname="china-s",fontsize=20,color=(.15,.2,.25))
    page.insert_text((48,204),"One workspace for every PDF task.",fontsize=14)
    page.insert_text((48,235),"This is a synthetic document for testing AIPDF.",fontsize=11)
    page.insert_text((48,264),"Reference: PRIVATE-2048",fontsize=11)
    for y in [320,356,392,428]:page.draw_line((48,y),(547,y),color=(.8,.83,.85))
    for x in [48,340,547]:page.draw_line((x,320),(x,428),color=(.8,.83,.85))
    page.draw_rect(fitz.Rect(48,320,547,356),color=None,fill=(.94,.95,.96),overlay=False)
    for i,(a,b) in enumerate([("Document task","Status"),("Local processing","Ready"),("Original preserved","Yes")]):
        page.insert_text((60,344+i*36),a,fontsize=11)
        page.insert_text((354,344+i*36),b,fontsize=11)
    page.insert_text((48,782),f"AIPDF demonstration / page {number} of 3",fontsize=10,color=(.55,.58,.6))
source=OUT/"demo.pdf";doc.save(source);doc.close()
with fitz.open(source) as d:d[0].get_pixmap(dpi=144).save(OUT/"scan.png")
cases={
    "watermark":{"text":"内部资料","position":"center","fontsize":"36"},
    "numbers":{},
    "redact":{"text":"PRIVATE-2048"},
    "forms":{"formMode":"create","fieldName":"reviewer","fieldValue":"Ada Lovelace","x":"48","y":"485","width":"300","height":"38"},
    "edit":{"text":"Reviewed / 已审核","x":"48","y":"545","width":"380","height":"64"},
    "crop":{"x":"30","y":"25","width":"530","height":"775"},
    "sign":{"x":"48","y":"620","width":"250","height":"60","strokes":[[[.05,.8],[.2,.1],[.4,.7],[.6,.2],[.8,.7],[.95,.4]]]},
}
results={"demo":str(source)}
for op,options in cases.items():
    result=engine.dispatch({"operation":op,"files":[str(source)],"options":options,"outputDir":str(OUT)})
    path=result["outputs"][0];results[op]=path
    with fitz.open(path) as d:d[0].get_pixmap(dpi=96).save(OUT/f"{op}.png")
import json
(OUT/"results.json").write_text(json.dumps(results,ensure_ascii=False,indent=2))
print(OUT)
