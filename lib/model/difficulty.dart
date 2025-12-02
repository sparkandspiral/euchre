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
        Difficulty.classic => 'Easy',
        Difficulty.royal => 'Medium',
        Difficulty.ace => 'Hard',
      };

  String getDescription(Game game) => switch (this) {
        Difficulty.classic => game == Game.spider
            ? 'Single suit for calm clears.'
            : 'Standard layout with a gentle pace.',
        Difficulty.royal => switch (game) {
            Game.golf => 'Start with one bonus draw.',
            Game.klondike => 'Draw three cards at a time.',
            Game.freeCell => 'Only three free cells available.',
            Game.spider => 'Two suits keep you alert.',
            Game.pyramid => 'Begin with one waste card.',
            Game.triPeaks => 'Begin with one waste card.',
          },
        Difficulty.ace => switch (game) {
            Game.golf => 'Bonus draw and no King-to-Ace wrap.',
            Game.klondike => 'Draw three with buried aces.',
            Game.freeCell => 'Three cells and buried aces.',
            Game.spider => 'All four suits, full gauntlet.',
            Game.pyramid => 'Buried aces slow the stock.',
            Game.triPeaks => 'No King-to-Ace wrap; plan ahead.',
          },
      };

  IconData get icon => switch (this) {
        Difficulty.classic => Symbols.playing_cards,
        Difficulty.royal => Symbols.favorite,
        Difficulty.ace => Symbols.military_tech,
      };
}
