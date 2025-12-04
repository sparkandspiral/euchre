import 'package:json_annotation/json_annotation.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';

part 'daily_challenge.g.dart';

class DailyChallengeConfig {
  final Game game;
  final int puzzleNumber;
  final DateTime date;
  final int shuffleSeed;
  final Difficulty difficulty;

  const DailyChallengeConfig({
    required this.game,
    required this.puzzleNumber,
    required this.date,
    required this.shuffleSeed,
    this.difficulty = Difficulty.royal,
  });

  String get formattedLabel =>
      'Day ${puzzleNumber.toString().padLeft(3, '0')}';
}

@JsonSerializable()
class DailyChallengeProgress {
  final int? lastPuzzleNumber;
  final DateTime? lastCompletedAt;
  final int? lastBestTimeCs;
  final int? lastSubmittedPuzzleNumber;

  const DailyChallengeProgress({
    this.lastPuzzleNumber,
    this.lastCompletedAt,
    this.lastBestTimeCs,
    this.lastSubmittedPuzzleNumber,
  });

  factory DailyChallengeProgress.fromJson(Map<String, dynamic> json) =>
      _$DailyChallengeProgressFromJson(json);

  Map<String, dynamic> toJson() => _$DailyChallengeProgressToJson(this);

  DailyChallengeProgress copyWith({
    int? lastPuzzleNumber,
    DateTime? lastCompletedAt,
    int? lastBestTimeCs,
    int? lastSubmittedPuzzleNumber,
  }) {
    return DailyChallengeProgress(
      lastPuzzleNumber: lastPuzzleNumber ?? this.lastPuzzleNumber,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      lastBestTimeCs: lastBestTimeCs ?? this.lastBestTimeCs,
      lastSubmittedPuzzleNumber:
          lastSubmittedPuzzleNumber ?? this.lastSubmittedPuzzleNumber,
    );
  }

  bool isCompleted(int puzzleNumber) =>
      lastPuzzleNumber != null && lastPuzzleNumber == puzzleNumber;

  bool hasSubmitted(int puzzleNumber) =>
      lastSubmittedPuzzleNumber != null &&
      lastSubmittedPuzzleNumber == puzzleNumber;
}


