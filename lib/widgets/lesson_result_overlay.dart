import 'package:flutter/material.dart';

class LessonResultOverlay extends StatelessWidget {
  final bool isCorrect;
  final String explanation;
  final VoidCallback onTryAgain;
  final VoidCallback? onNextLesson;

  const LessonResultOverlay({
    super.key,
    required this.isCorrect,
    required this.explanation,
    required this.onTryAgain,
    this.onNextLesson,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: EdgeInsets.all(32),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(0xFF0A2340),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCorrect
                      ? Colors.green.withValues(alpha: 0.5)
                      : Colors.red.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green.shade400 : Colors.red.shade400,
                    size: 56,
                  ),
                  SizedBox(height: 16),
                  Text(
                    isCorrect ? 'Correct!' : 'Not Quite',
                    style: TextStyle(
                      color: isCorrect
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    explanation,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isCorrect)
                        ElevatedButton(
                          onPressed: onTryAgain,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            foregroundColor: Colors.white,
                            padding:
                                EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: Text('Try Again'),
                        ),
                      if (!isCorrect && onNextLesson != null) SizedBox(width: 12),
                      if (onNextLesson != null)
                        ElevatedButton(
                          onPressed: onNextLesson,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding:
                                EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: Text(isCorrect ? 'Next Lesson' : 'Skip'),
                        ),
                      if (isCorrect && onNextLesson == null)
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding:
                                EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: Text('Done'),
                        ),
                    ],
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
