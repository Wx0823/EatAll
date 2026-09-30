"""Finite independent reference solver; gameplay replays must also pass Godot.
Usage: python tools/solve_levels.py [--write] [--limit 200000] [--seconds 10]
"""
import argparse, collections, json, pathlib, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
DIRS = {'U': (0,-1), 'D': (0,1), 'L': (-1,0), 'R': (1,0)}

def step(level, state, direction):
    body, fruit, pending = state
    dx,dy = DIRS[direction]
    target = (body[0][0]+dx, body[0][1]+dy)
    if target == body[1]: return None
    eating = target in fruit
    growing = eating or pending > 0
    if target in level['solid'] or target in (body if growing else body[:-1]): return None
    body = (target,) + (body if growing else body[:-1])
    pending = max(0, pending + int(eating) - int(growing))
    fruit = fruit - {target} if eating else fruit
    while True:
        if any(x<0 or y<0 or x>=level['width'] or y>=level['height'] or (x,y) in level['spikes'] for x,y in body): return None
        if any((x,y+1) in level['solid'] for x,y in body): break
        body = tuple((x,y+1) for x,y in body)
        if any(x<0 or y<0 or x>=level['width'] or y>=level['height'] or (x,y) in level['spikes'] for x,y in body): return None
        if body[0] in fruit:
            fruit = fruit - {body[0]}
            pending += 1
    return body, fruit, pending

def solve(raw, limit, seconds):
    level = dict(raw, solid=set(map(tuple,raw['terrain'])), spikes=set(map(tuple,raw['hazards'])))
    start = (tuple(map(tuple,raw['body'])), frozenset(map(tuple,raw['fruit'])), 0)
    queue = collections.deque([start]); parents = {start: None}
    begin = time.monotonic()
    while queue:
        if len(parents)>=limit or time.monotonic()-begin>=seconds:
            return None, 'budget_unknown', len(parents), time.monotonic()-begin
        state = queue.popleft()
        if not state[1] and state[0][0] == tuple(raw['exit']):
            path=[]
            while parents[state] is not None:
                state, action = parents[state]; path.append(action)
            return ''.join(reversed(path)), 'solved', len(parents), time.monotonic()-begin
        for action in DIRS:
            result=step(level,state,action)
            if result is not None and result not in parents:
                parents[result]=(state,action); queue.append(result)
    return None,'exhausted_unsolvable',len(parents),time.monotonic()-begin

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--write',action='store_true'); parser.add_argument('--limit',type=int,default=200000); parser.add_argument('--seconds',type=float,default=10)
    args=parser.parse_args(); path=ROOT/'game/data/levels.json'
    levels=json.loads(path.read_text(encoding='utf-8-sig')); failed=False
    for level in levels:
        solution,status,count,elapsed=solve(level,args.limit,args.seconds)
        print(f"EA-{level['id']:02}: {status}, states={count}, seconds={elapsed:.3f}, solution={solution}")
        if solution is None: failed=True
        elif args.write: level['solution']=solution
    if args.write: path.write_text(json.dumps(levels,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    raise SystemExit(1 if failed else 0)
if __name__=='__main__': main()
