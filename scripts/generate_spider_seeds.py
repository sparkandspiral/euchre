#!/usr/bin/env python3
"""
Spider seed mining (classic = 1-suit) matching the Dart implementation:
`SpiderSolitaireState.getInitialState` + move/deal/sequence removal rules.
"""
import argparse
import json
import os
import multiprocessing
from typing import List, Tuple

from shared_rng import shuffle_with_seed

DEFAULT_OUT_FILE = "spider_easy_seeds.json"


def rank(card_id: int) -> int:
    # deck is 8 sets of 13 ranks; rank is id % 13
    return (card_id % 13) + 1


def initial_state(seed: int) -> Tuple[List[List[int]], List[List[int]], List[int], int]:
    """
    Returns (hidden_cols, revealed_cols, stock, completed_sequences).
    Stock order matches Dart: new cards are dealt from the FRONT of stock (index 0).
    """
    deck = list(range(104))  # 8 sets of 13 (classic 1-suit)
    shuffle_with_seed(deck, seed)

    hidden: List[List[int]] = []
    revealed: List[List[int]] = []

    for i in range(10):
        cards_in_col = 6 if i < 4 else 5
        hidden_col = deck[: cards_in_col - 1]
        deck = deck[cards_in_col - 1 :]
        revealed_col = [deck[0]]
        deck = deck[1:]
        hidden.append(hidden_col)
        revealed.append(revealed_col)

    stock = deck  # remaining
    return hidden, revealed, stock, 0


def is_descending(cards: List[int]) -> bool:
    for i in range(len(cards) - 1):
        if rank(cards[i]) != rank(cards[i + 1]) + 1:
            return False
    return True


def can_place_on(target_top: int, moving_bottom: int) -> bool:
    return rank(moving_bottom) + 1 == rank(target_top)


def flip_if_needed(hidden: List[List[int]], revealed: List[List[int]], col: int) -> None:
    if revealed[col]:
        return
    if hidden[col]:
        revealed[col].append(hidden[col].pop())


def remove_complete_sequences(hidden: List[List[int]], revealed: List[List[int]]) -> int:
    """
    Mimics Dart `_checkAndRemoveCompleteSequences`:
    - If last 13 revealed cards are a descending King->Ace run, remove them.
    - Then flip a hidden card if revealed becomes empty.
    Returns the number of sequences removed.
    """
    removed = 0
    for i in range(10):
        col = revealed[i]
        if len(col) < 13:
            continue
        last13 = col[-13:]
        if rank(last13[0]) == 13 and rank(last13[-1]) == 1 and is_descending(last13):
            del col[-13:]
            removed += 1
            flip_if_needed(hidden, revealed, i)
    return removed


def serialize(hidden: List[List[int]], revealed: List[List[int]], stock: List[int], completed: int):
    return (
        tuple(tuple(c) for c in hidden),
        tuple(tuple(c) for c in revealed),
        tuple(stock),
        completed,
    )


def solve(seed: int, node_limit: int) -> Tuple[bool, int]:
    hidden, revealed, stock, completed = initial_state(seed)

    visited = set()
    nodes = 0
    stack = [(hidden, revealed, stock, completed)]

    while stack:
        hidden, revealed, stock, completed = stack.pop()
        key = serialize(hidden, revealed, stock, completed)
        if key in visited:
            continue
        visited.add(key)

        nodes += 1
        if nodes > node_limit:
            return False, nodes

        # Remove completed sequences after every move/deal just like the UI
        h2 = [list(c) for c in hidden]
        r2 = [list(c) for c in revealed]
        completed2 = completed + remove_complete_sequences(h2, r2)
        hidden, revealed, completed = h2, r2, completed2

        if completed == 8:
            return True, nodes

        # Moves: move any descending revealed suffix between columns
        for from_col in range(10):
            src = revealed[from_col]
            if not src:
                continue

            for start_idx in range(len(src)):
                moving = src[start_idx:]
                if not is_descending(moving):
                    continue

                moving_bottom = moving[0]

                for to_col in range(10):
                    if to_col == from_col:
                        continue
                    dst = revealed[to_col]
                    if dst and not can_place_on(dst[-1], moving_bottom):
                        continue

                    nh = [list(c) for c in hidden]
                    nr = [list(c) for c in revealed]
                    ns = list(stock)
                    nc = completed

                    mv = nr[from_col][start_idx:]
                    del nr[from_col][start_idx:]
                    nr[to_col].extend(mv)
                    flip_if_needed(nh, nr, from_col)
                    nc += remove_complete_sequences(nh, nr)
                    stack.append((nh, nr, ns, nc))

        # Deal from stock: only if all columns have at least one revealed card
        if len(stock) >= 10 and all(col for col in revealed):
            nh = [list(c) for c in hidden]
            nr = [list(c) for c in revealed]
            ns = list(stock)
            nc = completed

            deal = ns[:10]
            ns = ns[10:]
            for i in range(10):
                nr[i].append(deal[i])

            nc += remove_complete_sequences(nh, nr)
            stack.append((nh, nr, ns, nc))

    return False, nodes


def worker(args):
    seed, node_limit = args
    ok, _ = solve(seed, node_limit=node_limit)
    return seed if ok else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT_FILE)
    ap.add_argument("--target", type=int, default=365)
    ap.add_argument("--node-limit", type=int, default=200_000)
    ap.add_argument("--batch", type=int, default=100)
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
            task_args = [(s, args.node_limit) for s in batch]
            results = pool.map(worker, task_args)
            for r in results:
                if r is not None and r not in found:
                    found.add(r)
                    print("FOUND", r, f"[total={len(found)}]")
                    with open(args.out, "w", encoding="utf-8") as f:
                        json.dump({"seeds": sorted(found)}, f, separators=(",", ":"))

    print("DONE", len(found))


if __name__ == "__main__":
    main()
