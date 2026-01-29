import 'package:json_annotation/json_annotation.dart';
import 'package:solitaire/model/achievement.dart';
import 'package:solitaire/model/background.dart';
import 'package:solitaire/model/card_back.dart';
import 'package:solitaire/model/daily_challenge.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/difficulty_game_state.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/model/hint.dart';
import 'package:solitaire/model/active_game_snapshot.dart';
import 'package:solitaire/model/game_state.dart';
import 'package:utils/utils.dart';

part 'save_state.g.dart';

@JsonSerializable()
class SaveState {
  final Map<Game, GameState> gameStates;

  @JsonKey(defaultValue: <Achievement>{})
  final Set<Achievement> achievements;

  final Game? lastGamePlayed;

  @JsonKey(defaultValue: {})
  final Map<Game, Difficulty> lastPlayedGameDifficulties;

  @JsonKey(defaultValue: 0)
  final int winStreak;

  @JsonKey(defaultValue: Background.green)
  final Background background;

  @JsonKey(defaultValue: CardBack.redStripes)
  final CardBack cardBack;

  @JsonKey(defaultValue: 1.0)
  final double volume;

  @JsonKey(defaultValue: true)
  final bool enableAutoMove;

  @JsonKey(defaultValue: defaultHintCount)
  final int hints;

  @JsonKey(defaultValue: {})
  final Map<Game, DailyChallengeProgress> dailyChallengeProgress;

  @JsonKey(defaultValue: {})
  final Map<Game, bool> tutorialPromptsSeen;

  @JsonKey(defaultValue: {})
  final Map<Game, ActiveGameSnapshot> activeGames;

  @JsonKey(defaultValue: false)
  final bool adsRemoved;

  @JsonKey(defaultValue: false)
  final bool unlimitedHints;

  const SaveState({
    required this.gameStates,
    required this.achievements,
    required this.lastGamePlayed,
    required this.lastPlayedGameDifficulties,
    required this.winStreak,
    required this.background,
    required this.cardBack,
    required this.volume,
    required this.enableAutoMove,
    required this.hints,
    required this.dailyChallengeProgress,
    required this.tutorialPromptsSeen,
    required this.activeGames,
    required this.adsRemoved,
    required this.unlimitedHints,
  });

  const SaveState.empty()
      : gameStates = const {},
        achievements = const {},
        lastGamePlayed = null,
        lastPlayedGameDifficulties = const {},
        winStreak = 0,
        background = Background.green,
        cardBack = CardBack.redStripes,
        volume = 1,
        enableAutoMove = true,
        hints = defaultHintCount,
        dailyChallengeProgress = const {},
        tutorialPromptsSeen = const {},
        activeGames = const {},
        adsRemoved = false,
        unlimitedHints = false;

  factory SaveState.fromJson(Map<String, dynamic> json) =>
      _$SaveStateFromJson(json);
  Map<String, dynamic> toJson() => _$SaveStateToJson(this);

  GameState getOrDefault(Game game) =>
      gameStates[game] ?? GameState(states: {});

  SaveState withGameCompleted({
    required Game game,
    required Difficulty difficulty,
    required Duration duration,
  }) =>
      copyWith(
        gameStates: {
          ...gameStates,
          game: getOrDefault(game)
              .withCompleted(difficulty: difficulty, duration: duration),
        },
        winStreak: winStreak + 1,
      );

  SaveState withGameStarted(
          {required Game game, required Difficulty difficulty}) =>
      withDefaultDifficulty(game: game, difficulty: difficulty)
          .copyWith(lastGamePlayed: game);

  SaveState withDefaultDifficulty(
          {required Game game, required Difficulty difficulty}) =>
      copyWith(
        lastPlayedGameDifficulties: {
          ...lastPlayedGameDifficulties,
          game: difficulty,
        },
      );

  SaveState withCloseOrRestart() => copyWith(winStreak: 0);

  SaveState withDailyCompletion({
    required Game game,
    required int puzzleNumber,
    required Duration duration,
    bool submitted = false,
  }) {
    final current = dailyChallengeProgress[game];
    final isSamePuzzle = current?.lastPuzzleNumber == puzzleNumber;
    final newCentiseconds = duration.inMilliseconds ~/ 10;
    final lastBest = current?.lastBestTimeCs;
    final bestForPuzzle =
        isSamePuzzle && lastBest != null && lastBest < newCentiseconds
            ? lastBest
            : newCentiseconds;
    final updated = (current ?? const DailyChallengeProgress()).copyWith(
      lastPuzzleNumber: puzzleNumber,
      lastCompletedAt: DateTime.now().toUtc(),
      lastBestTimeCs: bestForPuzzle,
      lastSubmittedPuzzleNumber:
          submitted ? puzzleNumber : current?.lastSubmittedPuzzleNumber,
    );

    return copyWith(
      dailyChallengeProgress: {
        ...dailyChallengeProgress,
        game: updated,
      },
    );
  }

