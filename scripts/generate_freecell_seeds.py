#!/usr/bin/env python3
import json, os, multiprocessing
from shared_rng import shuffle_with_seed

OUT_FILE="freecell_easy_seeds.json"
TARGET_COUNT=365
NODE_LIMIT=200000

# suit: 0–3 → black, red, black, red
def suit(card): return card//13
def color(card): return suit(card)%2
def rank(card): return (card%13)+1


def can_stack(a,b):
    return rank(a)==rank(b)+1 and color(a)!=color(b)


def free_capacity(free, empty):
    # max movable seq length
    return (free+1)*(2**empty)


def initial_state(seed):
    deck=list(range(52))
    shuffle_with_seed(deck,seed)

    casc=[[] for _ in range(8)]
    i=0
    while i<52:
        for c in range(8):
            if i>=52: break
            casc[c].append(deck[i]); i+=1

    free=[None]*4
    found=[0,0,0,0]
    return casc,free,found


def serialize(casc,free,found):
    return (
        tuple(tuple(col) for col in casc),
        tuple(free),
        tuple(found)
    )


def solve(seed):
    casc,free,found = initial_state(seed)

    visited=set()
    nodes=0

    stack=[(casc,free,found)]

    while stack:
        casc,free,found = stack.pop()
        key=serialize(casc,free,found)
        if key in visited: continue
        visited.add(key)

        nodes+=1
        if nodes>NODE_LIMIT: return False,nodes

        # victory?
        if all(f==13 for f in found):
            return True,nodes

        free_count=sum(1 for f in free if f is None)
        empty_casc=sum(1 for col in casc if not col)

        # Generate moves…

        # (A) Foundation moves
        for ci,col in enumerate(casc):
            if not col: continue
            top=col[-1]
            r=rank(top)
            if r==found[suit(top)]+1:
                nc=[list(c) for c in casc]
                nf=list(free)
                nfd=list(found)
                nc[ci].pop()
                nfd[suit(top)] +=1
                stack.append((nc,nf,nfd))

        for fi,f in enumerate(free):
            if f is None: continue
            top=f
            r=rank(top)
            if r==found[suit(top)]+1:
                nc=[list(c) for c in casc]
                nf=list(free); nf[fi]=None
                nfd=list(found); nfd[suit(top)]+=1
                stack.append((nc,nf,nfd))

        # (B) Move from casc → free cell
        for ci,col in enumerate(casc):
            if not col: continue
            if any(f is None for f in free):
                fi=free.index(None)
                nc=[list(c) for c in casc]
                nf=list(free)
                nfd=list(found)
                card=nc[ci].pop()
                nf[fi]=card
                stack.append((nc,nf,nfd))

        # (C) Move from free → casc
        for fi,f in enumerate(free):
            if f is None: continue
            for ci,col in enumerate(casc):
                if not col:
                    nc=[list(c) for c in casc]
                    nf=list(free)
                    nfd=list(found)
                    nc[ci].append(f)
                    nf[fi]=None
                    stack.append((nc,nf,nfd))
                else:
                    if can_stack(col[-1],f):
                        nc=[list(c) for c in casc]
                        nf=list(free)
                        nfd=list(found)
                        nc[ci].append(f)
                        nf[fi]=None
                        stack.append((nc,nf,nfd))

        # (D) Move stacks cascade→cascade
        for ci,col in enumerate(casc):
            for start in range(len(col)):
                seq=col[start:]
                # check seq is valid descending-alt-color
                ok=True
                for i in range(len(seq)-1):
                    if not can_stack(seq[i],seq[i+1]):
                        ok=False; break
                if not ok: continue

                # check move capacity
                if len(seq) > free_capacity(free_count, empty_casc):
                    continue

                for ti,tcol in enumerate(casc):
                    if ti==ci: continue
                    if not tcol:
                        # move seq to empty col
                        nc=[list(c) for c in casc]
                        nf=list(free); nfd=list(found)
                        mv=nc[ci][start:]
                        del nc[ci][start:]
                        nc[ti].extend(mv)
                        stack.append((nc,nf,nfd))
                    else:
                        if can_stack(tcol[-1], seq[0]):
                            nc=[list(c) for c in casc]
                            nf=list(free); nfd=list(found)
                            mv=nc[ci][start:]
                            del nc[ci][start:]
                            nc[ti].extend(mv)
                            stack.append((nc,nf,nfd))

    return False,nodes


def worker(seed):
    ok,n=solve(seed)
    return seed if ok else None


def main():
    if os.path.exists(OUT_FILE):
        seeds=json.load(open(OUT_FILE))["seeds"]
    else:
        seeds=[]

    found=set(seeds)
    seed=0
    pool=multiprocessing.Pool()

    while len(found)<TARGET_COUNT:
        batch=range(seed,seed+100)
        results=pool.map(worker,batch)

        for r in results:
            if r is not None:
                found.add(r)
                print("FOUND",r)
                json.dump({"seeds":sorted(found)},open(OUT_FILE,"w"))

        seed+=100

    print("DONE",len(found))

if __name__=="__main__":
    main()
