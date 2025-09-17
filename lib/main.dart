// 📍 lib/main.dart (전체 파일)

import 'package:flutter/material.dart';
import 'package:chicachew/app/app_router.dart';
import 'package:chicachew/app/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✨ [추가] 날짜 형식 초기화를 위해 import 합니다.
import 'package:intl/date_symbol_data_local.dart';

// ✨ [수정] main 함수를 async로 변경하고 초기화 코드를 추가합니다.
Future<void> main() async {
  // Flutter 앱이 시작되기 전에 특정 작업을 수행할 수 있도록 보장합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 한국어 날짜 형식을 사용할 수 있도록 초기화합니다.
  await initializeDateFormatting('ko_KR', null);

  runApp(const ProviderScope(child: MyApp()));
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