// 📍 lib/features/brush_guide/presentation/guide_page.dart (전체 파일)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> _guideImagePaths = [
    'assets/images/guide1.png',
    'assets/images/guide2.png',
    'assets/images/guide3.png',
    'assets/images/guide4.png',
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!.round();
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _guideImagePaths.length,
                itemBuilder: (context, index) {
                  return ImageGuideCard(imagePath: _guideImagePaths[index]);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _guideImagePaths.length,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
                  height: 8.0,
                  width: _currentPage == index ? 24.0 : 8.0,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.blueAccent
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // ✨ [수정] 버튼 동작을 마지막 페이지인지에 따라 다르게 설정합니다.
                onPressed: () {
                  if (_currentPage == _guideImagePaths.length - 1) {
                    // 마지막 페이지에서는 이전 화면(교육 탭)으로 돌아갑니다.
                    context.pop();
                  } else {
                    // 마지막 페이지가 아니면 다음 페이지로 슬라이드합니다.
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeIn,
                    );
                  }
                },
                child: Text(
                  // ✨ [수정] 마지막 페이지의 버튼 텍스트를 '확인'으로 변경합니다.
                  _currentPage == _guideImagePaths.length - 1
                      ? '확인'
                      : '다음',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageGuideCard extends StatelessWidget {
  final String imagePath;

  const ImageGuideCard({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 6.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}