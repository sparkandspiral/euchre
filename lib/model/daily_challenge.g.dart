// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_challenge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyChallengeProgress _$DailyChallengeProgressFromJson(
        Map<String, dynamic> json) =>
    DailyChallengeProgress(
      lastPuzzleNumber: (json['lastPuzzleNumber'] as num?)?.toInt(),
      lastCompletedAt: json['lastCompletedAt'] == null
          ? null
          : DateTime.parse(json['lastCompletedAt'] as String),
      lastBestTimeCs: (json['lastBestTimeCs'] as num?)?.toInt(),
      lastSubmittedPuzzleNumber:
          (json['lastSubmittedPuzzleNumber'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DailyChallengeProgressToJson(
        DailyChallengeProgress instance) =>
    <String, dynamic>{
      'lastPuzzleNumber': instance.lastPuzzleNumber,
      'lastCompletedAt': instance.lastCompletedAt?.toIso8601String(),
      'lastBestTimeCs': instance.lastBestTimeCs,
      'lastSubmittedPuzzleNumber': instance.lastSubmittedPuzzleNumber,
    };
