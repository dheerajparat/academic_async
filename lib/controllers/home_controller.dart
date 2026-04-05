import 'package:academic_async/models/bottom_nav_item.dart';
import 'package:academic_async/pages/attendencepage.dart';
import 'package:academic_async/pages/calendar_page.dart';
import 'package:academic_async/pages/menu_page.dart';
import 'package:academic_async/pages/syllabus_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  final RxInt currentIndex = 0.obs;

  final List<BottomNavItem> navItems = const [
    BottomNavItem(icon: Icons.calendar_today_rounded, label: 'Calendar'),
    BottomNavItem(icon: Icons.check_circle_rounded, label: 'Attendance'),
    BottomNavItem(icon: Icons.menu_book_rounded, label: 'Syllabus'),
    BottomNavItem(icon: Icons.menu_rounded, label: 'Menu'),
  ];

  final List<Widget> pages = const [
    CalendarPage(),
    Attendencepage(),
    SyllabusPage(),
    MenuPage(),
  ];

  void changeTab(int index) {
    currentIndex.value = index;
  }
}
