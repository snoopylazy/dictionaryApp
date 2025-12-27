import 'dart:convert';
import 'package:dictionaryapp/models/words.dart';
import 'package:dictionaryapp/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

class DetailPage extends StatefulWidget {
  final int wordId;

  const DetailPage({super.key, required this.wordId});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Word? word;
  bool isFavorite = false;
  final AuthService _authService = AuthService();
  String? token;

  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _initializeAndLoadWord();
    _checkFavorite();
  }

  Future<void> _initializeTts() async {
    flutterTts = FlutterTts();

    // Set language to English (you can adjust to "en-GB" or others if needed)
    await flutterTts.setLanguage("en-US");

    // Optional: Adjust speech rate, volume, pitch for better pronunciation
    await flutterTts.setSpeechRate(0.5); // Slower for clearer pronunciation
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    // For iOS: Ensure it works with other audio
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      await flutterTts.setSharedInstance(true);
    }
  }

  Future<void> _speakWord() async {
    if (word != null) {
      await flutterTts.speak(word!.englishWord);
    }
  }

  @override
  void dispose() {
    flutterTts.stop(); // Stop any ongoing speech
    super.dispose();
  }

  Future<void> _initializeAndLoadWord() async {
    token = await _authService.getToken();
    _loadWord();
  }

  Future<void> _loadWord() async {
    if (token == null) return;
    final uri = Uri.parse(
      'https://nubbdictapi.kode4u.tech/api/dictionary/word?id=${widget.wordId}',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        word = Word.fromJson(data);
      });
    } else if (response.statusCode == 401) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading word: ${response.statusCode}')),
        );
      }
    }
  }

  Future<void> _checkFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favJsonList = prefs.getStringList('favorites') ?? [];
    final favList = favJsonList.map((jsonStr) => json.decode(jsonStr)).toList();
    setState(() {
      isFavorite = favList.any((f) => f['id'] == widget.wordId);
    });
  }

  Future<void> _toggleFavorite() async {
    if (word == null) return;
    final prefs = await SharedPreferences.getInstance();
    final favJsonList = prefs.getStringList('favorites') ?? [];
    final favList = favJsonList.map((jsonStr) => json.decode(jsonStr)).toList();

    if (isFavorite) {
      favList.removeWhere((f) => f['id'] == widget.wordId);
    } else {
      favList.add(word!.toJson());
    }

    final newFavJsonList = favList.map((f) => json.encode(f)).toList();
    await prefs.setStringList('favorites', newFavJsonList);

    setState(() {
      isFavorite = !isFavorite;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite ? 'បានបញ្ចូលពាក្យចូលចិត្ត' : 'បានដកចេញពាក្យដែលបានចូលចិត្ត',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (word == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(word!.englishWord),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    word!.englishWord,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 28),
                  color: Colors.blue.shade700,
                  onPressed: _speakWord,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Chip(
              label: Text(
                word!.partOfSpeech,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1976D2)),
              ),
              backgroundColor: Colors.blue.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            const SizedBox(height: 24),

            // Definition card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Html(data: word!.khmerDef),
            ),
          ],
        ),
      ),
    );
  }
}
