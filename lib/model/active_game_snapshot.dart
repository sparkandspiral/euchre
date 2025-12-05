import 'package:json_annotation/json_annotation.dart';
import 'package:solitaire/model/difficulty.dart';
import 'package:solitaire/model/game.dart';

part 'active_game_snapshot.g.dart';

@JsonSerializable()
class ActiveGameSnapshot {
  final Game game;
  final Difficulty difficulty;
  final bool isDaily;
  final int? shuffleSeed;
  final Map<String, dynamic> state;
  final DateTime updatedAt;
  final int elapsedMilliseconds;

  const ActiveGameSnapshot({
    required this.game,
    required this.difficulty,
    required this.state,
    required this.updatedAt,
    required this.elapsedMilliseconds,
    this.isDaily = false,
    this.shuffleSeed,
  });

  factory ActiveGameSnapshot.fromJson(Map<String, dynamic> json) =>
      _$ActiveGameSnapshotFromJson(json);

  Map<String, dynamic> toJson() => _$ActiveGameSnapshotToJson(this);

  ActiveGameSnapshot copyWith({
    Map<String, dynamic>? state,
    DateTime? updatedAt,
    int? elapsedMilliseconds,
    bool? isDaily,
    int? shuffleSeed,
  }) {
    return ActiveGameSnapshot(
      game: game,
      difficulty: difficulty,
      state: state ?? this.state,
      updatedAt: updatedAt ?? this.updatedAt,
      elapsedMilliseconds: elapsedMilliseconds ?? this.elapsedMilliseconds,
      isDaily: isDaily ?? this.isDaily,
      shuffleSeed: shuffleSeed ?? this.shuffleSeed,
    );
  }
}


