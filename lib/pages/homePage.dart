import 'dart:async';
import 'dart:convert';
import 'package:dictionaryapp/models/words.dart';
import 'package:dictionaryapp/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'detailPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  List<Word> words = [];
  Map<int, bool> isFavoriteMap = {}; // To track favorite status for each word
  int offset = 0;
  final int limit = 20;
  bool isLoading = false;
  bool isLoadingMore = false;
  String query = '';
  String? token;
  Timer? _debounce;
  String? errorMessage;
  String? debugInfo;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadWords();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !isLoadingMore &&
        !isLoading) {
      _loadWords();
    }
  }

  Future<void> _initializeAndLoadWords() async {
    token = await _authService.getToken();
    print(
      '🔑 Token retrieved: ${token != null ? "YES (${token!.length} chars)" : "NO"}',
    );

    if (token != null) {
      setState(() {
        debugInfo = 'Token found, loading words...';
      });
      _loadFavoritesStatus();
      _loadWords(refresh: true);
    } else {
      print('❌ No token found, redirecting to login');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  Future<void> _loadFavoritesStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final favJsonList = prefs.getStringList('favorites') ?? [];
    final favList = favJsonList.map((jsonStr) => json.decode(jsonStr)).toList();
    final Map<int, bool> tempMap = {};
    for (var f in favList) {
      tempMap[f['id']] = true;
    }
    setState(() {
      isFavoriteMap = tempMap;
    });
  }

  Future<void> _toggleFavorite(Word word) async {
    final prefs = await SharedPreferences.getInstance();
    final favJsonList = prefs.getStringList('favorites') ?? [];
    final favList = favJsonList.map((jsonStr) => json.decode(jsonStr)).toList();

    bool wasFavorite = isFavoriteMap[word.id] ?? false;

    if (wasFavorite) {
      favList.removeWhere((f) => f['id'] == word.id);
    } else {
      favList.add(word.toJson());
    }

    final newFavJsonList = favList.map((f) => json.encode(f)).toList();
    await prefs.setStringList('favorites', newFavJsonList);

    setState(() {
      isFavoriteMap[word.id] = !wasFavorite;
    });

    // Optional: small feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasFavorite ? 'បានដកចេញពាក្យដែលបានចូលចិត្ត' : 'បានបញ្ចូលពាក្យចូលចិត្ត',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _loadWords({bool refresh = false}) async {
    if ((isLoading || isLoadingMore) || token == null) {
      return;
    }

    setState(() {
      if (refresh) {
        isLoading = true;
        offset = 0;
        words.clear();
        errorMessage = null;
        debugInfo = 'Loading fresh data...';
      } else {
        isLoadingMore = true;
        debugInfo = 'Loading more (offset: $offset)...';
      }
    });

    try {
      final uri = Uri.parse(
        'https://nubbdictapi.kode4u.tech/api/dictionary?limit=$limit&offset=$offset${query.isNotEmpty ? '&query=$query' : ''}',
      );

      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['words'] == null) {
          setState(() {
            errorMessage = 'API returned invalid format (no "words" field)';
          });
          return;
        }

        final wordsList = data['words'] as List;
        final newWords = wordsList.map((j) => Word.fromJson(j)).toList();

        setState(() {
          words.addAll(newWords);
          offset += limit;
          errorMessage = null;
          debugInfo = 'Loaded ${newWords.length} words. Total: ${words.length}';
        });
      } else if (response.statusCode == 401) {
        await _authService.logout();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else if (response.statusCode == 429) {
        final data = json.decode(response.body);
        setState(() {
          errorMessage = data['message'] ?? 'Rate limit exceeded';
        });
      } else {
        setState(() {
          errorMessage = 'Error loading words: ${response.statusCode}';
        });
      }
    } on TimeoutException {
      setState(() {
        errorMessage = 'Connection timeout. Please try again.';
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        query = value;
        debugInfo = 'Searching for: "$value"';
      });
      _loadWords(refresh: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(color: Colors.blue.shade700),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'ស្វែងរកពាក្យ...',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Color.fromARGB(255, 225, 151, 145)),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (debugInfo != null) const SizedBox(height: 4),
        if (errorMessage != null)
          Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'ដំណើរការ...',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : words.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        query.isEmpty
                            ? 'សូមបញ្ចូលពាក្យស្វែងរក'
                            : 'គ្មានពាក្យ "$query"',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      if (query.isEmpty) ...[
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _loadWords(refresh: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('ទាយពាក្យម្តងទៀត'),
                        ),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadWords(refresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: words.length + (isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == words.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final word = words[index];
                      final bool isFavorite = isFavoriteMap[word.id] ?? false;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          // border: Border.all(color: const Color(0xFFE0E0E0)),
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
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              word.partOfSpeech,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isFavorite
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: isFavorite
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade400,
                                ),
                                onPressed: () => _toggleFavorite(word),
                              ),

                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.grey.shade500,
                                size: 14,
                              ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DetailPage(wordId: word.id),
                              ),
                            );
                            // Refresh favorite status when coming back (in case user changed it in detail page)
                            _loadFavoritesStatus();
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
