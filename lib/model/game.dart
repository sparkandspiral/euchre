import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum Game {
  golf,
  klondike,
  freeCell,
  spider,
  pyramid,
  triPeaks;

  String get title => switch (this) {
        Game.golf => 'Golf Solitaire',
        Game.klondike => 'Solitaire',
        Game.freeCell => 'Free Cell',
        Game.spider => 'Spider Solitaire',
        Game.pyramid => 'Pyramid Solitaire',
        Game.triPeaks => 'Tri-Peaks',
      };
}
