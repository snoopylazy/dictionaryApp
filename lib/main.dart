import 'package:dictionaryapp/pages/loginPage.dart';
import 'package:dictionaryapp/pages/favoritePage.dart';
import 'package:dictionaryapp/pages/homePage.dart';
import 'package:dictionaryapp/pages/subscriptionPage.dart';
import 'package:dictionaryapp/pages/apiTestPage.dart';
import 'package:dictionaryapp/services/auth_service.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  // Add a key to force rebuild
  Key _appKey = UniqueKey();

  final List<Widget> _pages = [
    const HomePage(),
    const FavoritePage(),
    const SubscriptionPage(),
  ];

  final List<String> _titles = [
    'វេចនានុក្រម អង់គ្លេស-ខ្មែរ',
    'ចំណូលចិត្ត',
    'ជាវសេវា',
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: _appKey, // Add this key
      debugShowCheckedModeBanner: false,
      title: 'វេចនានុក្រម',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade700),
        fontFamily: 'Noto',
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _authService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.data == true) {
            return _buildMainApp();
          } else {
            return const LoginPage();
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => _buildMainApp(),
        '/api-test': (context) => const ApiTestPage(),
      },
    );
  }

  Widget _buildMainApp() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 20,),
            onPressed: () async {
              await _authService.logout();
              if (mounted) {
                // Force complete app rebuild by changing the key
                setState(() {
                  _currentIndex = 0; // Reset to home tab
                  _appKey = UniqueKey(); // This forces MaterialApp to rebuild
                });
              }
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.book),
              ),
              label: 'វេនានុក្រម',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.bookmark),
              ),
              label: 'ចំណូលចិត្ត',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.subscriptions),
              ),
              label: 'ជាវសេវា',
            ),
          ],
        ),
      ),
    );
  }
}