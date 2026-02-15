import 'package:flutter/material.dart';

class GameEventBanner extends StatefulWidget {
  final String message;
  final int eventKey;
  const GameEventBanner(
      {super.key, required this.message, required this.eventKey});

  @override
  State<GameEventBanner> createState() => _GameEventBannerState();
}

class _GameEventBannerState extends State<GameEventBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3000),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void didUpdateWidget(GameEventBanner old) {
    super.didUpdateWidget(old);
    if (old.eventKey != widget.eventKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Opacity(opacity: _opacity.value, child: child),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 40, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          widget.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
