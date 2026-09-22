import 'package:flutter/material.dart';

import 'package:am_in/screens/admin/admin_dashboard.dart';
import 'package:am_in/screens/admin/manage_courses.dart';
import 'package:am_in/screens/admin/manage_lecturers.dart';
import 'package:am_in/screens/admin/manage_students.dart';
import 'package:am_in/screens/admin/reports_screen.dart';

/// The administrator's tabbed shell: overview, student & lecturer management,
/// course management and reports.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  static const List<Widget> _tabs = <Widget>[
    AdminDashboard(),
    ManageStudents(),
    ManageLecturers(),
    ManageCourses(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.co_present_outlined),
            selectedIcon: Icon(Icons.co_present),
            label: 'Lecturers',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
