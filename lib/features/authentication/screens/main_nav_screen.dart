import 'package:flutter/material.dart';
import '../../home/screens/home_screen.dart';
import '../../trip_planning/screens/trip_planner_screen.dart';
import '../../trip_history/screens/trip_history_screen.dart';
import '../../settings/screens/settings_screen.dart';

// NEW: Import professional tracking
import '../../trip_tracking/screens/trip_tracking_screen_new.dart';

class MainNavScreen extends StatefulWidget {
const MainNavScreen({super.key});

@override
State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
int _selectedIndex = 0;

// Update your existing screens list to include professional tracking
late final List<Widget> _screens = [
const HomeScreen(), // Your existing home
const TripTrackingScreenNew(), // NEW: Professional tracking replaces basic tracking
const TripPlannerScreen(), // Your existing planner
const TripHistoryScreen(), // Your existing history
const SettingsScreen(), // Your existing settings
];

void _onItemTapped(int index) {
setState(() {
_selectedIndex = index;
});
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: IndexedStack(
index: _selectedIndex,
children: _screens,
),
bottomNavigationBar: BottomNavigationBar(
type: BottomNavigationBarType.fixed,
currentIndex: _selectedIndex,
selectedItemColor: Colors.deepPurple,
unselectedItemColor: Colors.grey,
showUnselectedLabels: true,
onTap: _onItemTapped,
items: const [
BottomNavigationBarItem(
icon: Icon(Icons.home),
label: 'Home',
),
BottomNavigationBarItem(
icon: Icon(Icons.gps_fixed), // Changed icon for professional tracking
label: 'Track',
),
BottomNavigationBarItem(
icon: Icon(Icons.route),
label: 'Plan',
),
BottomNavigationBarItem(
icon: Icon(Icons.history),
label: 'History',
),
BottomNavigationBarItem(
icon: Icon(Icons.settings),
label: 'Settings',
),
],
),
);
}
}
