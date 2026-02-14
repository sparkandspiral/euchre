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

  const EuchreSaveState({
    this.cardBack = CardBack.redStripes,
    this.background = Background.green,
    this.volume = 0.5,
    this.difficulty = BotDifficulty.medium,
    this.gamesWon = 0,
    this.gamesPlayed = 0,
    this.coachMode = false,
  });

  EuchreSaveState copyWith({
    CardBack? cardBack,
    Background? background,
    double? volume,
    BotDifficulty? difficulty,
    int? gamesWon,
    int? gamesPlayed,
    bool? coachMode,
  }) {
    return EuchreSaveState(
      cardBack: cardBack ?? this.cardBack,
      background: background ?? this.background,
      volume: volume ?? this.volume,
      difficulty: difficulty ?? this.difficulty,
      gamesWon: gamesWon ?? this.gamesWon,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      coachMode: coachMode ?? this.coachMode,
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
    );
  }
}
