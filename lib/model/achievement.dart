import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/model/save_state.dart';
import 'package:utils/utils.dart';

enum Achievement {
  fullHouse('Full House', 'Complete all games on Easy.'),
  royalFlush('Royal Flush', 'Complete all games on Medium.'),
  speedDealer('Speed Dealer', 'Win any game in under 1 minute.'),
  grandSlam(
      'Grand Slam', 'In Golf Solitaire, make a chain of 20 consecutive cards.'),
  suitedUp(
    'Suited Up',
    'In Free Cell, fully complete one suit (Ace to King) before moving any other suits to foundations. (Hint: Disable Auto Move in Settings)',
  ),
  stackTheDeck(
      'Stack the Deck', 'Win 3 games in a row without restarting a game.'),
  deckWhisperer('Deck Whisperer',
      'Win a Solitaire game without cycling through the draw pile.'),
  aceUpYourSleeve('Ace Up Your Sleeve', 'Complete all games on Hard.'),
  birdie('Birdie',
      'Win a Hard Golf Solitaire game with at least 1 card left in the draw pile.'),
  cleanSweep(
      'Clean Sweep', 'Win a Hard Solitaire game without undoing any moves.'),
  perfectPlanning('Perfect Planning',
      'Win a Hard Free Cell game without undoing any moves.'),
  peakPerformance('Peak Performance',
      'In Tri-Peaks, achieve a streak of 15 consecutive cards.'),
  summitMaster('Summit Master',
      'Win a Tri-Peaks game with at least 10 cards remaining in the stock.'),
  silkRoad('Silk Road',
      'In Spider Solitaire, clear four suit sequences before dealing from the stock.'),
  eightfoldMaster('Eightfold Master',
      'Win a 4-suit Spider Solitaire game without undoing any moves.'),
  desertRunner('Desert Runner',
      'In Pyramid Solitaire, remove 10 pyramid cards before drawing from the stock.'),
  sunDial('Sun Dial',
      'Win a Pyramid Solitaire game with at least 10 cards remaining in the stock.');

  final String name;
  final String description;

  const Achievement(this.name, this.description);

  int? getCurrentProgress({required SaveState saveState}) => switch (this) {
        Achievement.fullHouse => saveState.gameStates
            .where(
                (game, state) => state.states.containsKey(Difficulty.classic))
            .length,
        Achievement.royalFlush => saveState.gameStates
            .where((game, state) => state.states.containsKey(Difficulty.royal))
            .length,
        Achievement.aceUpYourSleeve => saveState.gameStates
            .where((game, state) => state.states.containsKey(Difficulty.ace))
            .length,
        Achievement.stackTheDeck => saveState.winStreak,
        _ => null,
      };

  int? getProgressMax() => switch (this) {
        Achievement.fullHouse ||
        Achievement.royalFlush ||
        Achievement.aceUpYourSleeve =>
          Game.values.length,
        Achievement.stackTheDeck => 3,
        _ => null,
      };
}
