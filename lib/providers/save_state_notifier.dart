import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:euchre/model/euchre_game_state.dart';
import 'package:euchre/model/save_state.dart';
import 'package:euchre/utils/game_state_codec.dart';

part 'save_state_notifier.g.dart';

const _saveStateKey = 'euchre_save_state';
const _savedGameKey = 'euchre_saved_game';

@Riverpod(keepAlive: true)
class SaveStateNotifier extends _$SaveStateNotifier {
  @override
  Future<EuchreSaveState?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_saveStateKey);
    if (json == null) return EuchreSaveState();
    try {
      return EuchreSaveState.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return EuchreSaveState();
    }
  }

  Future<void> updateState(EuchreSaveState Function(EuchreSaveState) updater) async {
    final current = state.valueOrNull ?? EuchreSaveState();
    final updated = updater(current);
    state = AsyncData(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveStateKey, jsonEncode(updated.toJson()));
  }

  Future<void> recordGameResult({required bool won}) async {
    await updateState((s) => s.copyWith(
          gamesPlayed: s.gamesPlayed + 1,
          gamesWon: won ? s.gamesWon + 1 : s.gamesWon,
        ));
  }

  Future<void> completeLesson(String lessonId) async {
    await updateState((s) => s.copyWith(
          completedLessons: {...s.completedLessons, lessonId},
        ));
  }

  Future<void> saveGame(EuchreGameState gameState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _savedGameKey, jsonEncode(encodeGameState(gameState)));
  }

  Future<void> clearSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedGameKey);
  }

  Future<EuchreGameState?> loadSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_savedGameKey);
    if (json == null) return null;
    try {
      return decodeGameState(
          jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_savedGameKey);
      return null;
    }
  }
}
