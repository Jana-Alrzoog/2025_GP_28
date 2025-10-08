import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomScaffold extends StatelessWidget {
  const CustomScaffold({
    super.key,
    required this.child,
    required this.backgroundAsset,
    this.isSvg = false,
    this.appBarForeground = Colors.white,
  });

  final Widget child;
  final String backgroundAsset;
  final bool isSvg;
  final Color appBarForeground;

  @override
  Widget build(BuildContext context) {
    final background = Positioned.fill(
      child: isSvg
          ? SvgPicture.asset(
              backgroundAsset,
              fit: BoxFit.cover,
            )
          : Image.asset(
              backgroundAsset,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
    );

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: appBarForeground),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          background,
          SafeArea(child: child),
        ],
      ),
    );
  }
}
