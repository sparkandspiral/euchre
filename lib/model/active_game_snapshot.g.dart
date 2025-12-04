// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_game_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActiveGameSnapshot _$ActiveGameSnapshotFromJson(Map<String, dynamic> json) =>
    ActiveGameSnapshot(
      game: $enumDecode(_$GameEnumMap, json['game']),
      difficulty: $enumDecode(_$DifficultyEnumMap, json['difficulty']),
      state: json['state'] as Map<String, dynamic>,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      elapsedMilliseconds: (json['elapsedMilliseconds'] as num).toInt(),
      isDaily: json['isDaily'] as bool? ?? false,
      shuffleSeed: (json['shuffleSeed'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ActiveGameSnapshotToJson(ActiveGameSnapshot instance) =>
    <String, dynamic>{
      'game': _$GameEnumMap[instance.game]!,
      'difficulty': _$DifficultyEnumMap[instance.difficulty]!,
      'isDaily': instance.isDaily,
      'shuffleSeed': instance.shuffleSeed,
      'state': instance.state,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'elapsedMilliseconds': instance.elapsedMilliseconds,
    };

const _$GameEnumMap = {
  Game.golf: 'golf',
  Game.klondike: 'klondike',
  Game.freeCell: 'freeCell',
  Game.spider: 'spider',
  Game.pyramid: 'pyramid',
  Game.triPeaks: 'triPeaks',
};

const _$DifficultyEnumMap = {
  Difficulty.classic: 'classic',
  Difficulty.royal: 'royal',
  Difficulty.ace: 'ace',
};