  SaveState withDailySubmission({required Game game, required int puzzleNumber}) {
    final current = dailyChallengeProgress[game];
    final updated = (current ?? const DailyChallengeProgress()).copyWith(
      lastSubmittedPuzzleNumber: puzzleNumber,
    );

    return copyWith(
      dailyChallengeProgress: {
        ...dailyChallengeProgress,
        game: updated,
      },
    );
  }

  SaveState withActiveGame(ActiveGameSnapshot snapshot) => copyWith(
        activeGames: {
          ...activeGames,
          snapshot.game: snapshot,
        },
      );

  SaveState withTutorialPromptSeen(Game game) => copyWith(
        tutorialPromptsSeen: {
          ...tutorialPromptsSeen,
          game: true,
        },
      );

  SaveState withoutActiveGame(Game game) => copyWith(
        activeGames: {...activeGames}..remove(game),
      );

  SaveState withBackground({required Background background}) =>
      copyWith(background: background);
  SaveState withCardBack({required CardBack cardBack}) =>
      copyWith(cardBack: cardBack);
  SaveState withVolume({required double volume}) => copyWith(volume: volume);
  SaveState withAutoMoveEnabled({required bool enableAutoMove}) =>
      copyWith(enableAutoMove: enableAutoMove);
  SaveState withAchievement({required Achievement achievement}) =>
      copyWith(achievements: {...achievements, achievement});
  SaveState withAchievementRemoved({required Achievement achievement}) =>
      copyWith(achievements: {...achievements}..remove(achievement));

  SaveState withHintsAdded(int amount) {
    if (amount <= 0) {
      return this;
    }
    return copyWith(hints: hints + amount);
  }

  SaveState withHintSpent() {
    if (hints <= 0) {
      return this;
    }
    return copyWith(hints: hints - 1);
  }

  SaveState withCheatCode() => copyWith(
        gameStates: Game.values.mapToMap((value) => MapEntry(
              value,
              GameState(
                states: Difficulty.values.mapToMap(
                  (difficulty) => MapEntry(
                    difficulty,
                    DifficultyGameState(
                        fastestGame: Duration(minutes: 5), gamesWon: 1),
                  ),
                ),
              ),
            )),
        achievements: Achievement.values.toSet(),
      );

  SaveState copyWith({
    Map<Game, GameState>? gameStates,
    Set<Achievement>? achievements,
    Game? lastGamePlayed,
    Map<Game, Difficulty>? lastPlayedGameDifficulties,
    int? winStreak,
    Background? background,
    CardBack? cardBack,
    double? volume,
    bool? enableAutoMove,
    int? hints,
    Map<Game, DailyChallengeProgress>? dailyChallengeProgress,
    Map<Game, bool>? tutorialPromptsSeen,
    Map<Game, ActiveGameSnapshot>? activeGames,
    bool? adsRemoved,
    bool? unlimitedHints,
  }) {
    return SaveState(
      gameStates: gameStates ?? this.gameStates,
      achievements: achievements ?? this.achievements,
      lastGamePlayed: lastGamePlayed ?? this.lastGamePlayed,
      lastPlayedGameDifficulties:
          lastPlayedGameDifficulties ?? this.lastPlayedGameDifficulties,
      winStreak: winStreak ?? this.winStreak,
      background: background ?? this.background,
      cardBack: cardBack ?? this.cardBack,
      volume: volume ?? this.volume,
      enableAutoMove: enableAutoMove ?? this.enableAutoMove,
      hints: hints ?? this.hints,
      dailyChallengeProgress:
          dailyChallengeProgress ?? this.dailyChallengeProgress,
      tutorialPromptsSeen: tutorialPromptsSeen ?? this.tutorialPromptsSeen,
      activeGames: activeGames ?? this.activeGames,
      adsRemoved: adsRemoved ?? this.adsRemoved,
      unlimitedHints: unlimitedHints ?? this.unlimitedHints,
    );
  }
}
