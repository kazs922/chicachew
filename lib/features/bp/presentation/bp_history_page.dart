// lib/features/bp/presentation/bp_history_page.dart
import 'package:flutter/material.dart';
import 'package:chicachew/core/bp/bp_store.dart';

class BpHistoryPage extends StatelessWidget {
  const BpHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BP 히스토리')),
      body: FutureBuilder<List<BpEvent>>(
        future: BpStore.ledger(),
        builder: (c, s) {
          final list = s.data ?? const <BpEvent>[];
          if (list.isEmpty) {
            return const Center(child: Text('기록이 없습니다.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _tile(list[i]),
          );
        },
      ),
    );
  }

  Widget _tile(BpEvent e) {
    final dt = DateTime.tryParse(e.ts);
    final when = dt == null ? e.ts : '${dt.year}/${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    final sign = e.delta > 0 ? '+${e.delta}' : '${e.delta}';
    final color = e.delta >= 0 ? Colors.teal : Colors.redAccent;
    final icon = switch (e.type) {
      'award' => Icons.emoji_events_outlined,
      'bonus' => Icons.local_fire_department_outlined,
      'spend' => Icons.shopping_cart_outlined,
      'unlock' => Icons.lock_open_outlined,
      'item_add' => Icons.card_giftcard_outlined,
      'reset' => Icons.delete_forever_outlined,
      _ => Icons.info_outline,
    };
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(e.note ?? e.type),
        subtitle: Text('${e.contentId ?? ''} · $when'),
        trailing: Text(sign, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
