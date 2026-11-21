import importlib.util, json, subprocess, sys, tempfile, unittest
from pathlib import Path
P=Path(__file__).resolve().parents[1]/'assay_reports.py'
spec=importlib.util.spec_from_file_location('reports',P); m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

def sample(day,mode='iphone',battery='70%'):
 return dict(schema=m.SCHEMA,captured_at=f'2026-01-{day:02d}T12:00:00Z',engine=mode,source='demo' if mode=='demo' else 'device',facts=[dict(name='Battery',value=battery,evidence='observed')],findings=[],receipts=[])

class Reports(unittest.TestCase):
 def setUp(self): self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
 def tearDown(self): self.tmp.cleanup()
 def put(self,name,s): (self.root/name).write_text(json.dumps(s))
 def invoke(self,n='assay_latest',**args):return m.tool(n,args,self.root)
 def test_missing(self):self.assertFalse(m.tool('assay_status',{},self.root/'absent')['folder_available'])
 def test_roundtrip(self):
  self.put('assay-minis-report.json',sample(1));r=self.invoke();self.assertEqual(r['report_count'],1);self.assertEqual(r['report']['facts'][0]['value'],'70%');self.assertTrue(r['older_than_24h'])
 def test_comparison(self):
  self.put('assay-minis-report-2.json',sample(2,battery='55%'));self.put('assay-minis-report-1.json',sample(1));self.put('assay-minis-report.json',sample(3,'demo'))
  r=self.invoke('assay_compare');self.assertEqual(r['gap_seconds'],86400);self.assertEqual(r['changed_facts']['Battery']['after'],('55%','observed'));self.assertEqual(r['report_count'],2);self.assertEqual(self.invoke(engine='demo')['report_count'],1)
 def test_data_minimisation(self):
  s=sample(1);s['device_name']='PRIVATE';s['limits']=['PRIVATE'];s['facts'].append(dict(name='Model',value='PRIVATE',evidence='observed'));s['facts'].append(dict(name='Battery',value='PRIVATE',evidence='observed'));self.put('assay-minis-report.json',s);self.assertNotIn('PRIVATE',json.dumps(self.invoke()))
 def test_unreadable_files(self):
  self.put('other.json',sample(1));(self.root/'assay-minis-report-link.json').symlink_to(self.root/'other.json');(self.root/'assay-minis-report-big.json').write_bytes(b'x'*65537);(self.root/'assay-minis-report-bad.json').write_text('{');r=self.invoke();self.assertEqual(r['report_count'],0);self.assertEqual(r['skipped'],3)
 def test_wrong_source(self):
  s=sample(1,'demo');s['source']='device';self.put('assay-minis-report.json',s);self.assertEqual(self.invoke(engine='demo')['report_count'],0)
 def test_ambiguous_time(self):
  self.put('assay-minis-report-1.json',sample(1));self.put('assay-minis-report-2.json',sample(1,battery='56%'));r=self.invoke();self.assertEqual(r['report_count'],0);self.assertEqual(r['ambiguous_timestamps'],1)
 def test_log_counts(self):
  s=sample(1);s['imported_log_summary']=dict(heartbeat_samples=2,explicit_reset_lines=1,completion_lines=0,max_host_idle_seconds=30,last_reported_percent=6,path='PRIVATE');self.put('assay-minis-report.json',s)
  r=self.invoke();self.assertEqual(r['report']['imported_log_summary']['max_host_idle_seconds'],30);self.assertNotIn('PRIVATE',json.dumps(r))
 def test_protocol(self):
  msgs=[dict(jsonrpc='2.0',id=i,method=n,params=p) for i,(n,p) in enumerate([('initialize',{'protocolVersion':'2025-06-18'}),('tools/list',{}),('tools/call',{'name':'assay_latest','arguments':{'path':'../anything'}}),('apply',{})],1)];p=subprocess.run([sys.executable,'-I',str(P),'--reports',str(self.root)],input='\n'.join(map(json.dumps,msgs))+'\n',capture_output=True,text=True,check=True,timeout=5);out=list(map(json.loads,p.stdout.splitlines()));self.assertEqual(len(out[1]['result']['tools']),3);self.assertEqual(out[2]['error']['code'],-32602);self.assertEqual(out[3]['error']['code'],-32601)
if __name__=='__main__':unittest.main()
