import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/core/utils/validators.dart';
import 'package:am_in/models/course.dart';
import 'package:am_in/providers/app_providers.dart';
import 'package:am_in/providers/data_providers.dart';
import 'package:am_in/widgets/app_feedback.dart';
import 'package:am_in/widgets/app_text_field.dart';
import 'package:am_in/widgets/async_value_view.dart';
import 'package:am_in/widgets/primary_button.dart';
import 'package:am_in/widgets/state_views.dart';
import 'package:am_in/widgets/status_chip.dart';

/// Admin: the course catalogue. Create new courses, edit details, and
/// activate/deactivate them. Lecturer assignment lives on the Lecturers tab.
class ManageCourses extends ConsumerWidget {
  const ManageCourses({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Course>> coursesAsync =
        ref.watch(allCoursesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New course'),
      ),
      body: AsyncValueView<List<Course>>(
        value: coursesAsync,
        onRetry: () => ref.invalidate(allCoursesProvider),
        emptyBuilder: () => const EmptyView(
          icon: Icons.menu_book_outlined,
          title: 'No courses yet',
          subtitle: 'Tap “New course” to add the first one.',
        ),
        dataBuilder: (List<Course> courses) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: courses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (BuildContext context, int i) =>
              _CourseTile(course: courses[i]),
        ),
      ),
    );
  }
}

class _CourseTile extends ConsumerWidget {
  const _CourseTile({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<dynamic>> enrollmentsAsync =
        ref.watch(courseEnrollmentsProvider(course.id));
    final String enrolled = enrollmentsAsync.maybeWhen(
      data: (List<dynamic> e) => '${e.length} enrolled',
      orElse: () => '… enrolled',
    );
    final int lecturers = course.lecturerIds.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.withValues(alpha: 0.12),
          foregroundColor: Colors.deepPurple,
          child: const Icon(Icons.menu_book),
        ),
        title: Text(course.courseCode),
        subtitle: Text(
          '${course.courseName}\n$enrolled  •  '
          '$lecturers lecturer${lecturers == 1 ? '' : 's'}',
        ),
        isThreeLine: true,
        trailing: course.isActive
            ? StatusChip.positive('Active')
            : StatusChip.neutral('Archived'),
        onTap: () => _openForm(context, course: course),
      ),
    );
  }
}

/// Opens the create/edit form as a bottom sheet.
void _openForm(BuildContext context, {Course? course}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _CourseForm(course: course),
    ),
  );
}

/// Create (when [course] is null) or edit a course.
class _CourseForm extends ConsumerStatefulWidget {
  const _CourseForm({this.course});

  final Course? course;

  @override
  ConsumerState<_CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends ConsumerState<_CourseForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _department;
  late final TextEditingController _faculty;
  late bool _isActive;
  bool _saving = false;

  bool get _isEditing => widget.course != null;

  @override
  void initState() {
    super.initState();
    final Course? c = widget.course;
    _code = TextEditingController(text: c?.courseCode ?? '');
    _name = TextEditingController(text: c?.courseName ?? '');
    _department = TextEditingController(text: c?.department ?? '');
    _faculty = TextEditingController(text: c?.faculty ?? '');
    _isActive = c?.isActive ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _department.dispose();
    _faculty.dispose();
    super.dispose();
  }

  String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (_isEditing) {
        await ref.read(courseRepositoryProvider).updateCourse(
          widget.course!.id,
          <String, dynamic>{
            'courseCode': _code.text.trim(),
            'courseName': _name.text.trim(),
            'department': _emptyToNull(_department.text),
            'faculty': _emptyToNull(_faculty.text),
            'isActive': _isActive,
          },
        );
      } else {
        await ref.read(courseRepositoryProvider).createCourse(
              Course(
                id: '',
                courseCode: _code.text.trim(),
                courseName: _name.text.trim(),
                department: _emptyToNull(_department.text),
                faculty: _emptyToNull(_faculty.text),
                isActive: _isActive,
              ),
            );
      }
      if (mounted) {
        Navigator.of(context).pop();
        AppFeedback.showSuccess(
          context,
          _isEditing ? 'Course updated.' : 'Course created.',
        );
      }
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _isEditing ? 'Edit course' : 'New course',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _code,
              label: 'Course code',
              hint: 'e.g. SCO 209',
              prefixIcon: Icons.tag,
              textCapitalization: TextCapitalization.characters,
              validator: (String? v) =>
                  Validators.requiredField(v, field: 'Course code'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _name,
              label: 'Course name',
              hint: 'e.g. Computer Organization',
              prefixIcon: Icons.menu_book_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (String? v) =>
                  Validators.requiredField(v, field: 'Course name'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _department,
              label: 'Department (optional)',
              prefixIcon: Icons.account_tree_outlined,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _faculty,
              label: 'Faculty (optional)',
              prefixIcon: Icons.apartment_outlined,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text(
                  'Only active courses can be enrolled in or started.'),
              value: _isActive,
              onChanged: (bool v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: _isEditing ? 'Save changes' : 'Create course',
              icon: _isEditing ? Icons.save_outlined : Icons.add,
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
