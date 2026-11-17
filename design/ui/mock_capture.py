"""Captures the approved fight-poster mockup itself, at 1280 x 720, in a chosen state, to a PNG.

    python design/ui/mock_capture.py out.png '{"view":"fight","cls":"Tempest","stag":55,"cdq":3.5,"cdr":4}'
    python design/ui/mock_capture.py --page some.html out.png           # any page beside the mockup copy
    python design/ui/mock_capture.py --dump some.html                   # print the page's final DOM text

The mockup is the vault's UI Research/fight-poster-prototype.html. This copies it to a temp folder, adds a small
script that pins the stage to the top-left at full size and applies the state in the URL hash, serves it on a free
local port and screenshots it with headless Edge (or Chrome). Nothing is installed or downloaded; the page loads
its two Google fonts as it always does.

State keys: view "fight" | "lobby"; cls (class id); touch; stag; since (seconds since the last hit: under 0.8 reads
RISING); cdq, cdr (seconds left on Q and R); stun (seconds); standing; entry (lobby window: classes, shop, ranked,
moves, more); rects (a list of CSS selectors: with --dump mock.html, prints each one's on-screen box);
run (a JavaScript expression to call after the state is set, e.g. "gotUlt()"); motion (true keeps the
animations running); ms (how long to let the page run before the picture, default 1500).
"""

from __future__ import annotations

import functools
import http.server
import json
import pathlib
import shutil
import socketserver
import subprocess
import sys
import tempfile
import threading
import urllib.parse

PROJECT = pathlib.Path(__file__).resolve().parents[2]
MOCKUP = PROJECT.parent / "UI Research" / "fight-poster-prototype.html"
BROWSERS = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
]

INJECT = r"""
<script>
(function(){
  let cap={}; try{cap=JSON.parse(decodeURIComponent(location.hash.slice(1))||'{}')}catch(e){}
  const box=document.getElementById('box');
  box.style.cssText='position:fixed;left:0;top:0;width:1280px;max-width:none;margin:0;border:0;z-index:99999';
  document.documentElement.style.overflow='hidden';
  setMotion(cap.motion===true);
  if(cap.touch)setTouch(true);
  if(cap.cls){S.equipped=S.pick=cap.cls; tint(cls(cap.cls).c);}
  if(cap.view==='fight'){
    setView('fight');
    S.stag=cap.stag==null?22:cap.stag; S.lastHit=performance.now()/1000-(cap.since==null?1:cap.since);
    S.cd.q=cap.cdq||0; S.cd.r=cap.cdr||0; S.stun=cap.stun||0;
    if(cap.standing){S.standing=cap.standing; $('standing').textContent=cap.standing;}
  } else if(cap.entry){openEntry(cap.entry);} else {closeEntry();}
  fit();
  // one timer does everything in order: clearInterval also cancels timeouts, so nothing may be queued after it
  const dump=()=>{const pre=document.createElement('pre'); pre.id='capdump';
    pre.textContent='\n'+cap.rects.map(q=>{const e=document.querySelector(q); if(!e)return 'RECT '+q+' | none';
      const r=e.getBoundingClientRect(), c=getComputedStyle(e);
      return 'RECT '+q+' | '+[r.left,r.top,r.width,r.height].map(v=>v.toFixed(1)).join(' ')+' | lay '+e.offsetWidth+'x'+e.offsetHeight+' at '+e.offsetLeft+','+e.offsetTop+' | '+c.fontSize+' '+c.fontFamily.split(',')[0]+' '+c.color+' '+c.backgroundColor;}).join('\n')+'\n';
    document.body.appendChild(pre);};
  setTimeout(()=>{
    if(cap.run)(0,eval)(cap.run);
    if(cap.motion!==true){for(let i=1;i<5000;i++)clearInterval(i);}
    if(cap.rects){if(cap.motion===true)setTimeout(dump,cap.rectsAt||300); else dump();}
  },180);
})();
</script>
"""


def browser() -> str:
    for path in BROWSERS:
        if pathlib.Path(path).exists():
            return path
    raise SystemExit("no Edge or Chrome found")


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):  # noqa: D401
        pass


def serve(folder: pathlib.Path):
    handler = functools.partial(Quiet, directory=str(folder))
    server = socketserver.ThreadingTCPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def stage(folder: pathlib.Path) -> None:
    html = MOCKUP.read_text(encoding="utf-8")
    # the mockup is an artifact page: a head and a body's contents, with no closing tags
    head = '<!doctype html><meta charset="utf-8">'
    (folder / "mock.html").write_text(head + html + INJECT, encoding="utf-8")


def run(args: list[str]) -> str:
    done = subprocess.run([browser(), *args], capture_output=True, timeout=120)
    return done.stdout.decode("utf-8", "replace")


def main() -> None:
    argv = sys.argv[1:]
    page, dump, size, clear = "mock.html", False, "1280,720", False
    while argv and argv[0].startswith("--"):
        flag = argv.pop(0)
        if flag == "--page":
            page = argv.pop(0)
        elif flag == "--dump":
            dump, page = True, argv.pop(0)
        elif flag == "--size":
            size = argv.pop(0)
        elif flag == "--clear":
            clear = True  # transparent page background
    at = 0 if dump else 1
    state = json.loads(argv[at]) if len(argv) > at else {}
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        folder = pathlib.Path(tmp)
        stage(folder)
        source = pathlib.Path(page)
        if page != "mock.html":
            shutil.copy(source, folder / source.name)
            page = source.name
        server = serve(folder)
        url = f"http://127.0.0.1:{server.server_address[1]}/{page}"
        if state:
            url += "#" + urllib.parse.quote(json.dumps(state))
        common = [
            "--headless=old",
            "--disable-gpu",
            "--hide-scrollbars",
            "--autoplay-policy=no-user-gesture-required",
            f"--user-data-dir={folder / 'profile'}",
            f"--virtual-time-budget={int(state.get('ms', 1500))}",
        ]
        if dump:
            dom = run([*common, "--dump-dom", url])
            sys.stdout.reconfigure(encoding="utf-8")
            lines = [line for line in dom.splitlines() if line.startswith("RECT ")]
            print("\n".join(lines) if lines else dom)
        else:
            out = pathlib.Path(argv[0]).resolve()
            extra = ["--default-background-color=00000000"] if clear else []
            run([*common, *extra, f"--window-size={size}", f"--screenshot={out}", url])
            print(out, out.exists() and out.stat().st_size)
        server.shutdown()


if __name__ == "__main__":
    main()
