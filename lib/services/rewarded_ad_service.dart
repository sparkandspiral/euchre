import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final rewardedAdServiceProvider = Provider((ref) => RewardedAdService());

class RewardedAdService {
  static const Duration _adDuration = Duration(seconds: 4);

  Future<void> showRewardedAd(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RewardedAdDialog(duration: _adDuration),
    );
  }
}

class _RewardedAdDialog extends StatefulWidget {
  final Duration duration;
  const _RewardedAdDialog({required this.duration});

  @override
  State<_RewardedAdDialog> createState() => _RewardedAdDialogState();
}

class _RewardedAdDialogState extends State<_RewardedAdDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_completed && mounted) {
          _completed = true;
          Navigator.of(context).maybePop(true);
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rewarded Ad'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thanks for watching! Keep the app open while we finish the bonus.',
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => LinearProgressIndicator(
              value: _controller.value,
            ),
          ),
        ],
      ),
    );
  }
}

