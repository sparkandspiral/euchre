#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
from pathlib import Path
from typing import List, Optional, Tuple

from shared_rng import shuffle_with_seed

# Default output mirrors other generators.
DEFAULT_OUT_FILE = "freecell_easy_seeds.json"

# suit: 0–3 → hearts, diamonds, clubs, spades (matches Dart's CardSuit ordering)
# value order in deck: 2..10, J, Q, K, A (matches SuitedCard.deck)
VALUES_IN_ORDER = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 1]
SUITS_IN_ORDER = [0, 1, 2, 3]
SUIT_TO_CHAR = {0: "H", 1: "D", 2: "C", 3: "S"}

Card = Tuple[int, int]  # (suit, rank_value) where Ace=1, Jack=11, Queen=12, King=13


def suit(card: Card) -> int:
    return card[0]


def rank(card: Card) -> int:
    return card[1]


def _deal_freecell_like_dart(
    deck: List[Card], aces_at_bottom: bool
) -> List[List[Card]]:
    """
    Deal tableau EXACTLY like `FreeCellState.getInitialState` in Dart:
    - 8 columns
    - columns 0..3 have 7 cards, columns 4..7 have 6 cards
    - if aces_at_bottom: remove aces from deck, then insert an Ace at index 0 of cols 0..3
      (while taking one fewer card from deck for those columns)
    """
    aces: List[Card] = [c for c in deck if rank(c) == 1]
    if aces_at_bottom:
        deck[:] = [c for c in deck if rank(c) != 1]

    tableau: List[List[Card]] = []
    for i in range(8):
        cards_per_col = 7 if i < 4 else 6
        cards_to_take = cards_per_col - (1 if (aces_at_bottom and i < 4) else 0)
        col = deck[:cards_to_take]
        del deck[:cards_to_take]
        if aces_at_bottom and i < 4 and aces:
            col.insert(0, aces.pop(0))
        tableau.append(col)
    return tableau


def deal_tableau(
    seed: int, *, aces_at_bottom: bool = False
) -> List[List[Card]]:
    deck = [(s, v) for s in SUITS_IN_ORDER for v in VALUES_IN_ORDER]
    shuffle_with_seed(deck, seed)

    tableau = _deal_freecell_like_dart(deck, aces_at_bottom=aces_at_bottom)
    return tableau


def card_to_str(card: Card) -> str:
    value = rank(card)
    if value == 1:
        value_str = "A"
    elif value == 11:
        value_str = "J"
    elif value == 12:
        value_str = "Q"
    elif value == 13:
        value_str = "K"
    else:
        value_str = str(value)
    return f"{value_str}{SUIT_TO_CHAR[suit(card)]}"


def tableau_to_json(tableau: List[List[Card]]) -> dict:
    return {
        "tableau piles": [
            [card_to_str(card) for card in column] for column in tableau
        ]
    }


def _game_type_for_free_cells(free_cell_count: int) -> str:
    if free_cell_count == 4:
        return "free-cell"
    if 0 <= free_cell_count <= 3:
        return f"free-cell-{free_cell_count}-cell"
    raise ValueError(f"Unsupported free cell count: {free_cell_count}")


def run_solvitaire(
    deal_path: Path,
    *,
    game_type: str,
    solvitaire_root: Path,
    use_docker: bool,
    timeout_ms: int,
    streamliner: Optional[str],
) -> str:
    extra_args = []
    if timeout_ms > 0:
        extra_args += ["--timeout", str(timeout_ms)]
    if streamliner:
        extra_args += ["--str", streamliner]

    if use_docker:
        rel_deal_path = str(deal_path.relative_to(solvitaire_root))
        cmd = [
            str(solvitaire_root / "enter-container.sh"),
            " ".join(
                ["./solvitaire", "--type", game_type, *extra_args, rel_deal_path]
            ),
        ]
    else:
        cmd = [
            str(solvitaire_root / "solvitaire"),
            "--type",
            game_type,
            *extra_args,
            str(deal_path),
        ]

    result = subprocess.run(
        cmd,
        cwd=solvitaire_root,
        capture_output=True,
        text=True,
        check=False,
    )
    return (result.stdout or "") + (result.stderr or "")


def run_solvitaire_batch(
    deal_paths: List[Path],
    *,
    game_type: str,
    solvitaire_root: Path,
    use_docker: bool,
    timeout_ms: int,
    streamliner: Optional[str],
    wall_timeout_s: Optional[float],
) -> Tuple[str, bool]:
    extra_args = []
    if timeout_ms > 0:
        extra_args += ["--timeout", str(timeout_ms)]
    if streamliner:
        extra_args += ["--str", streamliner]

    if use_docker:
        rel_deal_paths = [
            str(path.relative_to(solvitaire_root)) for path in deal_paths
        ]
        cmd = [
            str(solvitaire_root / "enter-container.sh"),
            " ".join(
                ["./solvitaire", "--type", game_type, *extra_args, *rel_deal_paths]
            ),
        ]
    else:
        cmd = [
            str(solvitaire_root / "solvitaire"),
            "--type",
            game_type,
            *extra_args,
            *[str(path) for path in deal_paths],
        ]

    try:
        result = subprocess.run(
            cmd,
            cwd=solvitaire_root,
            capture_output=True,
            text=True,
            check=False,
            timeout=wall_timeout_s,
        )
        return (result.stdout or "") + (result.stderr or ""), False
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or "") + (exc.stderr or "")
        return output + "\n[timeout] wall-clock timeout reached\n", True


