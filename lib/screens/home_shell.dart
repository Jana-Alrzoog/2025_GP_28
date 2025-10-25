import 'package:flutter/material.dart';
import 'package:fluid_bottom_nav_bar/fluid_bottom_nav_bar.dart';

import 'tabs/home_tab.dart';
import 'tabs/assistant_tab.dart';
import 'tabs/profile_tab.dart';

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
  Widget build(BuildContext context) {
    // ألوان التبويبات عند التفعيل
    const tabColors = [
      Color.fromRGBO(209, 32, 39, 1.0), // الرئيسية (برتقالي)
      Color(0xFF43B649), // المساعد (أخضر)
      Color(0xFF984C9D), // الملف (بنفسجي)
    ];
    const inactive = Color.fromRGBO(59, 59, 59, 1);

    return Scaffold(
      // نحتاجه علشان الموجة تدخل فوق الجسم، بس بنحكم تموضع البار يدويًا
      extendBody: true,
      backgroundColor: const Color(0xFFF5F5F5),



      // نستخدم Stack حتى نثبت البار بأسفل الشاشة بدون أي فراغ
      body: Stack(
        children: [
          // المحتوى
          Positioned.fill(child: _pages[_index]),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 20,
            child: Container(color: Colors.white),
          ),
          // البار السفلي — مثبت عند 0 بالضبط
          Positioned(
            left: 0,
            right: 0,
            bottom: -10,
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true, // ⛔️ ألغِ أي SafeArea سفلية
              child: SizedBox(
                height: 70,
                child: FluidNavBar(
                  // لا تكتب const هنا لأن الألوان تعتمد على _index
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