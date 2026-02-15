import 'package:flutter/material.dart';

class PracticeFeedbackBanner extends StatefulWidget {
  final bool isGoodPlay;
  final String message;
  final VoidCallback onDismissed;

  const PracticeFeedbackBanner({
    super.key,
    required this.isGoodPlay,
    required this.message,
    required this.onDismissed,
  });

  @override
  State<PracticeFeedbackBanner> createState() => _PracticeFeedbackBannerState();
}

class _PracticeFeedbackBannerState extends State<PracticeFeedbackBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 3000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0, 0.15, curve: Curves.easeOut),
    ));

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isGoodPlay
                  ? Colors.green.shade800.withValues(alpha: 0.95)
                  : Colors.red.shade800.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isGoodPlay
                    ? Colors.green.shade400.withValues(alpha: 0.5)
                    : Colors.red.shade400.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.isGoodPlay ? Icons.thumb_up : Icons.lightbulb,
                  color: widget.isGoodPlay
                      ? Colors.green.shade200
                      : Colors.amber.shade200,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
