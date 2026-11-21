#!/usr/bin/env python3
"""Assay read-only JSON-RPC over stdio. No external packages, sockets, environment credentials or write APIs."""
import argparse, datetime as dt, json, os, re, stat, sys
from itertools import islice
from pathlib import Path

SCHEMA = 'assay.minis.report.v1'
ENGINES = ('iphone','demo','mac')
PROTOCOLS = ('2025-06-18','2025-03-26','2024-11-05','2025-11-25')
MAX = 65536
FINDINGS = set('clock-941 green-line touch-dots no-logo never-locks paste-noise clock-glass prefs-unreadable thermal lowpower'.split())
EVIDENCE = ('observed','inferred','unknown')
PERM = {'Charging state': ('Charging','Unplugged','Full','Not reported'), 'Low Power Mode': ('On','Off'), 'Thermal state': ('Nominal','Fair','Serious','Critical','Unknown'), 'Status bar override': ('Present','None')}
LOG_COUNTS = ('heartbeat_samples','explicit_reset_lines','completion_lines')
SAFE_FILENAME = re.compile(r'assay-minis-report(?:[- ()A-Za-z0-9_]{0,90})\.json\Z')
UTC = dt.timezone.utc

def iso(s):
    if not isinstance(s,str) or not re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?Z',s): raise ValueError()
    return dt.datetime.fromisoformat(s.replace('Z','+00:00'))

def count(n, upper=10_000_000):
    if type(n) is not int or not 0 <= n <= upper: raise ValueError()
    return n

def clean(data):
    if not isinstance(data,dict) or data.get('schema') != SCHEMA: raise ValueError()
    mode = data['engine']; source = data['source']
    if mode not in ENGINES or source != ('demo' if mode=='demo' else 'device'): raise ValueError()
    stamp = data['captured_at']; moment = iso(stamp)
    if moment > dt.datetime.now(UTC)+dt.timedelta(minutes=5): raise ValueError()
    out = dict(schema=SCHEMA,engine=mode,source=source,captured_at=stamp)
    if data.get('check_at') is not None:
        if iso(data['check_at']) > moment+dt.timedelta(seconds=2): raise ValueError()
        out['check_at']=data['check_at']
    for field,limit in [('facts',24),('findings',32),('receipts',20)]:
        if not isinstance(data.get(field),list) or len(data[field])>limit: raise ValueError()
    facts=[]; findings=[]; receipts=[]
    for f in data['facts']:
        k,v,ev = (f[x] for x in ('name','value','evidence'))
        if ev not in EVIDENCE or not isinstance(v,str): raise ValueError()
        ok = v in PERM.get(k,()) or (k in ('Battery','Battery health') and (v=='Not reported' or re.fullmatch(r'(?:100|[1-9]?\d)%',v))) or (k=='iOS' and re.fullmatch(r'[1-9][0-9]?(?:\.(?:0|[1-9][0-9]?)){0,2}',v))
        if ok: facts.append(dict(name=k,value=v,evidence=ev))
    for f in data['findings']:
        if f['id'] in FINDINGS and f['severity'] in ('info','attention','problem') and f['evidence'] in EVIDENCE:
            findings.append({k:f[k] for k in ('id','severity','evidence')})
    for r in data['receipts']:
        if r['engine'] != mode or r['kind'] not in ('fix','tweak','undo','scene','restoreAll') or r['outcome'] not in ('complete','partial','failed','simulated','rolled_back'): raise ValueError()
        iso(r['when']); count(r['number']); count(r['item_count']); receipts.append({k:r[k] for k in ('number','kind','outcome','when','item_count','engine')})
    out.update(facts=facts,findings=findings,receipts=receipts)
    if (l:=data.get('imported_log_summary')) is not None:
        if mode=='demo' or not isinstance(l,dict):raise ValueError()
        log={k:count(l[k]) for k in LOG_COUNTS}
        for k,m in [('last_reported_percent',100),('max_host_idle_seconds',9_999_999)]:
            if l.get(k) is not None: log[k]=count(l[k],m)
        out['imported_log_summary']=log
    return out

def read_reports(directory, mode):
    rows={}; conflicts=set(); rejected=0; inspected=0
    try: fd=os.open(directory,os.O_RDONLY|os.O_DIRECTORY)
    except OSError: return [],dict(folder_available=False,files_checked=0,skipped=0,truncated=False)
    truncated=False
    try:
        with os.scandir(fd) as entries:
            for i,e in enumerate(entries):
                if i>=512 or inspected>=128: truncated=True; break
                if not SAFE_FILENAME.fullmatch(e.name):continue
                inspected+=1
                try:
                    f=os.open(e.name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=fd)
                    with os.fdopen(f,'rb') as inf:
                        st=os.fstat(inf.fileno());
                        if not stat.S_ISREG(st.st_mode) or st.st_size>MAX: raise ValueError()
                        payload=inf.read(MAX+1)
                    if len(payload)>MAX: raise ValueError()
                    report=clean(json.loads(payload))
                    if report['engine']!=mode:continue
                    key=iso(report['captured_at']);
                    if key in rows and rows[key]!=report: conflicts.add(key)
                    else:rows[key]=report
                except (OSError,ValueError,TypeError,KeyError,RecursionError,OverflowError): rejected+=1
    finally:os.close(fd)
    return [rows[k] for k in sorted(rows,reverse=True) if k not in conflicts],dict(folder_available=True,files_checked=inspected,skipped=rejected,ambiguous_timestamps=len(conflicts),truncated=truncated)

