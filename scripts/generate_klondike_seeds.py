#!/usr/bin/env python3
import json
from dataclasses import dataclass, field
from enum import Enum
from typing import List, Dict, Optional, Tuple, Set

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
        # max_val > 0
        return self._next32() % max_val


def shuffle_with_seed(seq: List, seed: int) -> None:
    rng = XorShift32(seed)
    # Fisher–Yates
    for i in range(len(seq) - 1, 0, -1):
        j = rng.next_int(i + 1)
        seq[i], seq[j] = seq[j], seq[i]


# ---------- Card model (must be consistent with Dart) ----------

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


# We’ll use 1..13, Ace = 1, King = 13
ACE = 1
KING = 13


@dataclass(frozen=True)
class Card:
    suit: Suit
    value: int  # 1..13

    @property
    def id(self) -> int:
        # Unique id 0..51
        return self.suit.value * 13 + (self.value - 1)


def full_deck() -> List[Card]:
    # Order does not matter as long as Dart uses the same
    return [Card(suit, value)
            for suit in Suit
            for value in range(1, 14)]


# ---------- Klondike state ----------

@dataclass
class SolverState:
    # 7 tableau columns: hidden + revealed
    hidden: List[List[Card]]
    revealed: List[List[Card]]

    # Stock (face-down) + waste (revealedDeck in your Dart)
    stock: List[Card]
    waste: List[Card]

    # Foundations by suit
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


def initial_state_from_seed(seed: int, draw_amount: int = 1, aces_at_bottom: bool = False) -> SolverState:
    deck = full_deck()
    shuffle_with_seed(deck, seed)

    # Mirror your Dart logic:
    # final aces = deck.where(card.value == Ace).toList();
    aces = [c for c in deck if c.value == ACE]
    if aces_at_bottom:
        deck = [c for c in deck if c.value != ACE]

    hidden = []
    # hiddenCards columns
    # for i in 0..6:
    #   if acesAtBottom && i >= 3 && i < 7 && aces.isNotEmpty:
    #       column = [ace] + deck.take(i-1)
    #   else:
    #       column = deck.take(i)
    #   then deck = deck.skip(...)
    from_index = 0
    for i in range(7):
        column = []
        if aces_at_bottom and i >= 3 and i < 7 and aces:
            # place an ace + (i-1) cards from deck
            column.append(aces.pop(0))
            take = i - 1
        else:
            take = i
        column.extend(deck[from_index:from_index + take])
        from_index += take
        hidden.append(column)

    deck = deck[from_index:]

    # Now revealed: one card per column from deck
    revealed = []
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
        stock=deck,   # face-down pile
        waste=[],     # revealedDeck
        foundations=foundations,
        draw_amount=draw_amount,
        aces_at_bottom=aces_at_bottom,
    )


# ---------- Rules (mirror your Dart logic) ----------

def card_value(card: Card) -> int:
    # Ace as lowest = 1, same as our value field
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
        # Only Kings can go to empty column
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


# ---------- State transitions ----------

def draw_or_recycle(state: SolverState) -> None:
    if not state.stock:
        # recycle
        state.stock = list(reversed(state.waste))
        state.waste.clear()
    else:
        # draw draw_amount cards from end of stock into waste
        draw = min(state.draw_amount, len(state.stock))
        # Dart: revealedDeck + deck.reversed.take(drawAmount)
        # That means take from stock end, push into waste in face-up order
        for _ in range(draw):
            card = state.stock.pop()  # from end
            state.waste.append(card)


def move_tableau_to_foundation(state: SolverState, col_idx: int) -> bool:
    col = state.revealed[col_idx]
    if not col:
        return False
    card = col[-1]
    if not can_complete(state, card):
        return False

    # Remove from revealed
    col.pop()
    # If empty and hidden has cards, flip last hidden
    if not col and state.hidden[col_idx]:
        flipped = state.hidden[col_idx].pop()
        col.append(flipped)

    # Add to foundations
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


def move_tableau_to_tableau(state: SolverState, from_idx: int, start_index: int, to_idx: int) -> bool:
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

    # Do move
    del source_revealed[start_index:]
    state.revealed[to_idx].extend(moving)

    # If we emptied revealed[from_idx], flip hidden if any
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
    # for tableau moves
    from_col: Optional[int] = None
    to_col: Optional[int] = None
    start_index: Optional[int] = None  # index in from_col's revealed
    # draw has no extra fields


