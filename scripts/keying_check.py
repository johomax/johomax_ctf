import json,subprocess,os
from collections import defaultdict
BIN="/home/user/.cwvenv/bin/coworld"
def cli(*a): return subprocess.run([BIN,*a],capture_output=True,text=True,check=True).stdout
XQ=["xreq_9b788bf7-bdad-417c-9bdd-a830de25c67f","xreq_ad2d8b7e-1a3b-4cb4-9cd3-a31afcf7728b",
    "xreq_f148bcae-730c-4b6b-9da9-0399053060dc","xreq_198f5880-69c8-4938-b739-d794415579df"]
by_build=defaultdict(lambda: defaultdict(int))
by_seat =defaultdict(lambda: defaultdict(int))
n=0
for xq in XQ:
    d=json.loads(cli("xp-request","episodes",xq,"--json"))
    rows=d if isinstance(d,list) else d.get("entries",[])
    for r in rows:
        parts=r.get("participants") or []
        if not parts: continue
        try: res=json.loads(cli("episode-results",r["id"]))
        except Exception: continue
        if not res.get("kills"): continue
        n+=1
        pos2lab={p["position"]:p.get("label") for p in parts}
        for key in ("kills","deaths"):
            for i,v in enumerate(res.get(key) or []):
                by_build[pos2lab.get(i)][key]+=v
                by_seat["EVEN_seats" if i%2==0 else "ODD_seats"][key]+=v
def kd(t): return t["kills"]/t["deaths"] if t["deaths"] else 0
print(f"episodes: {n}\n")
print("CORRECT - keyed to the build that actually held each seat:")
for b,t in sorted(by_build.items()): print(f"   {b}: kills={t['kills']} deaths={t['deaths']} K/D={kd(t):.4f}")
print(f"   gap (v39 - v29) = {kd(by_build['jordan-ctf-candidate:v39'])-kd(by_build['jordan-ctf-candidate:v29']):+.4f}")
print("\nWRONG - keyed to seat parity, as if the treatment were always on RED:")
for b,t in sorted(by_seat.items()): print(f"   {b}: kills={t['kills']} deaths={t['deaths']} K/D={kd(t):.4f}")
print(f"   gap (EVEN - ODD) = {kd(by_seat['EVEN_seats'])-kd(by_seat['ODD_seats']):+.4f}")
