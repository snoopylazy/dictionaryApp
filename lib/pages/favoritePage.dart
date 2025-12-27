import 'dart:convert';
import 'package:dictionaryapp/models/words.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'detailPage.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  List<Word> favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favJsonList = prefs.getStringList('favorites') ?? [];
    final favList = favJsonList
        .map((jsonStr) => Word.fromJson(json.decode(jsonStr)))
        .toList();

    if (mounted) {
      setState(() {
        favorites = favList;
      });
    }
  }

  Future<void> _removeFavorite(Word word) async {
    final prefs = await SharedPreferences.getInstance();
    final favJsonList = prefs.getStringList('favorites') ?? [];
    final favList = favJsonList.map((jsonStr) => json.decode(jsonStr)).toList();

    favList.removeWhere((f) => f['id'] == word.id);

    final newFavJsonList = favList.map((f) => json.encode(f)).toList();
    await prefs.setStringList('favorites', newFavJsonList);

    if (mounted) {
      setState(() {
        favorites.remove(word);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('បានដកចេញពាក្យដែលបានចូលចិត្ត'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'មិនមានពាក្យដែលបានចូលចិត្តទេ',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final word = favorites[index];

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Text(
                word.englishWord,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  word.partOfSpeech,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    onPressed: () => _removeFavorite(word),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailPage(wordId: word.id),
                  ),
                );
                // Refresh favorites in case user toggled it in detail page
                _loadFavorites();
              },
            ),
          );
        },
      ),
    );
  }
}
