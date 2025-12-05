#!/usr/bin/env python3
import json, os, multiprocessing
from shared_rng import shuffle_with_seed

OUT_FILE = "tripeaks_easy_seeds.json"
TARGET_COUNT = 365
NODE_LIMIT = 200000

def rank(card_id): return (card_id % 13) + 1
def can_follow(prev, nxt, rollover):
    if prev is None: return True
    a, b = rank(prev), rank(nxt)
    if abs(a-b)==1: return True
    if rollover and {a,b}=={1,13}: return True
    return False

def initial_state(seed, start_with_waste=True, rollover=True):
    deck = list(range(52))
    shuffle_with_seed(deck, seed)

    tableau = []
    idx = 0
    tableau.append(deck[idx:idx+3]); idx+=3
    tableau.append(deck[idx:idx+6]); idx+=6
    tableau.append(deck[idx:idx+9]); idx+=9
    tableau.append(deck[idx:idx+10]); idx+=10

    waste=[]
    if start_with_waste:
        waste.append(deck[idx]); idx+=1

    stock = deck[idx:]
    return tableau, stock, waste, rollover


def is_exposed(tableau, row, col):
    card = tableau[row][col]
    if card is None: return False
    if row==3: return True

    if row==2:
        return tableau[3][col] is None and tableau[3][col+1] is None

    if row==1:
        peak_group = col//2
        pos = col%2
        base = peak_group*3
        if pos==0:
            return tableau[2][base] is None and tableau[2][base+1] is None
        else:
            return tableau[2][base+1] is None and tableau[2][base+2] is None

    if row==0:
        return tableau[1][2*col] is None and tableau[1][2*col+1] is None

    return False


def serialize(tableau, stock, waste):
    return (
        tuple(tuple(c if c is None else c for c in row) for row in tableau),
        tuple(stock),
        tuple(waste),
    )


def solve(seed):
    tableau, stock, waste, rollover = initial_state(seed)
    visited=set()
    nodes=0

    stack=[(tableau,stock,waste)]

    while stack:
        tableau,stock,waste = stack.pop()
        key=serialize(tableau,stock,waste)
        if key in visited: continue
        visited.add(key)

        nodes+=1
        if nodes>NODE_LIMIT: return False,nodes

        if all(all(c is None for c in row) for row in tableau):
            return True,nodes

        prev = waste[-1] if waste else None

        # tableau moves
        for r,row in enumerate(tableau):
            for c,card in enumerate(row):
                if card is None: continue
                if is_exposed(tableau,r,c) and can_follow(prev,card,rollover):
                    newt=[list(rr) for rr in tableau]
                    newt[r][c]=None
                    ns=list(stock)
                    nw=list(waste)+[card]
                    stack.append((newt,ns,nw))

        # draw
        if stock:
            newt=[list(rr) for rr in tableau]
            ns=stock[:-1]
            nw=list(waste)+[stock[-1]]
            stack.append((newt,ns,nw))

    return False,nodes


def worker(seed):
    ok,n = solve(seed)
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
        batch=range(seed,seed+200)
        results=pool.map(worker,batch)

        for r in results:
            if r is not None:
                found.add(r)
                print("FOUND",r)
                json.dump({"seeds":sorted(found)},open(OUT_FILE,"w"))

        seed+=200

    print("DONE",len(found))

if __name__=="__main__":
    main()