def parse_batch_results(output: str) -> dict:
    results = {}
    current_file = None
    for line in output.splitlines():
        if "Attempting to solve " in line:
            current_file = line.split("Attempting to solve ", 1)[1].strip(" .")
        elif "Solution Type:" in line and current_file:
            results[current_file] = line.split("Solution Type:", 1)[1].strip()
            current_file = None
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT_FILE)
    ap.add_argument("--target", type=int, default=365)
    ap.add_argument("--batch", type=int, default=200)
    ap.add_argument("--solvitaire-batch", type=int, default=20)
    ap.add_argument("--free-cells", type=int, default=4)
    ap.add_argument("--aces-at-bottom", action="store_true")
    ap.add_argument(
        "--solvitaire-root",
        default=str(Path(__file__).resolve().parent.parent / "vendor" / "Solvitaire"),
    )
    ap.add_argument("--no-docker", action="store_true")
    ap.add_argument("--timeout-ms", type=int, default=60_000)
    ap.add_argument("--wall-timeout-s", type=float, default=None)
    ap.add_argument("--streamliner", default="smart-solvability")
    ap.add_argument("--keep-deals", action="store_true")
    ap.add_argument("--stop-after-first", action="store_true")
    args = ap.parse_args()

    solvitaire_root = Path(args.solvitaire_root).resolve()
    use_docker = not args.no_docker
    if args.streamliner.lower() == "none":
        args.streamliner = None
    if not solvitaire_root.exists():
        raise SystemExit(f"Solvitaire root not found: {solvitaire_root}")
    if use_docker and not (solvitaire_root / "enter-container.sh").exists():
        raise SystemExit("enter-container.sh not found in Solvitaire root.")
    if args.wall_timeout_s is None:
        args.wall_timeout_s = max(10.0, (args.timeout_ms / 1000.0) + 10.0)
    deals_dir = solvitaire_root / "tmp" / "freecell_deals"
    deals_dir.mkdir(parents=True, exist_ok=True)

    if os.path.exists(args.out):
        existing = json.load(open(args.out, "r", encoding="utf-8")).get("seeds", [])
    else:
        existing = []

    found = set(int(s) for s in existing)
    seed = (max(found) + 1) if found else 0

    while len(found) < args.target:
        seeds_batch = list(range(seed, seed + args.batch))
        seed += args.batch

        batch_paths = []
        batch_seed_map = {}
        for s in seeds_batch:
            tableau = deal_tableau(s, aces_at_bottom=args.aces_at_bottom)
            deal_json = tableau_to_json(tableau)
            deal_path = deals_dir / f"seed_{s}.json"
            with open(deal_path, "w", encoding="utf-8") as f:
                json.dump(deal_json, f, separators=(",", ":"))
            batch_paths.append(deal_path)
            batch_seed_map[deal_path.name] = s

            if len(batch_paths) >= args.solvitaire_batch:
                output, timed_out = run_solvitaire_batch(
                    batch_paths,
                    game_type=_game_type_for_free_cells(args.free_cells),
                    solvitaire_root=solvitaire_root,
                    use_docker=use_docker,
                    timeout_ms=args.timeout_ms,
                    streamliner=args.streamliner,
                    wall_timeout_s=args.wall_timeout_s,
                )
                if timed_out:
                    print(
                        f"TIMEOUT batch seeds {batch_seed_map[batch_paths[0].name]}.."
                        f"{batch_seed_map[batch_paths[-1].name]}"
                    )
                    results = {}
                else:
                    results = parse_batch_results(output)

                for deal_path in batch_paths:
                    key = (
                        str(deal_path)
                        if not use_docker
                        else str(deal_path.relative_to(solvitaire_root))
                    )
                    status = results.get(key) or results.get(str(deal_path.name))
                    s = batch_seed_map[deal_path.name]
                    if status == "solved":
                        if s not in found:
                            found.add(s)
                            print("FOUND", s, f"[total={len(found)}]")
                            with open(args.out, "w", encoding="utf-8") as f:
                                json.dump(
                                    {"seeds": sorted(found)}, f, separators=(",", ":")
                                )
                            if args.stop_after_first:
                                print("STOP after first found")
                                return
                    else:
                        print("SKIP", s)

                if not args.keep_deals:
                    for deal_path in batch_paths:
                        try:
                            deal_path.unlink()
                        except OSError:
                            pass

                batch_paths = []
                batch_seed_map = {}

        if batch_paths:
            output, timed_out = run_solvitaire_batch(
                batch_paths,
                game_type=_game_type_for_free_cells(args.free_cells),
                solvitaire_root=solvitaire_root,
                use_docker=use_docker,
                timeout_ms=args.timeout_ms,
                streamliner=args.streamliner,
                wall_timeout_s=args.wall_timeout_s,
            )
            if timed_out:
                print(
                    f"TIMEOUT batch seeds {batch_seed_map[batch_paths[0].name]}.."
                    f"{batch_seed_map[batch_paths[-1].name]}"
                )
                results = {}
            else:
                results = parse_batch_results(output)

            for deal_path in batch_paths:
                key = (
                    str(deal_path)
                    if not use_docker
                    else str(deal_path.relative_to(solvitaire_root))
                )
                status = results.get(key) or results.get(str(deal_path.name))
                s = batch_seed_map[deal_path.name]
                if status == "solved":
                    if s not in found:
                        found.add(s)
                        print("FOUND", s, f"[total={len(found)}]")
                        with open(args.out, "w", encoding="utf-8") as f:
                            json.dump(
                                {"seeds": sorted(found)}, f, separators=(",", ":")
                            )
                        if args.stop_after_first:
                            print("STOP after first found")
                            return
                else:
                    print("SKIP", s)

            if not args.keep_deals:
                for deal_path in batch_paths:
                    try:
                        deal_path.unlink()
                    except OSError:
                        pass

    print("DONE", len(found))

if __name__=="__main__":
    main()
