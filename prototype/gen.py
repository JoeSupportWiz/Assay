"""Assemble screen pages from frags/*.html. First line: <!-- tab:home|studio|signet|device|none -->"""
import pathlib, re
D = pathlib.Path(__file__).parent
STATUS = '''<div class="island"></div><div class="status"><span>9:41</span><span class="r">
<svg width="19" height="12" viewBox="0 0 19 12" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>
<svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor"><path d="M8.5 2.3c2.3 0 4.4.9 6 2.4l1.2-1.2A10.2 10.2 0 0 0 8.5.6 10.2 10.2 0 0 0 1.3 3.5l1.2 1.2a8.6 8.6 0 0 1 6-2.4zm0 3.4c1.4 0 2.6.5 3.6 1.4l1.2-1.2a6.8 6.8 0 0 0-9.6 0L4.9 7.1c1-.9 2.2-1.4 3.6-1.4zm0 3.4c.5 0 1 .2 1.3.5L8.5 11 7.2 9.6c.3-.3.8-.5 1.3-.5z"/></svg>
<svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.5" fill="none" stroke="currentColor" opacity=".35"/><rect x="2" y="2" width="18" height="9" rx="2" fill="currentColor"/><path d="M25 4.5v4c.8-.3 1.3-1.1 1.3-2s-.5-1.7-1.3-2z" fill="currentColor" opacity=".35"/></svg></span></div>'''
IC = {'home': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 10.5 12 3.8l8.5 6.7v9.2a1.8 1.8 0 0 1-1.8 1.8H5.3a1.8 1.8 0 0 1-1.8-1.8z"/><path d="M9 21.5v-7h6v7"/></svg>', 'scenes': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8.6Q4 7.9 4.6 7.5L11 3.9Q12.5 3.1 12.5 4.8V14.6Q12.5 15.3 11.9 15.7L5.5 19.3Q4 20.1 4 18.4Z"/><path d="M9.5 11.4Q9.5 10.7 10.1 10.3L18 5.8Q19.5 5 19.5 6.7V14.9Q19.5 15.6 18.9 16L11 20.5Q9.5 21.3 9.5 19.6Z"/></svg>', 'studio': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="3.5" width="17" height="17" rx="4"/><path d="M7 8h10M7 12h6M7 16h8"/><circle cx="16.5" cy="12" r="1.2"/></svg>', 'lab': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M9 3.5h6M10 3.5v6l-5.5 9.1A1.9 1.9 0 0 0 6.1 21.5h11.8a1.9 1.9 0 0 0 1.6-2.9L14 9.5v-6"/><path d="M7.5 16h9"/></svg>', 'more': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/></svg>'}
NAMES = {"home":"Home","scenes":"Scenes","studio":"Studio","lab":"Lab","more":"More"}
ALIAS={"signet":"lab","device":"lab"}
exec(open(D/"mark.py").read())
def mark(h,fill="currentColor"): return f'<svg width="{h*50/71.5:.1f}" height="{h}" viewBox="17 5.5 50 71.5" fill="{fill}" aria-hidden="true">{FOLD}</svg>'
def tabbar(on):
    h = '<div class="tabbar rise" style="--d:4">'
    on = ALIAS.get(on,on)
    for k in ["home","scenes","studio","lab","more"]:
        h += f'<div class="tab{" on" if k==on else ""}">{IC[k]}<span class="lbl">{NAMES[k]}</span></div>'
    return h + '</div><div class="xptray"><span>9:41</span></div>'
HEAD = '''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="theme.css"><link rel="stylesheet" href="ui.css">
<script>const q=new URLSearchParams(location.search);</script>{extra}<link rel="stylesheet" href="craft.css"></head><body>
<script>document.body.className="t-"+(q.get("t")||"light");if(q.get("still"))document.body.classList.add("still")</script>'''
for f in sorted((D/"frags").glob("*.html")):
    src = f.read_text()
    m = re.match(r"<!--\s*tab:(\w+)\s*-->", src); tab = m.group(1) if m else "none"
    extra = ""
    mm = re.search(r"<style>.*?</style>", src, re.S)
    if mm: extra = mm.group(0); src = src.replace(extra, "")
    src = src.replace('{{MARK}}', mark(22)).replace('{{MARKW}}', mark(14,'#fff'))
    page = HEAD.format(extra=extra) + STATUS + src + (tabbar(tab) if tab != "none" else "") + '<div class="home-ind"></div></body></html>'
    (D/f.name).write_text(page); print("built", f.name)
