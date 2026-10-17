import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:costibake_app/core/constants/app_breakpoints.dart';
import 'package:costibake_app/core/theme/app_colors.dart';
import 'package:costibake_app/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:costibake_app/features/costing/presentation/screens/costing_screen.dart';
import 'package:costibake_app/features/recipes/presentation/screens/recipes_screen.dart';
import 'package:costibake_app/features/settings/presentation/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    const CatalogScreen(),
    const RecipesScreen(),
    const CostingScreen(),
    SettingsScreen(onBackToHome: () => _navigateToTab(0)),
  ];

  void _navigateToTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      key: const Key('home_pop_scope'),
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. If an actual input has focus, dismiss it first
        final currentFocus = FocusManager.instance.primaryFocus;
        if (currentFocus != null && currentFocus is! FocusScopeNode && currentFocus.hasFocus) {
          currentFocus.unfocus();
          return;
        }

        // 2. If not on primary tab (Catálogo), navigate to tab 0 instead of exiting
        if (_currentIndex != 0) {
          _navigateToTab(0);
          return;
        }

        // 3. Otherwise, on tab 0 with no active keyboard, close the app
        SystemNavigator.pop();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen =
              constraints.maxWidth >= AppBreakpoints.navigationRailBreakpoint;

          if (isWideScreen) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _navigateToTab,
                    labelType: NavigationRailLabelType.all,
                    selectedIconTheme: const IconThemeData(
                      color: AppColors.primaryCaramel,
                    ),
                    selectedLabelTextStyle: const TextStyle(
                      color: AppColors.primaryCaramel,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedIconTheme: const IconThemeData(
                      color: AppColors.textMuted,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: AppColors.textMuted,
                    ),
                    backgroundColor: AppColors.butterCream,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.bakery_dining,
                            size: 36,
                            color: AppColors.primaryCaramel,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'CostiBake',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDarkCaramel,
                            ),
                          ),
                        ],
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2),
                        label: Text('Catálogo'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book),
                        label: Text('Recetas'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.calculate_outlined),
                        selectedIcon: Icon(Icons.calculate),
                        label: Text('Costeo'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Ajustes'),
                      ),
                    ],
                  ),
                  const VerticalDivider(
                    thickness: 1,
                    width: 1,
                    color: AppColors.borderSubtle,
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _screens,
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            resizeToAvoidBottomInset: false,
            body: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _navigateToTab,
              selectedItemColor: AppColors.primaryCaramel,
              unselectedItemColor: AppColors.textMuted,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined),
                  activeIcon: Icon(Icons.inventory_2),
                  label: 'Catálogo',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.menu_book_outlined),
                  activeIcon: Icon(Icons.menu_book),
                  label: 'Recetas',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calculate_outlined),
                  activeIcon: Icon(Icons.calculate),
                  label: 'Costeo',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Ajustes',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
