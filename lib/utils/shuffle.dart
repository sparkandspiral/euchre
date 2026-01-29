import 'package:card_game/card_game.dart';

/// Simple 32-bit XorShift generator matching Python solver seeds.
class XorShift32 {
  int _state;

  XorShift32(int seed)
      : _state = (seed & 0xFFFFFFFF) == 0 ? 1 : (seed & 0xFFFFFFFF);

  int _next32() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >> 17);
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    return _state;
  }

  int nextInt(int max) {
    return _next32() % max;
  }
}

/// Deterministic Fisher–Yates shuffle backed by [XorShift32].
void shuffleWithSeed<T>(List<T> list, int seed) {
  final rng = XorShift32(seed);
  for (var i = list.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
}

/// Returns deck order as stable integer ids for debugging/test parity.
///
/// Mirrors the pre-deal aces-at-bottom handling used by Klondike
/// `SolitaireState.getInitialState`, but stops before any tableau/foundation
/// dealing occurs.
List<int> debugDeckIdsForSeed(int seed, {required bool acesAtBottom}) {
  var deck = List.of(SuitedCard.deck);
  shuffleWithSeed(deck, seed);

  if (acesAtBottom) {
    deck = deck.where((card) => card.value != AceSuitedCardValue()).toList();
  }

  return deck
      .map((c) =>
          c.suit.index * 13 + (SuitedCardValueMapper.aceAsLowest.getValue(c) - 1))
      .toList();
}

