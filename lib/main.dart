// 📍 lib/main.dart (파일 전체를 이 코드로 교체하세요)

import 'package:chicachew/app/app_router.dart';
import 'package:chicachew/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Chicachew',
      // ✅ 존재하지 않는 클래스 대신, 실제 함수를 호출하도록 수정했습니다.
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}