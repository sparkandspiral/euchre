import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:solitaire/games/solitaire.dart';

/// Lightweight harness that stresses Solitaire state's history handling.
///
/// It repeatedly calls [SolitaireState.copyWith] to simulate a player making
/// thousands of moves. The work is wrapped in a [TimelineTask] so the Flutter
/// profiler can capture it easily when launched with the
/// `PROFILE_HISTORY_STRESS` define.
class HistoryStressHarness extends StatefulWidget {
  const HistoryStressHarness({super.key});

  @override
  State<HistoryStressHarness> createState() => _HistoryStressHarnessState();
}

class _HistoryStressHarnessState extends State<HistoryStressHarness> {
  static const int _iterations = 12000;
  static const int _chunkSize = 500;

  String _status = 'Waiting to start profiling run…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStress());
  }

  Future<void> _runStress() async {
    setState(() => _status = 'Running history stress test…');

    var state =
        SolitaireState.getInitialState(drawAmount: 1, acesAtBottom: false);
    final task = TimelineTask()..start('solitaire_history_stress');

    final stopwatch = Stopwatch();
    for (var iter = 0; iter < _iterations; iter += _chunkSize) {
      stopwatch
        ..reset()
        ..start();

      for (var i = 0; i < _chunkSize && iter + i < _iterations; i++) {
        state = state.copyWith();
      }

      stopwatch.stop();
      final chunk = (iter ~/ _chunkSize) + 1;
      // Log chunk timings so we can see slowdown directly in the console output.
      // ignore: avoid_print
      print('Chunk $chunk took ${stopwatch.elapsedMilliseconds}ms');
    }

    task.finish(arguments: {
      'iterations': _iterations,
      'historyLength': state.history.length,
    });

    setState(() => _status = 'Stress run complete. Check timeline traces.');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            _status,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

void runHistoryStressHarness() {
  runApp(const HistoryStressHarness());
}
