import 'package:flutter/material.dart';

import 'portefeuille_scherm.dart';
import 'start_screen.dart';

/// Hoofdnavigatie tussen opnemen (StartScreen) en portefeuille (verbeterscherm).
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({Key? key}) : super(key: key);

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: const [
          StartScreen(),
          PortefeuilleScherm(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt),
            label: 'Opnemen',
          ),
          NavigationDestination(
            icon: Icon(Icons.business),
            label: 'Mijn eenheden',
          ),
        ],
      ),
    );
  }
}
