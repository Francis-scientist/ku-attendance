import 'package:flutter/material.dart';

import 'package:am_in/screens/common/profile_screen.dart';
import 'package:am_in/screens/lecturer/lecturer_dashboard.dart';
import 'package:am_in/screens/lecturer/lecturer_history.dart';

/// The lecturer's tabbed shell: their courses (to start sessions), their
/// session history, and the shared profile tab.
class LecturerHome extends StatefulWidget {
  const LecturerHome({super.key});

  @override
  State<LecturerHome> createState() => _LecturerHomeState();
}

class _LecturerHomeState extends State<LecturerHome> {
  int _index = 0;

  static const List<Widget> _tabs = <Widget>[
    LecturerDashboard(),
    LecturerHistory(),
    ProfileScreen(),
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
            icon: Icon(Icons.co_present_outlined),
            selectedIcon: Icon(Icons.co_present),
            label: 'Teach',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
