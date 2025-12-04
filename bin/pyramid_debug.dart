import 'package:solitaire/games/pyramid_solitaire.dart';
import 'package:solitaire/model/difficulty.dart';

void main() {
  final game = PyramidSolitaire(difficulty: Difficulty.ace);
  final state = game.initialState;
  for (var r = 0; r < state.pyramid.length; r++) {
    for (var c = 0; c < state.pyramid[r].length; c++) {
      final exposed = state.isExposed(r, c);
      if (r == state.pyramid.length - 1) {
        print('Row $r col $c exposed: $exposed');
      }
    }
  }
}
