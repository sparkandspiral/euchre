import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:euchre/data/lessons.dart';
import 'package:euchre/model/lesson.dart';
import 'package:euchre/pages/lesson_play_page.dart';
import 'package:euchre/providers/save_state_notifier.dart';

class LessonsPage extends ConsumerWidget {
  const LessonsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveState = ref.watch(saveStateNotifierProvider).valueOrNull;
    final completed = saveState?.completedLessons ?? {};

    return Scaffold(
      backgroundColor: Color(0xFF0A2340),
      appBar: AppBar(
        title: Text('Lessons', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${completed.length}/${allLessons.length}',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          for (final category in LessonCategory.values) ...[
            _CategorySection(
              category: category,
              completedLessons: completed,
              onLessonTap: (lesson) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LessonPlayPage(lesson: lesson),
                ));
              },
            ),
            SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final LessonCategory category;
  final Set<String> completedLessons;
  final void Function(Lesson) onLessonTap;

  const _CategorySection({
    required this.category,
    required this.completedLessons,
    required this.onLessonTap,
  });

  @override
  Widget build(BuildContext context) {
    final categoryLessons =
        allLessons.where((l) => l.category == category).toList();
    final completedCount =
        categoryLessons.where((l) => completedLessons.contains(l.id)).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        initiallyExpanded: completedCount < categoryLessons.length,
        tilePadding: EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.only(bottom: 8),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white38,
        title: Row(
          children: [
            Text(
              category.icon,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                category.displayName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: completedCount == categoryLessons.length
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$completedCount/${categoryLessons.length}',
                style: TextStyle(
                  color: completedCount == categoryLessons.length
                      ? Colors.green.shade300
                      : Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        children: [
          for (final lesson in categoryLessons)
            _LessonTile(
              lesson: lesson,
              isCompleted: completedLessons.contains(lesson.id),
              onTap: () => onLessonTap(lesson),
            ),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final bool isCompleted;
  final VoidCallback onTap;

  const _LessonTile({
    required this.lesson,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        isCompleted ? Icons.check_circle : Icons.circle_outlined,
        color: isCompleted ? Colors.green.shade400 : Colors.white24,
        size: 22,
      ),
      title: Text(
        lesson.title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        lesson.description,
        style: TextStyle(color: Colors.white38, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _DifficultyBadge(difficulty: lesson.difficulty),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final LessonDifficulty difficulty;

  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = switch (difficulty) {
      LessonDifficulty.beginner => (
          Colors.green.shade300,
          Colors.green.withValues(alpha: 0.15),
        ),
      LessonDifficulty.intermediate => (
          Colors.amber.shade300,
          Colors.amber.withValues(alpha: 0.15),
        ),
      LessonDifficulty.advanced => (
          Colors.red.shade300,
          Colors.red.withValues(alpha: 0.15),
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        difficulty.displayName,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
