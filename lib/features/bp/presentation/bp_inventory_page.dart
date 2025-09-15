// lib/features/bp/presentation/bp_inventory_page.dart
import 'package:flutter/material.dart';
import 'package:chicachew/core/bp/bp_store.dart';

class BpInventoryPage extends StatelessWidget {
  const BpInventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('인벤토리')),
      body: FutureBuilder<List<String>>(
        future: BpStore.inventory(),
        builder: (c, s) {
          final inv = s.data ?? const <String>[];
          if (inv.isEmpty) {
            return const Center(child: Text('아직 아이템이 없어요. 상점에서 구매해보세요!'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: inv.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final id = inv[i];
              final (icon, title) = _labelFor(id);
              return Card(
                child: ListTile(
                  leading: Icon(icon),
                  title: Text(title),
                  subtitle: Text(id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  (IconData, String) _labelFor(String id) {
    if (id.startsWith('unlock_')) {
      return (Icons.lock_open_outlined, '레슨 해금');
    }
    switch (id) {
      case 'sticker_pack_basic': return (Icons.emoji_emotions_outlined, '스티커팩(기본)');
      case 'theme_ocean': return (Icons.palette_outlined, '테마: Ocean');
      case 'sfx_chime': return (Icons.music_note_outlined, '사운드팩: Chime');
      default: return (Icons.card_giftcard_outlined, '아이템');
    }
  }
}
