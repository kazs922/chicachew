// lib/app/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// 스플래시 & 인트로 (단일 인트로로 교체)
import 'package:chicachew/features/splash/presentation/intro_page.dart';

// 기존 인트로들은 더 이상 사용하지 않음
// import 'package:chicachew/features/splash/presentation/intro_step1_page.dart';
// import 'package:chicachew/features/splash/presentation/intro_step2_page.dart';

// 홈 메인
import 'package:chicachew/features/home/presentation/main_page.dart';

// 브러쉬 가이드
import 'package:chicachew/features/brush_guide/presentation/live_brush_page.dart';
import 'package:chicachew/features/brush_guide/presentation/summary_page.dart';
import 'package:chicachew/features/brush_guide/application/summary_args.dart';
import 'package:chicachew/features/brush_guide/presentation/guide_page.dart';
import 'package:chicachew/features/brush_guide/presentation/face_check_page.dart';

// ✅ 프로필
import 'package:chicachew/features/profile/presentation/profile_add_page.dart';
import 'package:chicachew/features/profile/presentation/profile_select_page.dart';

// (필요할 경우) 로컬 스토리지
// import 'package:chicachew/core/storage/local_store.dart';

final GoRouter appRouter = GoRouter(
  // ✅ 단일 인트로 사용
  initialLocation: '/intro',
  routes: [
    // ✅ 새 인트로
    GoRoute(path: '/intro', builder: (_, __) => const IntroPage()),

    // ⛔️ 더 이상 사용 안 함 (필요시 완전 삭제 가능)
    // GoRoute(path: '/intro1', builder: (_, __) => const IntroStep1Page()),
    // GoRoute(path: '/intro2', builder: (_, __) => const IntroStep2Page()),

    // 홈
    GoRoute(path: '/home', builder: (_, __) => const MainPage()),
    GoRoute(path: '/guide', builder: (_, __) => const GuidePage()),

    // 브러쉬
    // NOTE: 기존에 /live 와 /live-brush 둘 다 존재 → 호환 위해 둘 다 유지
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
        // nextRoute를 extra로 전달받아 사용 (기본: /live-brush)
        final next = (state.extra as String?) ?? '/live-brush';
        return FaceCheckPage(nextRoute: next);
      },
    ),
    GoRoute(
      path: '/live-brush',
      builder: (_, __) => const LiveBrushPage(), // 기존 실전 양치 페이지
    ),

    // ✅ 프로필
    GoRoute(path: '/profile/add', builder: (_, __) => const ProfileAddPage()),
    GoRoute(path: '/profile/select', builder: (_, __) => const ProfileSelectPage()),
  ],
);
