import 'package:flutter/material.dart';
import 'package:chicachew/app/app_router.dart';
import 'package:chicachew/app/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChicachewApp());
}

class ChicachewApp extends StatelessWidget {
  const ChicachewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Chicachew',
      theme: buildAppTheme(),     // #BFEAD6 테마
      // 필요하면 아래 두 줄 추가
      // darkTheme: buildDarkAppTheme(),
      // themeMode: ThemeMode.light,
      routerConfig: appRouter,    // GoRouter
    );
  }
}
