import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class AdhkarScreen extends StatelessWidget {
  const AdhkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper().getCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }

        final categories = snapshot.data ?? [];
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
                      builder: (_) => AdhkarDetailScreen(categoryId: cat['id'], title: cat['title']),
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
  final String categoryId;
  final String title;
  
  const AdhkarDetailScreen({super.key, required this.categoryId, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getAdhkarByCategory(categoryId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد أذكار في هذه الفئة.'));
          }

          return ListView.builder(
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
                        'المصدر: ${item['book_name'] ?? 'غير محدد'} - رقم ${item['hadith_number'] ?? ''} - ${item['grade'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
