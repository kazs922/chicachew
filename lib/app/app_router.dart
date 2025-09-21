// 📍 lib/app/app_router.dart (파일 전체를 이 코드로 교체하세요)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// 스플래시 & 인트로
import 'package:chicachew/features/splash/presentation/intro_page.dart';

// 홈 메인
import 'package:chicachew/features/home/presentation/main_page.dart';

// 브러쉬 가이드
import 'package:chicachew/features/brush_guide/presentation/live_brush_page.dart';
import 'package:chicachew/features/brush_guide/presentation/summary_page.dart';
import 'package:chicachew/features/brush_guide/application/summary_args.dart';
import 'package:chicachew/features/brush_guide/presentation/guide_page.dart';
import 'package:chicachew/features/brush_guide/presentation/face_check_page.dart';

// ✅ 1. 알려주신 정확한 경로로 수정했습니다.
import 'package:chicachew/features/brush_guide/presentation/mouthwash_page.dart';
import 'package:chicachew/features/brush_guide/presentation/brush_result_page.dart';


// 프로필
import 'package:chicachew/features/profile/presentation/profile_add_page.dart';
import 'package:chicachew/features/profile/presentation/profile_select_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/intro',
  routes: [
    GoRoute(path: '/intro', builder: (_, __) => const IntroPage()),

    // 홈
    GoRoute(path: '/home', builder: (_, __) => const MainPage()),
    GoRoute(path: '/guide', builder: (_, __) => const GuidePage()),

    // 브러쉬
    GoRoute(path: '/live', builder: (_, __) => const LiveBrushPage()),
    GoRoute(
      path: '/summary',
      builder: (ctx, state) {
        final args = state.extra is SummaryArgs
            ? state.extra as SummaryArgs
            : const SummaryArgs(scores: [], durationSec: 0);
        return SummaryPage(args: args);
      },
    ),
    GoRoute(
      path: '/face-check',
      builder: (_, state) {
        final next = (state.extra as String?) ?? '/live-brush';
        return FaceCheckPage(nextRoute: next);
      },
    ),
    GoRoute(
      path: '/live-brush',
      builder: (_, __) => const LiveBrushPage(),
    ),

    // ✅ 2. '/mouthwash' 와 '/brush-result' 경로를 새로 추가합니다.
    GoRoute(
      path: '/mouthwash',
      name: 'mouthwash',
      builder: (context, state) {
        final scores = state.extra as List<double>? ?? [];
        return MouthwashPage(scores: scores);
      },
    ),
    GoRoute(
      path: '/brush-result',
      builder: (context, state) {
        // ✅ [수정] onDone 파라미터를 제거합니다.
        final rawList = state.extra as List? ?? [];
        final List<double> scores = rawList.map((v) => (v as num).toDouble()).toList();
        return BrushResultPage(scores01: scores);
      },
    ),

    // 프로필
    GoRoute(path: '/profile/add', builder: (_, __) => const ProfileAddPage()),
    GoRoute(path: '/profile/select', builder: (_, __) => const ProfileSelectPage()),
  ],
);