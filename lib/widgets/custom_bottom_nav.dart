import 'dart:ui';

import 'package:academic_async/controllers/home_controller.dart';
import 'package:academic_async/models/bottom_nav_item.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomBottomNav extends GetView<HomeController> {
  const CustomBottomNav({
    super.key,
    required this.bottomBarColor,
    required this.isDarkMode,
    required this.navItems,
    required this.accentColor,
  });

  final Color bottomBarColor;
  final bool isDarkMode;
  final List<BottomNavItem> navItems;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 5, // blur strength
              sigmaY: 5,
            ),
            child: Container(
              height: 65,
              decoration: BoxDecoration(
                color: bottomBarColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode ? Colors.black54 : Colors.black12,
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(navItems.length, (index) {
                  final bool isSelected =
                      controller.currentIndex.value == index;

                  return GestureDetector(
                    onTap: () => controller.changeTab(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            navItems[index].icon,
                            color: isSelected
                                ? accentColor
                                : (isDarkMode
                                      ? Colors.white54
                                      : Colors.black54),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            child: isSelected
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      navItems[index].label,
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
