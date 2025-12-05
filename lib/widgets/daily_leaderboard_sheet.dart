import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:solitaire/model/daily_challenge.dart';
import 'package:solitaire/model/game.dart';
import 'package:solitaire/model/score_data.dart';
import 'package:solitaire/services/leaderboard_service.dart';
import 'package:solitaire/utils/duration_extensions.dart';
import 'package:solitaire/widgets/themed_sheet.dart';

class DailyLeaderboardSheet extends ConsumerStatefulWidget {
  final Game game;
  final DailyChallengeConfig config;

  const DailyLeaderboardSheet({
    super.key,
    required this.game,
    required this.config,
  });

  static Future<void> show(
    BuildContext context, {
    required Game game,
    required DailyChallengeConfig config,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DailyLeaderboardSheet(game: game, config: config),
    );
  }

  @override
  ConsumerState<DailyLeaderboardSheet> createState() =>
      _DailyLeaderboardSheetState();
}

class _DailyLeaderboardSheetState
    extends ConsumerState<DailyLeaderboardSheet> {
  late Future<_LeaderboardPayload> _data;

  @override
  void initState() {
    super.initState();
    _data = _loadData();
  }

  Future<_LeaderboardPayload> _loadData() async {
    final service = ref.read(leaderboardServiceProvider);
    final scores = await service.getLeaderboard(
      widget.game,
      widget.config.puzzleNumber,
    );
    final player =
        await service.getCurrentRanking(widget.game, widget.config.puzzleNumber);
    final displayName = await service.getStoredDisplayName();
    return _LeaderboardPayload(
      scores: scores,
      playerScore: player,
      playerDisplayName: displayName,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _data = _loadData();
    });
    await _data;
  }

  String _formatScore(ScoreData data) => data.duration.format();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LeaderboardPayload>(
      future: _data,
      builder: (context, snapshot) {
        return ThemedSheet(
          title: 'Daily Leaderboard',
          subtitle:
              '${widget.game.title} • ${widget.config.formattedLabel} (Day ${widget.config.puzzleNumber})',
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: snapshot.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: _buildContent(context, snapshot.data),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, _LeaderboardPayload? payload) {
    if (payload == null) {
      return ListView(
        children: const [
          SizedBox(height: 48),
          Center(
            child: Text(
              'Unable to load leaderboard data.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    }

    final scores = payload.scores;

    return Column(
      children: [
        if (payload.playerDisplayName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Signed in as ${payload.playerDisplayName}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        Expanded(
          child: scores.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 48),
                    Center(
                      child: Text(
                        'No scores yet. Be the first!',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  itemCount: scores.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white24),
                  itemBuilder: (context, index) {
                    final score = scores[index];
                    final isPlayer =
                        payload.playerScore?.userId == score.userId;
                    return ListTile(
                      leading: Text(
                        '${score.rank}.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              isPlayer ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      title: Text(
                        score.displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              isPlayer ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Text(
                        _formatScore(score),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      tileColor: isPlayer
                          ? Colors.white.withValues(alpha: 0.08)
                          : null,
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final newName = await _promptForNewName(context);
                if (newName.isEmpty || !context.mounted) return;
                final service = ref.read(leaderboardServiceProvider);
                final result =
                    await service.updateDisplayName(context, newName);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.message)),
                );
                if (result.success) {
                  await _refresh();
                }
              },
              icon: const Icon(Icons.edit),
              label: const Text('Change Name'),
            ),
            ElevatedButton.icon(
              onPressed: () => _refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ],
    );
  }

  Future<String> _promptForNewName(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Display Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter new display name',
            ),
            maxLength: 25,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    return (result ?? '').trim();
  }
}

class _LeaderboardPayload {
  final List<ScoreData> scores;
  final ScoreData? playerScore;
  final String? playerDisplayName;

  _LeaderboardPayload({
    required this.scores,
    required this.playerScore,
    required this.playerDisplayName,
  });
}

