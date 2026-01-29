#!/usr/bin/env python3
import json, os, multiprocessing
from functools import lru_cache
from shared_rng import shuffle_with_seed

OUT_FILE = "golf_easy_seeds.json"
TARGET_COUNT = 365
NODE_LIMIT = 200000

# Value mapping: Ace=1 … King=13
def rank(card_id: int) -> int:
    return (card_id % 13) + 1

def can_follow(prev_card, next_card, rollover):
    if prev_card is None:
        return True
    a = rank(prev_card)
    b = rank(next_card)
    if abs(a - b) == 1:
        return True
    if rollover and {a, b} == {1, 13}:
        return True
    return False


def initial_state(seed: int, start_with_draw=True, can_rollover=True):
    deck = list(range(52))
    shuffle_with_seed(deck, seed)

    tableau = []
    idx = 0
    for _ in range(7):
        tableau.append(deck[idx:idx+5])
        idx += 5

    completed = []
    if start_with_draw:
        completed.append(deck[idx])
        idx += 1

    stock = deck[idx:]
    return tableau, stock, completed, can_rollover


def serialize(tableau, stock, completed):
    return (
        tuple(tuple(col) for col in tableau),
        tuple(stock),
        tuple(completed),
    )


def golfs_solve(seed):
    tableau, stock, completed, can_roll = initial_state(seed)
    visited = set()
    nodes = 0

    stack = [(tableau, stock, completed)]

    while stack:
        tableau, stock, completed = stack.pop()
        key = serialize(tableau, stock, completed)
        if key in visited:
            continue
        visited.add(key)

        nodes += 1
        if nodes > NODE_LIMIT:
            return False, nodes

        # Victory?
        if all(len(col) == 0 for col in tableau):
            return True, nodes

        prev = completed[-1] if completed else None

        # Moves from tableau
        for ci, col in enumerate(tableau):
            if not col:
                continue
            top = col[-1]
            if can_follow(prev, top, can_roll):
                new_tableau = [list(c) for c in tableau]
                new_stock = list(stock)
                new_completed = list(completed)

                new_tableau[ci].pop()
                new_completed.append(top)

                stack.append((new_tableau, new_stock, new_completed))

        # Draw
        if stock:
            new_tableau = [list(c) for c in tableau]
            new_stock = stock[:-1]
            new_completed = list(completed) + [stock[-1]]
            stack.append((new_tableau, new_stock, new_completed))

    return False, nodes


def worker(seed):
    solved, nodes = golfs_solve(seed)
    return seed if solved else None


def main():
    if os.path.exists(OUT_FILE):
        existing = json.load(open(OUT_FILE))["seeds"]
    else:
        existing = []

    found = set(existing)
    seed = 0

    pool = multiprocessing.Pool()

    while len(found) < TARGET_COUNT:
        batch = range(seed, seed + 200)
        results = pool.map(worker, batch)

        for r in results:
            if r is not None:
                found.add(r)
                print("FOUND:", r)
                json.dump({"seeds": sorted(found)}, open(OUT_FILE, "w"))

        seed += 200

    print("Completed:", len(found))


if __name__ == "__main__":
    main()
