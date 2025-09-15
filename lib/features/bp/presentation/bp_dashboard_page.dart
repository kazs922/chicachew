// lib/features/bp/presentation/bp_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:chicachew/core/bp/bp_store.dart';
import 'package:chicachew/core/bp/streak_store.dart';
import 'package:chicachew/features/bp/presentation/bp_shop_page.dart';
import 'package:chicachew/features/bp/presentation/bp_inventory_page.dart';
import 'package:chicachew/features/bp/presentation/bp_history_page.dart';

class BpDashboardPage extends StatefulWidget {
  const BpDashboardPage({super.key});

  @override
  State<BpDashboardPage> createState() => _BpDashboardPageState();
}

class _BpDashboardPageState extends State<BpDashboardPage> {
  Future<void> _refresh() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BP 대시보드'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          // 개발용 리셋(배포 시 제거)
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              await BpStore.resetAll();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('BP 초기화 완료')));
              setState(() {});
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<int>(
              future: BpStore.total(),
              builder: (c, s) {
                final bp = s.data ?? 0;
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.brush_outlined, size: 36),
                    title: const Text('누적 BP'),
                    subtitle: Text('$bp'),
                    trailing: FilledButton(
                      onPressed: () async {
                        final days = await StreakStore.updateTodayAndBonus();
                        if (!mounted) return;
                        final (d, best) = await StreakStore.info();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('스트릭 ${days}일차! (최고 ${best}일) 보너스 지급')),
                        );
                        setState(() {});
                      },
                      child: const Text('오늘 체크(+보너스)'),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.storefront_outlined,
                    title: '상점',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BpShopPage()))
                        .then((_) => _refresh()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.inventory_2_outlined,
                    title: '인벤토리',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BpInventoryPage())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.receipt_long_outlined,
                    title: '히스토리',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BpHistoryPage())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('최근 활동', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            FutureBuilder(
              future: BpStore.ledger(),
              builder: (c, s) {
                final list = (s.data as List?)?.cast<BpEvent>() ?? const <BpEvent>[];
                final recent = list.take(10).toList();
                if (recent.isEmpty) {
                  return const Text('아직 기록이 없어요.');
                }
                return Column(children: recent.map((e) => _ledgerTile(e)).toList());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _ledgerTile(BpEvent e) {
    final dt = DateTime.tryParse(e.ts);
    final when = dt == null ? e.ts : '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    final sign = e.delta > 0 ? '+${e.delta}' : '${e.delta}';
    final color = e.delta >= 0 ? Colors.teal : Colors.redAccent;
    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(
          switch (e.type) {
            'award' => Icons.emoji_events_outlined,
            'bonus' => Icons.local_fire_department_outlined,
            'spend' => Icons.shopping_cart_outlined,
            'unlock' => Icons.lock_open_outlined,
            'item_add' => Icons.card_giftcard_outlined,
            _ => Icons.info_outline,
          },
        ),
        title: Text(e.note ?? e.type),
        subtitle: Text('${e.contentId ?? ''} · $when'),
        trailing: Text(sign, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 6),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}
