#!/usr/bin/env python3
import json
import os
from dataclasses import dataclass
from enum import Enum
from typing import List, Dict, Optional, Tuple, Set
from multiprocessing import Pool, cpu_count

# ---------- RNG + shuffle (must match Dart) ----------

class XorShift32:
    def __init__(self, seed: int):
        s = seed & 0xFFFFFFFF
        if s == 0:
            s = 1
        self.state = s

    def _next32(self) -> int:
        x = self.state
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= (x >> 17)
        x ^= (x << 5) & 0xFFFFFFFF
        self.state = x & 0xFFFFFFFF
        return self.state

    def next_int(self, max_val: int) -> int:
        return self._next32() % max_val


def shuffle_with_seed(seq: List, seed: int) -> None:
    rng = XorShift32(seed)
    for i in range(len(seq) - 1, 0, -1):
        j = rng.next_int(i + 1)
        seq[i], seq[j] = seq[j], seq[i]


# ---------- Card model ----------

class SuitColor(Enum):
    RED = 0
    BLACK = 1


class Suit(Enum):
    HEARTS = 0
    DIAMONDS = 1
    CLUBS = 2
    SPADES = 3

    @property
    def color(self) -> SuitColor:
        if self in (Suit.HEARTS, Suit.DIAMONDS):
            return SuitColor.RED
        return SuitColor.BLACK


ACE = 1
KING = 13


@dataclass(frozen=True)
class Card:
    suit: Suit
    value: int  # 1..13

    @property
    def id(self) -> int:
        return self.suit.value * 13 + (self.value - 1)


def full_deck() -> List[Card]:
    return [Card(suit, value)
            for suit in Suit
            for value in range(1, 14)]


# ---------- Klondike state ----------

@dataclass
class SolverState:
    hidden: List[List[Card]]
    revealed: List[List[Card]]
    stock: List[Card]
    waste: List[Card]
    foundations: Dict[Suit, List[Card]]
    draw_amount: int
    aces_at_bottom: bool

    def clone(self) -> "SolverState":
        return SolverState(
            hidden=[col[:] for col in self.hidden],
            revealed=[col[:] for col in self.revealed],
            stock=self.stock[:],
            waste=self.waste[:],
            foundations={s: cards[:] for s, cards in self.foundations.items()},
            draw_amount=self.draw_amount,
            aces_at_bottom=self.aces_at_bottom,
        )

    @property
    def is_victory(self) -> bool:
        return all(len(pile) == 13 for pile in self.foundations.values())


def initial_state_from_seed(seed: int,
                            draw_amount: int = 1,
                            aces_at_bottom: bool = False) -> SolverState:
    deck = full_deck()
    shuffle_with_seed(deck, seed)

    aces = [c for c in deck if c.value == ACE]
    if aces_at_bottom:
        deck = [c for c in deck if c.value != ACE]

    hidden: List[List[Card]] = []
    from_index = 0
    for i in range(7):
        column: List[Card] = []
        if aces_at_bottom and i >= 3 and i < 7 and aces:
            column.append(aces.pop(0))
            take = i - 1
        else:
            take = i
        column.extend(deck[from_index:from_index + take])
        from_index += take
        hidden.append(column)

    deck = deck[from_index:]

    revealed: List[List[Card]] = []
    from_index = 0
    for i in range(7):
        card = deck[from_index]
        from_index += 1
        revealed.append([card])

    deck = deck[from_index:]

    foundations = {s: [] for s in Suit}

    return SolverState(
        hidden=hidden,
        revealed=revealed,
        stock=deck,
        waste=[],
        foundations=foundations,
        draw_amount=draw_amount,
        aces_at_bottom=aces_at_bottom,
    )


# ---------- Rules ----------

def card_value(card: Card) -> int:
    return card.value


def can_complete(state: SolverState, card: Card) -> bool:
    pile = state.foundations[card.suit]
    if not pile:
        return card.value == ACE
    return card_value(pile[-1]) + 1 == card_value(card)


def can_move_onto(state: SolverState, moving_top: Card, target_col_idx: int) -> bool:
    target_col = state.revealed[target_col_idx]
    target_top = target_col[-1] if target_col else None

    if target_top is None:
        return moving_top.value == KING

    return (card_value(moving_top) + 1 == card_value(target_top) and
            moving_top.suit.color != target_top.suit.color)


