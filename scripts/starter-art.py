from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import io, math
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parents[1]
out=root/'App/ArtResources/AssayCanvasSample.zip';out.parent.mkdir(exist_ok=True)
with ZipFile(out,'w',ZIP_DEFLATED) as z:
    for index,name in enumerate(['Dusk','Fjord']):
        w,h=360,640; im=Image.new('RGB',(w,h));pix=im.load()
        a,b=([(249,187,126),(62,41,121)],[(117,214,183),(35,62,111)])[index]
        for y in range(h):
            for x in range(w):
                t=min(1,max(0,.15*x/w+.85*y/h+.07*math.sin(x/w*3.8+y/h*2)))
                pix[x,y]=tuple(round(k*(1-t)+l*t) for k,l in zip(a,b))
        pen=ImageDraw.Draw(im,'RGBA');
        for i in range(9):pen.arc((-190+i*16,30+i*20,450+i*14,720+i*15),194,340,fill=(255,255,255,90),width=2)
        f=io.BytesIO();im.save(f,'PNG');z.writestr('Artwork/'+name+'.png',f.getvalue())
    z.writestr('Project.txt','Original Assay ZIP artwork sample. Not an installable system wallpaper.\n')
print(out.name,out.stat().st_size)
