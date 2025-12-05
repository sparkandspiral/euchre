#!/usr/bin/env python3
import json, os, multiprocessing
from shared_rng import shuffle_with_seed

OUT_FILE="spider_easy_seeds.json"
TARGET_COUNT=365
NODE_LIMIT=200000

def rank(card): return (card%13)+1


def initial_state(seed):
    deck=list(range(104))  # 2 full decks
    shuffle_with_seed(deck,seed)

    tableau=[[] for _ in range(10)]
    idx=0
    # deal 6 to first 4, 5 to rest
    for i in range(10):
        n=6 if i<4 else 5
        tableau[i].extend(deck[idx:idx+n])
        idx+=n

    # all tableau dealt face-down except top card:
    # Your Dart code uses SuitedCard suits but 1-suit means we ignore suit matching.
    # We'll treat all as identical suit but distinct IDs.

    # stock = remaining cards
    stock=[]
    while idx<len(deck):
        stock.append(deck[idx:idx+10])
        idx+=10

    return tableau,stock


def can_stack(top,below):
    return rank(top)+1 == rank(below)


def serialize(tableau,stock):
    return (
        tuple(tuple(col) for col in tableau),
        tuple(tuple(row) for row in stock)
    )


def solve(seed):
    tableau,stock = initial_state(seed)
    visited=set()
    nodes=0

    # each frame: tableau, stock
    stack=[(tableau,stock)]

    while stack:
        tab,stk = stack.pop()
        key=serialize(tab,stk)
        if key in visited: continue
        visited.add(key)

        nodes+=1
        if nodes>NODE_LIMIT: return False,nodes

        # remove complete sequences
        newtab=[list(col) for col in tab]
        removed_any=True
        while removed_any:
            removed_any=False
            for ci,col in enumerate(newtab):
                if len(col)>=13:
                    seq=col[-13:]
                    if all(rank(seq[i])==rank(seq[i+1])+1 for i in range(12)):
                        newtab[ci]=col[:-13]
                        removed_any=True
        tab=newtab

        # victory?
        if all(len(col)==0 for col in tab) and not stk:
            return True,nodes

        # moves: for each col, each descending sequence, move to another col
        for ci,col in enumerate(tab):
            # find sequences
            for start in range(len(col)-1):
                if not (rank(col[start])==rank(col[start+1])+1):
                    continue
                # sequence begins at start
                seq=col[start:]
                for ti,tcol in enumerate(tab):
                    if ti==ci: continue
                    if not tcol:
                        nc=[list(c) for c in tab]
                        ns=[list(r) for r in stk]
                        mv=nc[ci][start:]
                        del nc[ci][start:]
                        nc[ti].extend(mv)
                        stack.append((nc,ns))
                    else:
                        if can_stack(tcol[-1],seq[0]):
                            nc=[list(c) for c in tab]
                            ns=[list(r) for r in stk]
                            mv=nc[ci][start:]
                            del nc[ci][start:]
                            nc[ti].extend(mv)
                            stack.append((nc,ns))

        # deal from stock
        if stk and all(col for col in tab):  # cannot deal if any column empty
            nextrow=stk[-1]
            ns=[list(r) for r in stk[:-1]]
            nc=[list(c) for c in tab]
            for ci in range(10):
                nc[ci].append(nextrow[ci])
            stack.append((nc,ns))

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
                json.dump({"seeds":sorted(found)},open(OUT_FILE,"w"))
                print("FOUND",r)
        seed+=100

    print("DONE",len(found))

if __name__=="__main__":
    main()
