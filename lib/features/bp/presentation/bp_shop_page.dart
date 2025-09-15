// lib/features/bp/presentation/bp_shop_page.dart
import 'package:flutter/material.dart';
import 'package:chicachew/core/bp/bp_store.dart';

class BpShopPage extends StatefulWidget {
  const BpShopPage({super.key});

  @override
  State<BpShopPage> createState() => _BpShopPageState();
}

class _BpShopPageState extends State<BpShopPage> {
  Future<void> _buy({
    required int cost,
    required String itemId,
    required String title,
  }) async {
    final ok = await BpStore.spendIfEnough(cost, note: '$title 구매');
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('BP가 부족해요.')));
      return;
    }
    await BpStore.addItem(itemId, note: '$title 획득');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('구매 완료! $title 인벤토리에 추가')));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const items = [
      ('스티커팩(기본)', 'sticker_pack_basic', 50, Icons.emoji_emotions_outlined),
      ('테마: Ocean', 'theme_ocean', 80, Icons.palette_outlined),
      ('사운드팩: Chime', 'sfx_chime', 60, Icons.music_note_outlined),
      ('레슨 해금: 고급 양치 애니', 'unlock_lesson_pro', 70, Icons.lock_open_outlined),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('상점')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<int>(
          future: BpStore.total(),
          builder: (c, s) {
            final bp = s.data ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(avatar: const Icon(Icons.brush_outlined), label: Text('BP $bp')),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final (title, id, cost, icon) = items[i];
                      return Card(
                        child: ListTile(
                          leading: Icon(icon),
                          title: Text(title),
                          subtitle: Text('$cost BP'),
                          trailing: FilledButton(
                            onPressed: () => _buy(cost: cost, itemId: id, title: title),
                            child: const Text('구매'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
