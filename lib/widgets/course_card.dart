import 'package:flutter/material.dart';

import 'package:am_in/models/course.dart';

/// A tappable card summarising a [Course]. Used across student, lecturer and
/// admin lists. [trailing] lets each screen add its own action/status.
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.trailing,
    this.subtitle,
  });

  final Course course;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Overrides the default subtitle (course name) when provided.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text(
            course.courseCode.isNotEmpty
                ? course.courseCode.characters.first.toUpperCase()
                : '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          course.courseCode,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle ?? course.courseName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing,
        isThreeLine: false,
      ),
    );
  }
}
