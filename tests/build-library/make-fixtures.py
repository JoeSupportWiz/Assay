import io, sys, zipfile, pathlib, plistlib
p=pathlib.Path(sys.argv[1]);p.mkdir(exist_ok=True)
def z(items):
 b=io.BytesIO()
 with zipfile.ZipFile(b,'w',zipfile.ZIP_DEFLATED) as a:
  for name,data in items:a.writestr(name,data)
 return b.getvalue()
for name,bundle,platform,extra in [('ok','com.joesupportwiz.assay','iPhoneOS',False),('wrong','org.example.other','iPhoneOS',False),('sim','com.joesupportwiz.assay','iPhoneSimulator',False),('extra','com.joesupportwiz.assay','iPhoneOS',True)]:
 data=plistlib.dumps({'CFBundleIdentifier':bundle,'CFBundleShortVersionString':'0.3.0','CFBundleVersion':'6','CFBundleSupportedPlatforms':[platform]})
 inner=z([('Payload/Assay.app/Info.plist',data),('Payload/Assay.app/PlugIns/AssayWidgets.appex/Info.plist',plistlib.dumps({'CFBundleIdentifier':bundle+'.widgets'}))]); outer=[('Assay-unsigned.ipa',inner)];
 if extra:outer.append(('unexpected.txt',b'x'))
 (p/(name+'.zip')).write_bytes(z(outer))
