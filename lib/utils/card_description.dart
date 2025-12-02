import 'package:card_game/card_game.dart';

String describeCard(SuitedCard card) =>
    '${_describeValue(card.value)}${_describeSuitSymbol(card.suit)}';

String _describeValue(SuitedCardValue value) => switch (value) {
      NumberSuitedCardValue(:final value) => value.toString(),
      JackSuitedCardValue() => 'J',
      QueenSuitedCardValue() => 'Q',
      KingSuitedCardValue() => 'K',
      AceSuitedCardValue() => 'A',
      _ => value.toString(),
    };

String _describeSuitSymbol(CardSuit suit) => switch (suit) {
      CardSuit.hearts => '♥',
      CardSuit.diamonds => '♦',
      CardSuit.clubs => '♣',
      CardSuit.spades => '♠',
    };

String describeSuitName(CardSuit suit) => switch (suit) {
      CardSuit.hearts => 'hearts',
      CardSuit.diamonds => 'diamonds',
      CardSuit.clubs => 'clubs',
      CardSuit.spades => 'spades',
    };

String describeCardSequence(List<SuitedCard> cards) {
  if (cards.isEmpty) {
    return '';
  }

  if (cards.length == 1) {
    return describeCard(cards.first);
  }

  final first = describeCard(cards.first);
  final last = describeCard(cards.last);
  return '$first…$last';
}

String describeColumn(int index) => 'column ${index + 1}';

String describeFreeCell(int index) => 'free cell ${index + 1}';

String describeRowPosition(int row, int column) =>
    'row ${row + 1}, card ${column + 1}';

