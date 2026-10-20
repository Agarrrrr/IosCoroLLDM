"""Keep original PDF text-run boundaries, which plain text extraction loses."""
from pdfminer.converter import PDFPageAggregator
from pdfminer.pdfinterp import PDFResourceManager,PDFPageInterpreter
from pdfminer.pdfpage import PDFPage
from pdfminer.utils import translate_matrix

class RunDevice(PDFPageAggregator):
    def __init__(self,manager):
        super().__init__(manager);self.run=0;self.characters=[]
    def render_char(self,*args):
        advance=super().render_char(*args)
        c=self.cur_item._objs[-1]
        self.characters.append(dict(text=c.get_text(),fontname=c.fontname,size=c.size,
            x0=c.x0,x1=c.x1,top=self.height-c.y1,run=self.run))
        return advance
    def render_string_horizontal(self,seq,matrix,pos,font,fontsize,scaling,
            charspace,wordspace,rise,dxscale,ncs,graphicstate):
        x,y=pos;need=False
        for obj in seq:
            if isinstance(obj,(int,float)):
                x-=obj*dxscale;need=True
            elif isinstance(obj,bytes):
                self.run+=1
                for cid in font.decode(obj):
                    if need:x+=charspace
                    x+=self.render_char(translate_matrix(matrix,(x,y)),font,fontsize,
                        scaling,rise,cid,ncs,graphicstate)
                    if cid==32 and wordspace:x+=wordspace
                    need=True
        return x,y

def page_runs(path):
    manager=PDFResourceManager();device=RunDevice(manager)
    interpreter=PDFPageInterpreter(manager,device)
    result=[]
    with open(path,'rb') as stream:
        for page in PDFPage.get_pages(stream):
            device.height=float(page.mediabox[3]);device.characters=[]
            interpreter.process_page(page)
            result.append(device.characters)
    return result
