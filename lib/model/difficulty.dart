import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:solitaire/model/game.dart';

@JsonEnum()
enum Difficulty {
  classic,
  royal,
  ace;

  String get title => switch (this) {
        Difficulty.classic => 'Classic',
        Difficulty.royal => 'Royal',
        Difficulty.ace => 'Ace',
      };

  String getDescription(Game game) => switch (this) {
        Difficulty.classic => game == Game.spider
            ? 'Play with one suit (Spades only).'
            : 'The original ruleset as traditionally played.',
        Difficulty.royal => switch (game) {
            Game.golf => 'One card is automatically drawn at the start.',
            Game.klondike => 'Cards are drawn three at a time.',
            Game.freeCell => 'Play with one fewer free cell.',
            Game.spider => 'Play with two suits (Spades and Hearts).',
            Game.pyramid => 'Start with one waste card to widen pairing options.',
            Game.triPeaks => 'Start with one waste card for an easier start.',
          },
        Difficulty.ace => switch (game) {
            Game.golf => 'One card is automatically drawn at the start, and Kings cannot wrap to Aces.',
            Game.klondike =>
              'Cards are drawn three at a time and all aces are buried at the bottom of the last four tableaus.',
            Game.freeCell =>
              'Play with one fewer free cell and all aces are buried at the bottom of the first four tableaus.',
            Game.spider => 'Play with all four suits - the ultimate challenge!',
            Game.pyramid => 'Aces are buried to the bottom of the stock for a tougher start.',
            Game.triPeaks => 'Kings cannot wrap to Aces - must plan your moves carefully!',
          },
      };

  IconData get icon => switch (this) {
        Difficulty.classic => Symbols.playing_cards,
        Difficulty.royal => Symbols.favorite,
        Difficulty.ace => Symbols.military_tech,
      };
}