def generate_moves(state: SolverState) -> List[Move]:
    moves: List[Move] = []

    # 1) tableau -> foundation
    for col_idx in range(7):
        if state.revealed[col_idx]:
            card = state.revealed[col_idx][-1]
            if can_complete(state, card):
                moves.append(Move("tableau_to_foundation", from_col=col_idx))

    # 2) waste -> foundation
    if state.waste:
        if can_complete(state, state.waste[-1]):
            moves.append(Move("waste_to_foundation"))

    # 3) tableau sequences -> tableau
    for from_idx in range(7):
        source = state.revealed[from_idx]
        for start_idx in range(len(source)):
            moving = source[start_idx:]
            if not moving:
                continue
            if not is_descending_alternating(moving):
                continue
            for to_idx in range(7):
                if to_idx == from_idx:
                    continue
                if can_move_onto(state, moving[0], to_idx):
                    moves.append(Move(
                        "tableau_to_tableau",
                        from_col=from_idx,
                        to_col=to_idx,
                        start_index=start_idx,
                    ))

    # 4) waste -> tableau
    if state.waste:
        top = state.waste[-1]
        for to_idx in range(7):
            if can_move_onto(state, top, to_idx):
                moves.append(Move("waste_to_tableau", to_col=to_idx))

    # 5) draw / recycle
    if state.stock or state.waste:
        moves.append(Move("draw"))

    return moves


def apply_move(state: SolverState, move: Move) -> SolverState:
    s = state.clone()

    if move.kind == "tableau_to_foundation":
        assert move.from_col is not None
        move_tableau_to_foundation(s, move.from_col)
    elif move.kind == "waste_to_foundation":
        move_waste_to_foundation(s)
    elif move.kind == "tableau_to_tableau":
        assert move.from_col is not None and move.to_col is not None and move.start_index is not None
        move_tableau_to_tableau(s, move.from_col, move.start_index, move.to_col)
    elif move.kind == "waste_to_tableau":
        assert move.to_col is not None
        move_waste_to_tableau(s, move.to_col)
    elif move.kind == "draw":
        draw_or_recycle(s)
    else:
        raise ValueError(f"Unknown move kind: {move.kind}")

    return s


# ---------- State hashing for cycle detection ----------

def hash_state(state: SolverState) -> int:
    ints: List[int] = []

    def push_cards(cards: List[Card]):
        for c in cards:
            ints.append(c.id)
        ints.append(999)  # separator

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

        moves = generate_moves(state)
        # Optional heuristic: try foundation moves first
        # We could sort by kind, but for now just use order as generated.
        for m in moves:
            next_state = apply_move(state, m)
            h = hash_state(next_state)
            if h not in visited:
                visited.add(h)
                stack.append(next_state)

    return SolveResult(False, nodes)


# ---------- Seed mining & JSON output ----------

def mine_seeds(target_count: int,
               draw_amount: int = 1,
               aces_at_bottom: bool = False,
               node_limit: int = 200_000,
               min_nodes: int = 5_000,
               max_nodes: int = 50_000) -> List[int]:
    """Find seeds that are solvable and roughly 'medium' difficulty."""
    seeds: List[int] = []
    seed = 0

    while len(seeds) < target_count:
        res = solve_seed(seed, draw_amount, aces_at_bottom, node_limit)
        if res.solved and min_nodes <= res.nodes_expanded <= max_nodes:
            print(f"Seed {seed} OK (nodes={res.nodes_expanded})")
            seeds.append(seed)
        else:
            print(f"Seed {seed} skipped (solved={res.solved}, nodes={res.nodes_expanded})")
        seed += 1

    return seeds


def main():
    # Adjust these for how many you want:
    MEDIUM_SEED_COUNT = 200  # for example

    seeds = mine_seeds(
        target_count=MEDIUM_SEED_COUNT,
        draw_amount=1,          # classic
        aces_at_bottom=False,   # Difficulty.ace would be True here
        node_limit=200_000,
        min_nodes=5_000,        # tune ranges after you see distribution
        max_nodes=50_000,
    )

    data = {
        "seeds": seeds
    }

    with open("klondike_medium_seeds.json", "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))

    print("Wrote klondike_medium_seeds.json")


if __name__ == "__main__":
    main()
