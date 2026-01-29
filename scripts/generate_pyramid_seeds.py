#!/usr/bin/env python3
"""
Pyramid seed mining matching `PyramidSolitaireState` rules in Dart.

We generate a shuffled 52-card deck using the shared XorShift32 + Fisher–Yates,
deal a 7-row pyramid (1..7 cards), then treat the remainder as stock (draw pile)
where draws take from the END (to match Dart's `stock.last` usage).

Moves:
- Remove an exposed King (rank 13) from pyramid or waste top.
- Remove a pair of exposed pyramid cards summing to 13.
- Remove an exposed pyramid card + waste top summing to 13.
- Draw from stock to waste (moves stock.last -> waste).

Goal: remove all pyramid cards.
"""
import argparse
import json
import os
import multiprocessing
from typing import List, Optional, Tuple

from shared_rng import shuffle_with_seed

DEFAULT_OUT_FILE = "pyramid_easy_seeds.json"


def rank(card_id: int) -> int:
    return (card_id % 13) + 1


def deal(seed: int, bury_aces: bool, start_with_waste_card: bool):
    deck = list(range(52))
    shuffle_with_seed(deck, seed)

    if bury_aces:
        aces = [c for c in deck if rank(c) == 1]
        non_aces = [c for c in deck if rank(c) != 1]
        deck = non_aces + aces  # buried at "bottom" (end), drawn later

    pyramid: List[List[Optional[int]]] = []
    idx = 0
    for r in range(7):
        row = deck[idx : idx + r + 1]
        idx += r + 1
        pyramid.append([c for c in row])

    rest = deck[idx:]

    waste: List[int] = []
    if start_with_waste_card and rest:
        waste.append(rest[0])
        rest = rest[1:]

    stock = rest  # draw uses stock[-1] (end)
    return pyramid, stock, waste


def has_card(pyr: List[List[Optional[int]]], row: int, col: int) -> bool:
    if row < 0 or row >= len(pyr):
        return False
    if col < 0 or col >= len(pyr[row]):
        return False
    return True


def is_exposed(pyr: List[List[Optional[int]]], row: int, col: int) -> bool:
    if not has_card(pyr, row, col):
        return False
    card = pyr[row][col]
    if card is None:
        return False
    if row == len(pyr) - 1:
        return True
    left_covered = has_card(pyr, row + 1, col) and pyr[row + 1][col] is not None
    right_covered = has_card(pyr, row + 1, col + 1) and pyr[row + 1][col + 1] is not None
    return not (left_covered or right_covered)


def is_victory(pyr: List[List[Optional[int]]]) -> bool:
    return all(all(c is None for c in row) for row in pyr)


def serialize(pyr: List[List[Optional[int]]], stock: List[int], waste: List[int]):
    return (
        tuple(tuple(row) for row in pyr),
        tuple(stock),
        tuple(waste),
    )


def solve(seed: int, bury_aces: bool, start_with_waste_card: bool, node_limit: int) -> Tuple[bool, int]:
    pyr, stock, waste = deal(seed, bury_aces, start_with_waste_card)
    visited = set()
    nodes = 0
    stack = [(pyr, stock, waste)]

    while stack:
        pyr, stock, waste = stack.pop()
        key = serialize(pyr, stock, waste)
        if key in visited:
            continue
        visited.add(key)

        nodes += 1
        if nodes > node_limit:
            return False, nodes

        if is_victory(pyr):
            return True, nodes

        # Gather exposed cards
        exposed_positions = []
        exposed_cards = []
        for r in range(7):
            for c in range(r + 1):
                if is_exposed(pyr, r, c):
                    exposed_positions.append((r, c))
                    exposed_cards.append(pyr[r][c])

        # (A) Remove exposed King from pyramid
        for (r, c) in exposed_positions:
            card = pyr[r][c]
            if card is None:
                continue
            if rank(card) == 13:
                np = [list(row) for row in pyr]
                np[r][c] = None
                stack.append((np, list(stock), list(waste)))

        # (B) Remove pair of exposed pyramid cards summing to 13
        for i in range(len(exposed_positions)):
            a = pyr[exposed_positions[i][0]][exposed_positions[i][1]]
            if a is None:
                continue
            for j in range(i + 1, len(exposed_positions)):
                b = pyr[exposed_positions[j][0]][exposed_positions[j][1]]
                if b is None:
                    continue
                if rank(a) + rank(b) == 13:
                    np = [list(row) for row in pyr]
                    r1, c1 = exposed_positions[i]
                    r2, c2 = exposed_positions[j]
                    np[r1][c1] = None
                    np[r2][c2] = None
                    stack.append((np, list(stock), list(waste)))

        # (C) Remove exposed pyramid card with waste top summing to 13
        if waste:
            wt = waste[-1]
            for (r, c) in exposed_positions:
                card = pyr[r][c]
                if card is None:
                    continue
                if rank(card) + rank(wt) == 13:
                    np = [list(row) for row in pyr]
                    np[r][c] = None
                    nw = waste[:-1]
                    stack.append((np, list(stock), list(nw)))

            # (D) Remove waste King
            if rank(wt) == 13:
                stack.append(([list(row) for row in pyr], list(stock), waste[:-1]))

        # (E) Draw
        if stock:
            ns = stock[:-1]
            nw = list(waste) + [stock[-1]]
            stack.append(([list(row) for row in pyr], list(ns), nw))

    return False, nodes


def worker(args):
    seed, bury_aces, start_with_waste_card, node_limit = args
    ok, _ = solve(seed, bury_aces, start_with_waste_card, node_limit)
    return seed if ok else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT_FILE)
    ap.add_argument("--target", type=int, default=365)
    ap.add_argument("--node-limit", type=int, default=200_000)
    ap.add_argument("--batch", type=int, default=200)
    ap.add_argument("--bury-aces", action="store_true")
    ap.add_argument("--start-with-waste", action="store_true")
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

            task_args = [(s, args.bury_aces, args.start_with_waste, args.node_limit) for s in batch]
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


