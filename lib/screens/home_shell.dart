import 'package:flutter/material.dart';
import 'package:fluid_bottom_nav_bar/fluid_bottom_nav_bar.dart';

import 'tabs/home_tab.dart';
import 'tabs/assistant_tab.dart';
import 'tabs/profile_tab.dart';

// ✅ add this
import '/services/notifications_onboarding.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    HomeTab(),
    AssistantTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();

    // ✅ run once after first frame (context ready)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationsOnboarding.maybeRun(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    const tabColors = [
      Color.fromRGBO(209, 32, 39, 1.0),
      Color(0xFF43B649),
      Color(0xFF984C9D),
    ];
    const inactive = Color.fromRGBO(59, 59, 59, 1);

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Positioned.fill(child: _pages[_index]),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 20,
            child: Container(color: Colors.white),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -10,
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: SizedBox(
                height: 70,
                child: FluidNavBar(
                  icons: [
                    FluidNavBarIcon(
                      icon: Icons.home,
                      backgroundColor: _index == 0 ? tabColors[0] : Colors.white,
                      selectedForegroundColor: Colors.white,
                      unselectedForegroundColor: inactive,
                      extras: const {'label': 'الرئيسية'},
                    ),
                    FluidNavBarIcon(
                      icon: Icons.comment_rounded,
                      backgroundColor: _index == 1 ? tabColors[1] : Colors.white,
                      selectedForegroundColor: Colors.white,
                      unselectedForegroundColor: inactive,
                      extras: const {'label': 'المساعد'},
                    ),
                    FluidNavBarIcon(
                      icon: Icons.person,
                      backgroundColor: _index == 2 ? tabColors[2] : Colors.white,
                      selectedForegroundColor: Colors.white,
                      unselectedForegroundColor: inactive,
                      extras: const {'label': 'الملف الشخصي'},
                    ),
                  ],
                  onChange: (i) => setState(() => _index = i),
                  animationFactor: 1.15,
                  scaleFactor: 1.1,
                  style: const FluidNavBarStyle(
                    barBackgroundColor: Colors.white,
                    iconSelectedForegroundColor: Colors.white,
                    iconUnselectedForegroundColor: inactive,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
