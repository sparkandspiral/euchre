#!/usr/bin/env python3
import argparse
import json
import os
import multiprocessing
from typing import List, Optional, Tuple

from shared_rng import shuffle_with_seed

# Default output mirrors other generators.
DEFAULT_OUT_FILE = "freecell_easy_seeds.json"

# suit: 0–3 → black, red, black, red (matches Dart's CardSuit ordering)
def suit(card: int) -> int: return card // 13
def color(card: int) -> int: return suit(card) % 2
def rank(card: int) -> int: return (card % 13) + 1


def can_stack(a,b):
    return rank(a)==rank(b)+1 and color(a)!=color(b)


def free_capacity(free, empty):
    # max movable seq length
    return (free+1)*(2**empty)


def _deal_freecell_like_dart(deck: List[int], aces_at_bottom: bool) -> List[List[int]]:
    """
    Deal tableau EXACTLY like `FreeCellState.getInitialState` in Dart:
    - 8 columns
    - columns 0..3 have 7 cards, columns 4..7 have 6 cards
    - if aces_at_bottom: remove aces from deck, then insert an Ace at index 0 of cols 0..3
      (while taking one fewer card from deck for those columns)
    """
    aces: List[int] = [c for c in deck if rank(c) == 1]
    if aces_at_bottom:
        deck[:] = [c for c in deck if rank(c) != 1]

    tableau: List[List[int]] = []
    for i in range(8):
        cards_per_col = 7 if i < 4 else 6
        cards_to_take = cards_per_col - (1 if (aces_at_bottom and i < 4) else 0)
        col = deck[:cards_to_take]
        del deck[:cards_to_take]
        if aces_at_bottom and i < 4 and aces:
            col.insert(0, aces.pop(0))
        tableau.append(col)
    return tableau


def initial_state(seed: int, free_cell_count: int = 4, aces_at_bottom: bool = False):
    deck = list(range(52))
    shuffle_with_seed(deck, seed)

    tableau = _deal_freecell_like_dart(deck, aces_at_bottom=aces_at_bottom)
    free: List[Optional[int]] = [None] * free_cell_count
    found = [0, 0, 0, 0]
    return tableau, free, found


def serialize(casc,free,found):
    return (
        tuple(tuple(col) for col in casc),
        tuple(free),
        tuple(found)
    )


def solve(seed: int, free_cell_count: int, aces_at_bottom: bool, node_limit: int):
    casc, free, found = initial_state(
        seed, free_cell_count=free_cell_count, aces_at_bottom=aces_at_bottom
    )

    visited=set()
    nodes=0

    stack=[(casc,free,found)]

    while stack:
        casc,free,found = stack.pop()
        key=serialize(casc,free,found)
        if key in visited: continue
        visited.add(key)

        nodes += 1
        if nodes > node_limit:
            return False, nodes

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

    return False, nodes


def worker(args: Tuple[int, int, bool, int]):
    seed, free_cell_count, aces_at_bottom, node_limit = args
    ok, _ = solve(seed, free_cell_count, aces_at_bottom, node_limit)
    return seed if ok else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT_FILE)
    ap.add_argument("--target", type=int, default=365)
    ap.add_argument("--node-limit", type=int, default=200_000)
    ap.add_argument("--batch", type=int, default=200)
    ap.add_argument("--free-cells", type=int, default=4)
    ap.add_argument("--aces-at-bottom", action="store_true")
    args = ap.parse_args()

    if os.path.exists(args.out):
        existing = json.load(open(args.out, "r", encoding="utf-8")).get("seeds", [])
    else:
        existing = []

    found = set(int(s) for s in existing)
    seed = (max(found) + 1) if found else 0

    with multiprocessing.Pool() as pool:
        while len(found) < args.target:
            batch = list(range(seed, seed + args.batch))
            seed += args.batch

            task_args = [(s, args.free_cells, args.aces_at_bottom, args.node_limit) for s in batch]
            results = pool.map(worker, task_args)

            for r in results:
                if r is not None and r not in found:
                    found.add(r)
                    print("FOUND", r, f"[total={len(found)}]")
                    with open(args.out, "w", encoding="utf-8") as f:
                        json.dump({"seeds": sorted(found)}, f, separators=(",", ":"))

    print("DONE", len(found))

if __name__=="__main__":
    main()
