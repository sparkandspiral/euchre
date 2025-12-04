import 'package:card_game/card_game.dart';

Map<String, dynamic> encodeSuitedCard(SuitedCard card) => {
      'suit': card.suit.index,
      'value': _encodeValue(card.value),
    };

SuitedCard decodeSuitedCard(Map<String, dynamic> json) => SuitedCard(
      suit: CardSuit.values[json['suit'] as int],
      value: _decodeValue(json['value'] as Map<String, dynamic>),
    );

Map<String, dynamic> _encodeValue(SuitedCardValue value) {
  if (value is NumberSuitedCardValue) {
    return {'type': 'number', 'value': value.value};
  }
  if (value is JackSuitedCardValue) return {'type': 'jack'};
  if (value is QueenSuitedCardValue) return {'type': 'queen'};
  if (value is KingSuitedCardValue) return {'type': 'king'};
  if (value is AceSuitedCardValue) return {'type': 'ace'};
  throw ArgumentError('Unknown SuitedCardValue: $value');
}

SuitedCardValue _decodeValue(Map<String, dynamic> json) {
  switch (json['type'] as String) {
    case 'number':
      return NumberSuitedCardValue(value: json['value'] as int);
    case 'jack':
      return JackSuitedCardValue();
    case 'queen':
      return QueenSuitedCardValue();
    case 'king':
      return KingSuitedCardValue();
    case 'ace':
      return AceSuitedCardValue();
    default:
      throw ArgumentError('Unknown SuitedCardValue type: ${json['type']}');
  }
}


