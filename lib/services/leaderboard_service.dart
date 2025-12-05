import 'dart:async';
import 'dart:math';

import 'package:badword_guard/badword_guard.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:solitaire/model/game.dart';
import 'package:solitaire/model/score_data.dart';

final leaderboardServiceProvider =
    Provider<LeaderboardService>((_) => LeaderboardService());

class OperationResult {
  final bool success;
  final String message;

  const OperationResult({required this.success, required this.message});
}

class LeaderboardService {
  LeaderboardService() {
    try {
      _leaderboardClient = SupabaseClient(_supabaseUrl, _supabaseAnonKey);
    } catch (error, stackTrace) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stackTrace);
      }
    }
  }

  static const _supabaseUrl = 'https://sgbjxmdlvipiirmiklai.supabase.co';
  static const _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnYmp4bWRsdmlwaWlybWlrbGFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDcyMzAxOTcsImV4cCI6MjA2MjgwNjE5N30.DqiQF-CzDErIvIJBkHiXNgax4F5AG1YgVrxl_ZVqZ7I';

  late SupabaseClient _leaderboardClient;

  Future<SupabaseClient> _clientWithDeviceHeader() async {
    final deviceId = await _getDeviceId();
    return SupabaseClient(
      _supabaseUrl,
      _supabaseAnonKey,
      headers: {'x-device-id': deviceId},
    );
  }

  Future<List<ScoreData>> getLeaderboard(
    Game game,
    int levelNumber, {
    int maxResults = 30,
  }) async {
    final response = await _leaderboardClient
        .from('scores')
        .select(
          '''
          id,
          user_id,
          time,
          game,
          level_number,
          users!inner(id, display_name)
        ''',
        )
        .eq('game', _gameName(game))
        .eq('level_number', levelNumber)
        .order('time', ascending: true)
        .limit(maxResults);

    final scores = (response as List<dynamic>).cast<Map<String, dynamic>>();
    int rank = 1;
    return scores.map((row) {
      return ScoreData(
        rank: rank++,
        rawScore: row['time'] as int,
        displayName: (row['users']?['display_name'] as String?) ?? 'Unknown',
        userId: row['users']?['id'] as int? ?? 0,
      );
    }).toList();
  }

  Future<ScoreData?> getCurrentRanking(Game game, int levelNumber) async {
    final userId = await _getStoredUserId();
    if (userId == null) return null;

    final single = await _leaderboardClient
        .from('scores')
        .select(
          '''
          id,
          user_id,
          time,
          game,
          level_number,
          users!inner(id, display_name)
        ''',
        )
        .eq('user_id', userId)
        .eq('game', _gameName(game))
        .eq('level_number', levelNumber)
        .maybeSingle();

    if (single == null) {
      return null;
    }

    final score = single['time'] as int;
    final betterScores = await _leaderboardClient
        .from('scores')
        .select('time')
        .eq('game', _gameName(game))
        .eq('level_number', levelNumber)
        .lt('time', score);
    final rank = (betterScores as List).length + 1;
    return ScoreData(
      rank: rank,
      rawScore: score,
      displayName: (single['users']?['display_name'] as String?) ?? 'You',
      userId: single['users']?['id'] as int? ?? userId,
    );
  }

  Future<bool> submitScore({
    required BuildContext context,
    required Game game,
    required int levelNumber,
    required Duration duration,
  }) async {
    try {
      final userId = await _getOrCreateUserId(context);
      final centiseconds = max(1, duration.inMilliseconds ~/ 10);
      await _leaderboardClient.from('scores').insert({
        'level_number': levelNumber,
        'time': centiseconds,
        'user_id': userId,
        'game': _gameName(game),
      });
      return true;
    } catch (error, stackTrace) {
      if (!kIsWeb) {
        try {
          FirebaseCrashlytics.instance
              .recordError(error, stackTrace, fatal: false);
        } catch (_) {}
      }
      return false;
    }
  }

  Future<OperationResult> updateDisplayName(
      BuildContext context, String newName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sanitizedName = newName.trim();

      if (sanitizedName.isEmpty) {
        return const OperationResult(
            success: false, message: 'Display name cannot be empty');
      }

      if (sanitizedName.length < 3) {
        return const OperationResult(
            success: false, message: 'Name must be at least 3 characters long');
      }

      final checker = LanguageChecker();
      if (checker.containsBadLanguage(sanitizedName)) {
        return const OperationResult(
            success: false, message: 'Please choose a different name');
      }

      final validCharacters = RegExp(r'^[a-zA-Z0-9_ ]+$');
      if (!validCharacters.hasMatch(sanitizedName)) {
        return const OperationResult(
          success: false,
          message:
              'Name can only contain letters, numbers, spaces, and underscores.',
        );
      }

      final current = prefs.getString('display_name');
      if (current != null && current == sanitizedName) {
        return const OperationResult(
            success: true, message: 'Display name unchanged');
      }

      final now = DateTime.now().toUtc();
      final dayKey =
          'display_name_updates_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final currentCount = prefs.getInt(dayKey) ?? 0;
      if (currentCount >= 2) {
        return const OperationResult(
          success: false,
          message: 'You can change your name at most twice per day.',
        );
      }

      int? userId = await _getStoredUserId();
      if (userId == null) {
        userId = await _createUserRecord(
          displayName: sanitizedName,
        );
        await prefs.setInt('user_id', userId);
      } else {
        final client = await _clientWithDeviceHeader();
        final updated = await client
            .from('users')
            .update({
              'display_name': sanitizedName,
              'updated_at': now.toIso8601String(),
            })
            .eq('id', userId)
            .select('id')
            .maybeSingle();

        if (updated == null) {
          return const OperationResult(
              success: false,
              message: 'Could not update name. Please try again later.');
        }
      }

      await prefs.setString('display_name', sanitizedName);
      await prefs.setInt(dayKey, currentCount + 1);
      return const OperationResult(
          success: true, message: 'Display name updated');
    } catch (error, stackTrace) {
      if (!kIsWeb) {
        try {
          FirebaseCrashlytics.instance
              .recordError(error, stackTrace, fatal: false);
        } catch (_) {}
      }
      return const OperationResult(
          success: false, message: 'Failed to update name');
    }
  }

  Future<String> ensureDisplayName(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('display_name');
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }

    if (!context.mounted) {
      final fallback = 'Player ${_anonymousSuffix()}';
      await prefs.setString('display_name', fallback);
      return fallback;
    }

    final prompted = await _promptForDisplayName(context);
    if (prompted != null && prompted.isNotEmpty) {
      await prefs.setString('display_name', prompted);
      return prompted;
    }

    final fallback = 'Player ${_anonymousSuffix()}';
    await prefs.setString('display_name', fallback);
    return fallback;
  }

  Future<String?> getStoredDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('display_name');
  }

  Future<int?> _getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  Future<int> _getOrCreateUserId(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getInt('user_id');
    if (existing != null) {
      return existing;
    }

    if (!context.mounted) {
      final fallback = 'Player ${_anonymousSuffix()}';
      final userId = await _createUserRecord(displayName: fallback);
      await prefs.setInt('user_id', userId);
      return userId;
    }

    final displayName = await ensureDisplayName(context);
    final userId = await _createUserRecord(displayName: displayName);
    await prefs.setInt('user_id', userId);
    return userId;
  }

  Future<int> _createUserRecord({required String displayName}) async {
    final deviceId = await _getDeviceId();
    final response = await _leaderboardClient
        .from('users')
        .insert({'device_id': deviceId, 'display_name': displayName})
        .select('id')
        .single();
    return response['id'] as int;
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('app_uuid');
    if (existing != null) {
      return existing;
    }

    final uuid = const Uuid().v4();
    await prefs.setString('app_uuid', uuid);
    return uuid;
  }

  Future<String?> _promptForDisplayName(BuildContext context) async {
    if (!context.mounted) return null;
    final controller = TextEditingController();
    final checker = LanguageChecker();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set Your Display Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter display name'),
            maxLength: 25,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!dialogContext.mounted) return;
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('Display name cannot be empty')),
                  );
                  return;
                }
                if (name.length < 3) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Name must be at least 3 characters long')),
                  );
                  return;
                }
                if (checker.containsBadLanguage(name)) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('Please choose a different name')),
                  );
                  return;
                }
                final validCharacters = RegExp(r'^[a-zA-Z0-9_ ]+$');
                if (!validCharacters.hasMatch(name)) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Name can only contain letters, numbers, spaces, and underscores.')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(name);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _gameName(Game game) => 'cards_${game.name}';

  String _anonymousSuffix() {
    const adjectives = [
      'Swift',
      'Clever',
      'Mighty',
      'Silent',
      'Wise',
      'Brave',
      'Gentle',
      'Fierce',
      'Noble',
      'Calm',
      'Wild',
      'Proud',
      'Loyal',
      'Quick',
      'Bright',
    ];
    const animals = [
      'Fox',
      'Owl',
      'Bear',
      'Wolf',
      'Hawk',
      'Lynx',
      'Deer',
      'Hare',
      'Frog',
      'Bat',
      'Mole',
      'Dove',
      'Swan',
      'Crab',
      'Bee',
    ];
    final random = Random();
    final adjective = adjectives[random.nextInt(adjectives.length)];
    final animal = animals[random.nextInt(animals.length)];
    return '$adjective $animal';
  }
}

