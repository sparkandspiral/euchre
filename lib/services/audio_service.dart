import 'package:audioplayers/audioplayers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:euchre/providers/save_state_notifier.dart';

part 'audio_service.g.dart';

class AudioService {
  AudioService(this.ref) {
    ref.onDispose(() async {
      for (final pool in _pools.values) {
        await pool.dispose();
      }
    });
  }

  final Ref ref;
  final Map<String, _SoundPool> _pools = {};

  void playPlace() => _playAudio('sounds/place.wav');
  void playDraw() => _playAudio('sounds/draw.wav');
  void playWin() => _playAudio('sounds/win.wav');

  Future<void> _playAudio(String path) async {
    final volume = await _getVolume();
    if (volume == null || volume == 0) {
      return;
    }

    final pool = _pools.putIfAbsent(
      path,
      () => _SoundPool(
        poolSize: path == 'sounds/win.wav' ? 2 : 4,
      ),
    );

    await pool.play(path, volume);
  }

  Future<double?> _getVolume() async {
    final asyncSaveState = ref.read(saveStateNotifierProvider);
    final saveState = asyncSaveState.valueOrNull ??
        await ref.read(saveStateNotifierProvider.future);
    return saveState?.volume;
  }
}

class _SoundPool {
  _SoundPool({required int poolSize})
      : _players = List.generate(poolSize, (_) => AudioPlayer());

  final List<AudioPlayer> _players;
  int _nextIndex = 0;

  AudioPlayer get _nextPlayer {
    final player = _players[_nextIndex];
    _nextIndex = (_nextIndex + 1) % _players.length;
    return player;
  }

  Future<void> play(String assetPath, double volume) async {
    final player = _nextPlayer;
    await player.stop();
    await player.setVolume(volume);
    await player.play(
      AssetSource(assetPath),
      mode: PlayerMode.lowLatency,
      volume: volume,
    );
  }

  Future<void> dispose() async {
    for (final player in _players) {
      await player.stop();
      await player.dispose();
    }
  }
}

@Riverpod(keepAlive: true)
AudioService audioService(Ref ref) => AudioService(ref);