def is_descending_alternating(cards: List[Card]) -> bool:
    if len(cards) <= 1:
        return True
    for i in range(len(cards) - 1):
        c = cards[i]
        n = cards[i + 1]
        if card_value(c) != card_value(n) + 1:
            return False
        if c.suit.color == n.suit.color:
            return False
    return True


def draw_or_recycle(state: SolverState) -> None:
    if not state.stock:
        state.stock = list(reversed(state.waste))
        state.waste.clear()
    else:
        draw = min(state.draw_amount, len(state.stock))
        for _ in range(draw):
            card = state.stock.pop()
            state.waste.append(card)


def move_tableau_to_foundation(state: SolverState, col_idx: int) -> bool:
    col = state.revealed[col_idx]
    if not col:
        return False
    card = col[-1]
    if not can_complete(state, card):
        return False

    col.pop()
    if not col and state.hidden[col_idx]:
        flipped = state.hidden[col_idx].pop()
        col.append(flipped)

    state.foundations[card.suit].append(card)
    return True


def move_waste_to_foundation(state: SolverState) -> bool:
    if not state.waste:
        return False
    card = state.waste[-1]
    if not can_complete(state, card):
        return False
    state.waste.pop()
    state.foundations[card.suit].append(card)
    return True


def move_tableau_to_tableau(state: SolverState,
                            from_idx: int,
                            start_index: int,
                            to_idx: int) -> bool:
    if from_idx == to_idx:
        return False
    source_revealed = state.revealed[from_idx]
    moving = source_revealed[start_index:]
    if not moving:
        return False
    if not is_descending_alternating(moving):
        return False
    if not can_move_onto(state, moving[0], to_idx):
        return False

    del source_revealed[start_index:]
    state.revealed[to_idx].extend(moving)

    if not source_revealed and state.hidden[from_idx]:
        flipped = state.hidden[from_idx].pop()
        source_revealed.append(flipped)

    return True


def move_waste_to_tableau(state: SolverState, to_idx: int) -> bool:
    if not state.waste:
        return False
    card = state.waste[-1]
    if not can_move_onto(state, card, to_idx):
        return False
    state.waste.pop()
    state.revealed[to_idx].append(card)
    return True


# ---------- Move enumeration ----------

@dataclass
class Move:
    kind: str
    from_col: Optional[int] = None
    to_col: Optional[int] = None
    start_index: Optional[int] = None


def generate_moves(state: SolverState) -> List[Move]:
    """Return moves ordered roughly from 'good' to 'less good'."""
    foundation_moves: List[Move] = []
    reveal_moves: List[Move] = []
    other_moves: List[Move] = []
    draw_moves: List[Move] = []

    # tableau -> foundation
    for col_idx in range(7):
        col = state.revealed[col_idx]
        if col:
            card = col[-1]
            if can_complete(state, card):
                foundation_moves.append(Move("tableau_to_foundation",
                                             from_col=col_idx))

    # waste -> foundation
    if state.waste:
        if can_complete(state, state.waste[-1]):
            foundation_moves.append(Move("waste_to_foundation"))

    # tableau sequences -> tableau
    for from_idx in range(7):
        source = state.revealed[from_idx]
        if not source:
            continue
        for start_idx in range(len(source)):
            moving = source[start_idx:]
            if not moving:
                continue
            if not is_descending_alternating(moving):
                continue
            for to_idx in range(7):
                if to_idx == from_idx:
                    continue
                if not can_move_onto(state, moving[0], to_idx):
                    continue
                # does this move reveal a hidden card?
                reveals = (start_idx == 0 and
                           len(moving) == len(source) and
                           len(state.hidden[from_idx]) > 0)
                m = Move("tableau_to_tableau",
                         from_col=from_idx,
                         to_col=to_idx,
                         start_index=start_idx)
                (reveal_moves if reveals else other_moves).append(m)

    # waste -> tableau
    if state.waste:
        top = state.waste[-1]
        for to_idx in range(7):
            if can_move_onto(state, top, to_idx):
                other_moves.append(Move("waste_to_tableau", to_col=to_idx))

    # draw / recycle
    if state.stock or state.waste:
        draw_moves.append(Move("draw"))

    return foundation_moves + reveal_moves + other_moves + draw_moves


