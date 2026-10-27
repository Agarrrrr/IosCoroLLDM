from pathlib import Path
import pdfplumber
from common import read_json,save_json,sha256

def normalized_omr_pdf(folder):
 folder=Path(folder);source=folder/'original.pdf';out=folder/'omr-input.pdf';record=folder/'omr-raster.json';spec=dict(source=sha256(source),long_edge=3508,physical_dpi=300)
 if out.exists() and read_json(record)==spec:return out
 pages=[]
 with pdfplumber.open(source) as pdf:
  for p in pdf.pages:
   # Scans can contain enormous physical page dimensions. Bound the raster
   # size rather than trusting the PDF's nominal DPI or embedded image size.
   dpi=3508*72/max(p.width,p.height);im=p.to_image(resolution=dpi).original.convert('RGB');pages.append(im)
 pages[0].save(out,'PDF',resolution=300,save_all=True,append_images=pages[1:]);save_json(record,spec)
 return out
