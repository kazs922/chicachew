import 'package:flutter/material.dart';

// 각 탭 import (tabs 폴더 기준)
import 'package:chicachew/features/home/presentation/tabs/brush_time_page.dart';
import 'package:chicachew/features/home/presentation/tabs/education_page.dart';
import 'package:chicachew/features/home/presentation/tabs/home_page.dart';
import 'package:chicachew/features/home/presentation/tabs/report_page.dart';
import 'package:chicachew/features/home/presentation/tabs/my_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 2; // 기본 홈 탭 인덱스

  // ✅ const 제거 → 위젯 생성자가 const가 아닐 경우 에러 방지
  final List<Widget> _pages = [
    const BrushTimePage(),
    const EducationPage(),
    const HomePage(),
    const ReportPage(),
    const MyPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],

      // ✅ 바텀 네비게이터
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.timer), label: "브러쉬타임"),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_books), label: "교육자료"),
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: "홈"),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: "리포트"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: "마이페이지"),
        ],
      ),
    );
  }
}
