import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdhkarScreen extends StatelessWidget {
  const AdhkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/data/adhkar.json'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ في تحميل الأذكار: ${snapshot.error}'));
        }

        final data = jsonDecode(snapshot.data!);
        final categories = data['categories'] as List;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.menu_book, color: Color(0xFFC6A76A)),
                title: Text(cat['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_left),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdhkarDetailScreen(category: cat),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class AdhkarDetailScreen extends StatelessWidget {
  final dynamic category;
  const AdhkarDetailScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final items = category['items'] as List;
    return Scaffold(
      appBar: AppBar(title: Text(category['title']), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item['text'],
                    style: const TextStyle(fontSize: 20, height: 1.8, fontFamily: 'Amiri'),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'المصدر: ${item['reference']['book']} - رقم ${item['reference']['hadith_number']} - ${item['reference']['grade']}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
