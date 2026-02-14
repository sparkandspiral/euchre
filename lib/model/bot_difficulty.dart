enum BotDifficulty {
  easy,
  medium,
  hard;

  String get displayName => switch (this) {
        BotDifficulty.easy => 'Easy',
        BotDifficulty.medium => 'Medium',
        BotDifficulty.hard => 'Hard',
      };

  String get description => switch (this) {
        BotDifficulty.easy => 'Bots play randomly from legal cards',
        BotDifficulty.medium => 'Bots use basic strategy',
        BotDifficulty.hard => 'Bots track cards and play strategically',
      };

  Duration get thinkDelay => switch (this) {
        BotDifficulty.easy => Duration(milliseconds: 400),
        BotDifficulty.medium => Duration(milliseconds: 700),
        BotDifficulty.hard => Duration(milliseconds: 1000),
      };
}