def apply_move(state: SolverState, move: Move) -> SolverState:
    s = state.clone()
    if move.kind == "tableau_to_foundation":
        move_tableau_to_foundation(s, move.from_col)
    elif move.kind == "waste_to_foundation":
        move_waste_to_foundation(s)
    elif move.kind == "tableau_to_tableau":
        move_tableau_to_tableau(s, move.from_col, move.start_index, move.to_col)
    elif move.kind == "waste_to_tableau":
        move_waste_to_tableau(s, move.to_col)
    elif move.kind == "draw":
        draw_or_recycle(s)
    else:
        raise ValueError(f"Unknown move kind: {move.kind}")
    return s


# ---------- State hashing ----------

def hash_state(state: SolverState) -> int:
    ints: List[int] = []

    def push_cards(cards: List[Card]):
        for c in cards:
            ints.append(c.id)
        ints.append(999)

    for col in state.hidden:
        push_cards(col)
    for col in state.revealed:
        push_cards(col)
    push_cards(state.stock)
    push_cards(state.waste)
    for suit in Suit:
        push_cards(state.foundations[suit])

    return hash(tuple(ints))


# ---------- Solver ----------

@dataclass
class SolveResult:
    solved: bool
    nodes_expanded: int


def solve_seed(seed: int,
               draw_amount: int = 1,
               aces_at_bottom: bool = False,
               node_limit: int = 200_000) -> SolveResult:
    start = initial_state_from_seed(seed, draw_amount, aces_at_bottom)
    stack: List[SolverState] = [start]
    visited: Set[int] = {hash_state(start)}
    nodes = 0

    while stack and nodes < node_limit:
        state = stack.pop()
        nodes += 1

        if state.is_victory:
            return SolveResult(True, nodes)

        for m in generate_moves(state):
            next_state = apply_move(state, m)
            h = hash_state(next_state)
            if h not in visited:
                visited.add(h)
                stack.append(next_state)

    return SolveResult(False, nodes)


# ---------- Parallel mining ----------

def worker_task(args) -> Tuple[int, bool, int]:
    seed, draw_amount, aces_at_bottom, node_limit = args
    res = solve_seed(seed, draw_amount, aces_at_bottom, node_limit)
    return seed, res.solved, res.nodes_expanded


def load_existing_seeds(path: str) -> Set[int]:
    if not os.path.exists(path):
        return set()
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return set(int(s) for s in data.get("seeds", []))
    except Exception:
        return set()


def save_seeds(path: str, seeds: Set[int]) -> None:
    # Sorted for deterministic file
    data = {"seeds": sorted(seeds)}
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
    os.replace(tmp, path)


def mine_seeds_parallel(
    outfile: str,
    target_count: int,
    draw_amount: int = 1,
    aces_at_bottom: bool = False,
    node_limit: int = 200_000,
    min_nodes: int = 5_000,
    max_nodes: int = 50_000,
    batch_size: int = 200,
) -> None:
    existing = load_existing_seeds(outfile)
    print(f"Loaded {len(existing)} existing seeds from {outfile}")

    found: Set[int] = set(existing)
    seed = 0

    # Skip seeds we've already found (so we don't spam prints for known ones)
    if found:
        seed = max(found) + 1

    with Pool(processes=cpu_count()) as pool:
        while len(found) < target_count:
            batch = list(range(seed, seed + batch_size))
            seed += batch_size

            args_iter = [
                (s, draw_amount, aces_at_bottom, node_limit) for s in batch
            ]

            for s, solved, nodes in pool.imap_unordered(worker_task, args_iter):
                if solved and min_nodes <= nodes <= max_nodes:
                    if s not in found:
                        found.add(s)
                        print(f"Seed {s} OK (nodes={nodes})  [total={len(found)}]")
                        # write immediately so we can kill anytime
                        save_seeds(outfile, found)
                else:
                    print(f"Seed {s} skipped (solved={solved}, nodes={nodes})")

                if len(found) >= target_count:
                    break

    print(f"Done. Found {len(found)} seeds.")


def main():
    OUT_FILE = "klondike_medium_seeds.json"
    TARGET_COUNT = 200  # how many seeds you want

    mine_seeds_parallel(
        outfile=OUT_FILE,
        target_count=TARGET_COUNT,
        draw_amount=1,          # classic
        aces_at_bottom=False,   # Difficulty.ace => True
        node_limit=200_000,
        min_nodes=5_000,        # tune difficulty
        max_nodes=50_000,
        batch_size=200,
    )


if __name__ == "__main__":
    main()
