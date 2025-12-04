import 'package:flutter/material.dart';
import 'package:solitaire/model/game.dart';

extension GameVisuals on Game {
  List<Color> get accentGradient => switch (this) {
        Game.klondike => [Color(0xFF00A8CC), Color(0xFF0074B7)],
        Game.spider => [Color(0xFF8B2FC9), Color(0xFF5C0099)],
        Game.freeCell => [Color(0xFFE63946), Color(0xFFC41E3A)],
        Game.pyramid => [Color(0xFFE67E22), Color(0xFFD35400)],
        Game.golf => [Color(0xFF27AE60), Color(0xFF1E8449)],
        Game.triPeaks => [Color(0xFFFFD700), Color(0xFFB8860B)],
      };

  IconData get icon => switch (this) {
        Game.klondike => Icons.stars,
        Game.spider => Icons.apps,
        Game.freeCell => Icons.dashboard,
        Game.pyramid => Icons.change_history,
        Game.golf => Icons.terrain,
        Game.triPeaks => Icons.filter_hdr,
      };

  String get logoAsset => switch (this) {
        Game.klondike => 'assets/logos/klondike.png',
        Game.spider => 'assets/logos/spider.png',
        Game.freeCell => 'assets/logos/freecell.png',
        Game.pyramid => 'assets/logos/pyramid.png',
        Game.golf => 'assets/logos/golf.png',
        Game.triPeaks => 'assets/logos/tripeaks.png',
      };

  Color get accentColor => accentGradient.first;
}
