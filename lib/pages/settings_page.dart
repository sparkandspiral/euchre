import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:euchre/model/background.dart';
import 'package:euchre/model/card_back.dart';
import 'package:euchre/providers/save_state_notifier.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveState = ref.watch(saveStateNotifierProvider).valueOrNull;
    if (saveState == null) {
      return Scaffold(
        backgroundColor: Color(0xFF0A2340),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFF0A2340),
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.all(24),
        children: [
          // Volume
          Text('Volume',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.volume_off, color: Colors.white54, size: 20),
              Expanded(
                child: Slider(
                  value: saveState.volume,
                  onChanged: (v) => ref
                      .read(saveStateNotifierProvider.notifier)
                      .updateState((s) => s.copyWith(volume: v)),
                ),
              ),
              Icon(Icons.volume_up, color: Colors.white54, size: 20),
            ],
          ),
          SizedBox(height: 32),

          // Card Back
          Text('Card Back',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 69 / 93,
            children: [
              for (final back in CardBack.values)
                GestureDetector(
                  onTap: () => ref
                      .read(saveStateNotifierProvider.notifier)
                      .updateState((s) => s.copyWith(cardBack: back)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: saveState.cardBack == back
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: back.build(),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 32),

          // Background
          Text('Table Color',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          Row(
            children: [
              for (final bg in Background.values) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => ref
                        .read(saveStateNotifierProvider.notifier)
                        .updateState((s) => s.copyWith(background: bg)),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: bg.fallbackColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: saveState.background == bg
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                if (bg != Background.values.last) SizedBox(width: 8),
              ],
            ],
          ),
          SizedBox(height: 32),

          // Coach Mode
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Coach Mode',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                      'Shows optimal play recommendations with reasoning during your turn',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: saveState.coachMode,
                onChanged: (v) => ref
                    .read(saveStateNotifierProvider.notifier)
                    .updateState((s) => s.copyWith(coachMode: v)),
                activeColor: Colors.amber,
              ),
            ],
          ),
          SizedBox(height: 32),

          // Stats
          Text('Statistics',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: 'Played', value: '${saveState.gamesPlayed}'),
                _StatItem(label: 'Won', value: '${saveState.gamesWon}'),
                _StatItem(
                  label: 'Win Rate',
                  value: saveState.gamesPlayed > 0
                      ? '${(saveState.gamesWon / saveState.gamesPlayed * 100).round()}%'
                      : '-',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