TOOLS={'assay_status':'Count valid reviewed snapshots; report timestamps, age and missing evidence.', 'assay_latest':'Read the latest allowlisted snapshot for the selected engine. Not a live device query.', 'assay_compare':'Compare two most recent distinct snapshots of the same engine; do not assume same physical phone.'}

def tool(name, args, directory):
    if not isinstance(args,dict) or set(args)-{'engine'}:raise ValueError()
    mode=args.get('engine','iphone')
    if mode not in ENGINES or name not in TOOLS: raise ValueError()
    rows,info=read_reports(directory,mode); now=dt.datetime.now(UTC)
    times=[r['captured_at'] for r in rows]; out=dict(engine=mode,report_count=len(rows),from_utc=times[-1] if rows else None,to_utc=times[0] if rows else None,**info)
    if not rows:
        return dict(out,message='No reviewed snapshots for this engine. Mount the dedicated Assay Reports folder read-only and export there from Lab → Analyse with Minis. Demo must be requested explicitly.')
    age=max(0,int((now-iso(times[0])).total_seconds()));out.update(latest_age_seconds=age,older_than_24h=age>86400)
    out['limits']=['Manually exported snapshots only, not live access. No unique device identifier.','Absent or filtered evidence is not proof that an issue is absent.','Imported log counts refer to lines in a user-selected excerpt: possibly duplicated, from multiple runs or another device. Original log time window is unknown. Do not add counts across exports.']
    if name=='assay_latest':out['report']=rows[0]
    if name=='assay_compare':
        if len(rows)<2:return dict(out,message='Two distinct export times for this engine are required for a comparison.')
        old,new=rows[1],rows[0]; out['compared_times']=[old['captured_at'],new['captured_at']]
        od={f['name']:(f['value'],f['evidence']) for f in old['facts']}; nd={f['name']:(f['value'],f['evidence']) for f in new['facts']}
        out['changed_facts']={k:{'before':od.get(k),'after':nd.get(k)} for k in sorted(od.keys()|nd.keys()) if od.get(k)!=nd.get(k)}
        out['findings']={'before':old['findings'],'after':new['findings']};out['log_summaries']=[r.get('imported_log_summary') for r in (old,new)]
        out['receipt_summary_counts']=[len(r['receipts']) for r in (old,new)];out['gap_seconds']=int((iso(new['captured_at'])-iso(old['captured_at'])).total_seconds())
    return out

def dispatch(q,directory):
    if not isinstance(q,dict) or q.get('jsonrpc')!='2.0' or not isinstance(q.get('method'),str):return {'jsonrpc':'2.0','id':None,'error':{'code':-32600,'message':'Invalid request'}}
    if 'id' not in q:return None
    res={'jsonrpc':'2.0','id':q['id']};m=q['method'];p=q.get('params') or {}
    if not isinstance(p,dict):return dict(res,error={'code':-32602,'message':'Invalid parameters'})
    if m=='initialize':v=p.get('protocolVersion');r=dict(protocolVersion=v if v in PROTOCOLS else PROTOCOLS[0],capabilities={'tools':{}},serverInfo={'name':'assay-reports','version':'1.0.0'})
    elif m=='ping':r={}
    elif m=='tools/list':
        schema={'type':'object','properties':{'engine':{'type':'string','enum':list(ENGINES),'default':'iphone'}},'additionalProperties':False}
        r={'tools':[dict(name=n,description=d,inputSchema=schema,annotations={'readOnlyHint':True,'destructiveHint':False,'openWorldHint':False}) for n,d in TOOLS.items()]}
    elif m=='tools/call':
        try: text=json.dumps(tool(p['name'],p.get('arguments',{}),directory),ensure_ascii=False); r={'content':[{'type':'text','text':text}]}
        except (TypeError,ValueError,KeyError):return dict(res,error={'code':-32602,'message':'Unknown tool or invalid arguments'})
    else:return dict(res,error={'code':-32601,'message':'Method not available'})
    return dict(res,result=r)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--reports',type=Path,default=Path('/var/minis/mounts/Assay Reports'));directory=parser.parse_args().reports
    while line:=sys.stdin.buffer.readline(MAX+1):
        if len(line)>MAX:return 2
        try:res=dispatch(json.loads(line),directory)
        except (ValueError,UnicodeError,RecursionError):res={'jsonrpc':'2.0','id':None,'error':{'code':-32700,'message':'Invalid JSON'}}
        except OSError:res={'jsonrpc':'2.0','id':None,'error':{'code':-32603,'message':'Reports folder unavailable'}}
        if res is not None: print(json.dumps(res,ensure_ascii=False),flush=True)
if __name__=='__main__':sys.exit(main())
