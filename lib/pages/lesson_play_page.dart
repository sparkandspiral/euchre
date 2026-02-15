import 'package:card_game/card_game.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:euchre/data/lessons.dart';
import 'package:euchre/model/game_phase.dart';
import 'package:euchre/model/lesson.dart';
import 'package:euchre/model/player.dart';
import 'package:euchre/providers/save_state_notifier.dart';
import 'package:euchre/widgets/bid_overlay.dart';
import 'package:euchre/widgets/euchre_table.dart';
import 'package:euchre/widgets/lesson_result_overlay.dart';
import 'package:euchre/widgets/trump_indicator.dart';

class LessonPlayPage extends ConsumerStatefulWidget {
  final Lesson lesson;

  const LessonPlayPage({super.key, required this.lesson});

  @override
  ConsumerState<LessonPlayPage> createState() => _LessonPlayPageState();
}

class _LessonPlayPageState extends ConsumerState<LessonPlayPage> {
  bool? _result; // null = not answered, true = correct, false = incorrect

  Lesson get _lesson => widget.lesson;

  void _reset() {
    setState(() => _result = null);
  }

  void _handleCardTap(SuitedCard card) {
    if (_result != null) return;

    final correct = _lesson.correctCard != null &&
        card.suit == _lesson.correctCard!.suit &&
        card.value.toString() == _lesson.correctCard!.value.toString();

    if (correct) {
      ref
          .read(saveStateNotifierProvider.notifier)
          .completeLesson(_lesson.id);
    }

    setState(() => _result = correct);
  }

  void _handleBidRound1(bool orderUp, {bool goAlone = false}) {
    if (_result != null) return;

    final correct = _lesson.correctBidOrderUp == orderUp;

    if (correct) {
      ref
          .read(saveStateNotifierProvider.notifier)
          .completeLesson(_lesson.id);
    }

    setState(() => _result = correct);
  }

  void _handleBidRound2(CardSuit? suit) {
    if (_result != null) return;

    final correct = _lesson.correctBidSuit == suit;

    if (correct) {
      ref
          .read(saveStateNotifierProvider.notifier)
          .completeLesson(_lesson.id);
    }

    setState(() => _result = correct);
  }

  Lesson? get _nextLesson {
    final idx = allLessons.indexWhere((l) => l.id == _lesson.id);
    if (idx < 0 || idx >= allLessons.length - 1) return null;
    return allLessons[idx + 1];
  }

  @override
  Widget build(BuildContext context) {
    final round = _lesson.scenario;
    final isBidding = _lesson.objective == LessonObjective.makeBidDecision;

    return Scaffold(
      backgroundColor: Color(0xFF1B5E20),
      appBar: AppBar(
        title: Text(_lesson.title, style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF0A2340),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                // Instruction banner
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lesson.description,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (round.trumpSuit != null && !isBidding) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            SizedBox(width: 24),
                            TrumpIndicator(suit: round.trumpSuit!),
                            SizedBox(width: 8),
                            Text(
                              'Tricks: ${round.tricksWon[Team.playerTeam] ?? 0} - ${round.tricksWon[Team.opponentTeam] ?? 0}',
                              style:
                                  TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Card table
                Expanded(
                  child: EuchreTable(
                    round: round,
                    onCardTap: isBidding ? null : _handleCardTap,
                  ),
                ),
              ],
            ),
          ),

          // Bidding overlay for bid lessons
          if (isBidding && _result == null)
            BidOverlay(
              round: round,
              onBidRound1: _handleBidRound1,
              onBidRound2: _handleBidRound2,
            ),

          // Result overlay
          if (_result != null)
            LessonResultOverlay(
              isCorrect: _result!,
              explanation: _lesson.explanation,
              onTryAgain: _reset,
              onNextLesson: _nextLesson != null
                  ? () {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (_) =>
                            LessonPlayPage(lesson: _nextLesson!),
                      ));
                    }
                  : null,
            ),
        ],
      ),
    );
  }
}
