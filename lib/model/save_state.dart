import 'package:euchre/model/background.dart';
import 'package:euchre/model/bot_difficulty.dart';
import 'package:euchre/model/card_back.dart';

class EuchreSaveState {
  final CardBack cardBack;
  final Background background;
  final double volume;
  final BotDifficulty difficulty;
  final int gamesWon;
  final int gamesPlayed;
  final bool coachMode;
  final bool practiceMode;
  final double playSpeed;
  final Set<String> completedLessons;

  const EuchreSaveState({
    this.cardBack = CardBack.redStripes,
    this.background = Background.green,
    this.volume = 0.5,
    this.difficulty = BotDifficulty.medium,
    this.gamesWon = 0,
    this.gamesPlayed = 0,
    this.coachMode = false,
    this.practiceMode = false,
    this.playSpeed = 1.0,
    this.completedLessons = const {},
  });

  EuchreSaveState copyWith({
    CardBack? cardBack,
    Background? background,
    double? volume,
    BotDifficulty? difficulty,
    int? gamesWon,
    int? gamesPlayed,
    bool? coachMode,
    bool? practiceMode,
    double? playSpeed,
    Set<String>? completedLessons,
  }) {
    return EuchreSaveState(
      cardBack: cardBack ?? this.cardBack,
      background: background ?? this.background,
      volume: volume ?? this.volume,
      difficulty: difficulty ?? this.difficulty,
      gamesWon: gamesWon ?? this.gamesWon,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      coachMode: coachMode ?? this.coachMode,
      practiceMode: practiceMode ?? this.practiceMode,
      playSpeed: playSpeed ?? this.playSpeed,
      completedLessons: completedLessons ?? this.completedLessons,
    );
  }

  Map<String, dynamic> toJson() => {
        'cardBack': cardBack.index,
        'background': background.index,
        'volume': volume,
        'difficulty': difficulty.index,
        'gamesWon': gamesWon,
        'gamesPlayed': gamesPlayed,
        'coachMode': coachMode,
        'practiceMode': practiceMode,
        'playSpeed': playSpeed,
        'completedLessons': completedLessons.toList(),
      };

  factory EuchreSaveState.fromJson(Map<String, dynamic> json) {
    return EuchreSaveState(
      cardBack: CardBack.values[json['cardBack'] as int? ?? 0],
      background: Background.values[json['background'] as int? ?? 0],
      volume: (json['volume'] as num?)?.toDouble() ?? 0.5,
      difficulty: BotDifficulty.values[json['difficulty'] as int? ?? 1],
      gamesWon: json['gamesWon'] as int? ?? 0,
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      coachMode: json['coachMode'] as bool? ?? false,
      practiceMode: json['practiceMode'] as bool? ?? false,
      playSpeed: (json['playSpeed'] as num?)?.toDouble() ?? 1.0,
      completedLessons: (json['completedLessons'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          {},
    );
  }
}
