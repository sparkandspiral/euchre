import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:euchre/model/bot_difficulty.dart';
import 'package:euchre/model/card_back.dart';
import 'package:euchre/pages/game_page.dart';
import 'package:euchre/pages/lessons_page.dart';
import 'package:euchre/pages/settings_page.dart';
import 'package:euchre/pages/strategy_page.dart';
import 'package:euchre/providers/save_state_notifier.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveState = ref.watch(saveStateNotifierProvider).valueOrNull;
    final difficulty = useState(saveState?.difficulty ?? BotDifficulty.medium);

    useEffect(() {
      if (saveState != null) {
        difficulty.value = saveState.difficulty;
      }
      return null;
    }, [saveState?.difficulty]);

    return Scaffold(
      backgroundColor: Color(0xFF0A2340),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'EUCHRE',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'A Classic Trick-Taking Card Game',
                    style: TextStyle(fontSize: 14, color: Colors.white60),
                  ),
                  SizedBox(height: 48),
                  _CardPreview(
                      cardBack: saveState?.cardBack ?? CardBack.redStripes),
                  SizedBox(height: 48),
                  Text(
                    'DIFFICULTY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 12),
                  SegmentedButton<BotDifficulty>(
                    segments: [
                      for (final d in BotDifficulty.values)
                        ButtonSegment(value: d, label: Text(d.displayName)),
                    ],
                    selected: {difficulty.value},
                    onSelectionChanged: (set) {
                      difficulty.value = set.first;
                      ref
                          .read(saveStateNotifierProvider.notifier)
                          .updateState((s) => s.copyWith(difficulty: set.first));
                    },
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.black
                            : Colors.white70,
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    difficulty.value.description,
                    style: TextStyle(fontSize: 12, color: Colors.white38),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              GamePage(difficulty: difficulty.value),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'NEW GAME',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => SettingsPage(),
                              ));
                            },
                            icon: Icon(Icons.settings, size: 20),
                            label: Text('Settings'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => StrategyPage(),
                              ));
                            },
                            icon: Icon(Icons.school, size: 20),
                            label: Text('Strategy'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.amber.shade200,
                              side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => LessonsPage(),
                        ));
                      },
                      icon: Icon(Icons.fitness_center, size: 20),
                      label: Text(
                        saveState != null &&
                                saveState.completedLessons.isNotEmpty
                            ? 'Lessons (${saveState.completedLessons.length}/15)'
                            : 'Lessons',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade200,
                        side: BorderSide(
                            color: Colors.blue.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  if (saveState != null && saveState.gamesPlayed > 0)
                    Text(
                      '${saveState.gamesWon}W / ${saveState.gamesPlayed - saveState.gamesWon}L',
                      style: TextStyle(fontSize: 13, color: Colors.white38),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardPreview extends StatelessWidget {
  final CardBack cardBack;

  const _CardPreview({required this.cardBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < 5; i++)
            Transform.translate(
              offset: Offset((i - 2) * 28.0, 0),
              child: Transform.rotate(
                angle: (i - 2) * 0.08,
                child: _AnimatedCard(index: i, cardBack: cardBack),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedCard extends StatefulWidget {
  final int index;
  final CardBack cardBack;

  const _AnimatedCard({required this.index, required this.cardBack});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _effect = 0;
  static final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_controller.isAnimating) return;
    setState(() => _effect = _random.nextInt(4));
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final card = SizedBox(
      width: 55,
      height: 76,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black, width: 1.5),
          ),
          child: widget.cardBack.build(),
        ),
      ),
    );

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (!_controller.isAnimating) return child!;
          final t = _controller.value;
          switch (_effect) {
            case 0: // Spin
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(t * 2 * math.pi),
                child: child,
              );
            case 1: // Bounce
              final bounce = math.sin(t * math.pi) * -20;
              final scale = 1.0 + math.sin(t * math.pi) * 0.15;
              return Transform.translate(
                offset: Offset(0, bounce),
                child: Transform.scale(scale: scale, child: child),
              );
            case 2: // Wiggle
              final wiggle = math.sin(t * math.pi * 6) * 0.15 * (1 - t);
              return Transform.rotate(angle: wiggle, child: child);
            case 3: // Pop + tilt
              final scale = 1.0 + math.sin(t * math.pi) * 0.3;
              final tilt = math.sin(t * math.pi * 2) * 0.1 * (1 - t);
              return Transform.scale(
                scale: scale,
                child: Transform.rotate(angle: tilt, child: child),
              );
            default:
              return child!;
          }
        },
        child: card,
      ),
    );
  }
}
