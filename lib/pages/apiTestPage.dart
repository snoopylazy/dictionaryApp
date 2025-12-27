import 'dart:convert';
import 'package:dictionaryapp/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiTestPage extends StatefulWidget {
  const ApiTestPage({super.key});

  @override
  State<ApiTestPage> createState() => _ApiTestPageState();
}

class _ApiTestPageState extends State<ApiTestPage> {
  final AuthService _authService = AuthService();
  String? token;
  String output = 'Ready to test API...';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _getToken();
  }

  Future<void> _getToken() async {
    token = await _authService.getToken();
    setState(() {
      output = token != null 
        ? 'Token loaded: ${token!.substring(0, 30)}...\n\nReady to test API!'
        : 'No token found!';
    });
  }

  Future<void> _testHealthEndpoint() async {
    setState(() {
      isLoading = true;
      output = 'Testing health endpoint...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://nubbdictapi.kode4u.tech/api/health'),
      ).timeout(const Duration(seconds: 10));

      setState(() {
        output = '''
✅ Health Check
Status: ${response.statusCode}
Body: ${response.body}
''';
      });
    } catch (e) {
      setState(() {
        output = '❌ Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _testDictionaryWithoutQuery() async {
    if (token == null) {
      setState(() {
        output = '❌ No token! Please login first.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      output = 'Testing dictionary endpoint (no query)...';
    });

    try {
      final uri = Uri.parse('https://nubbdictapi.kode4u.tech/api/dictionary?limit=5&offset=0');
      print('📡 Request URL: $uri');
      
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      print('📊 Status: ${response.statusCode}');
      print('📦 Body: ${response.body}');

      final prettyJson = JsonEncoder.withIndent('  ').convert(json.decode(response.body));

      setState(() {
        output = '''
✅ Dictionary (No Query)
Status: ${response.statusCode}
Response:
$prettyJson
''';
      });
    } catch (e) {
      setState(() {
        output = '❌ Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _testDictionaryWithQuery() async {
    if (token == null) {
      setState(() {
        output = '❌ No token! Please login first.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      output = 'Testing dictionary endpoint (query: "hello")...';
    });

    try {
      final uri = Uri.parse('https://nubbdictapi.kode4u.tech/api/dictionary?query=hello&limit=5');
      
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      final prettyJson = JsonEncoder.withIndent('  ').convert(json.decode(response.body));

      setState(() {
        output = '''
✅ Dictionary (Query: "hello")
Status: ${response.statusCode}
Response:
$prettyJson
''';
      });
    } catch (e) {
      setState(() {
        output = '❌ Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _testPlansEndpoint() async {
    setState(() {
      isLoading = true;
      output = 'Testing plans endpoint...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://nubbdictapi.kode4u.tech/api/subscription/plans'),
      ).timeout(const Duration(seconds: 10));

      final prettyJson = JsonEncoder.withIndent('  ').convert(json.decode(response.body));

      setState(() {
        output = '''
✅ Subscription Plans
Status: ${response.statusCode}
Response:
$prettyJson
''';
      });
    } catch (e) {
      setState(() {
        output = '❌ Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Test Page'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: isLoading ? null : _testHealthEndpoint,
                  child: const Text('Test Health'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : _testDictionaryWithoutQuery,
                  child: const Text('Test Dictionary (All)'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : _testDictionaryWithQuery,
                  child: const Text('Test Search "hello"'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : _testPlansEndpoint,
                  child: const Text('Test Plans'),
                ),
                ElevatedButton(
                  onPressed: _getToken,
                  child: const Text('Refresh Token'),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  output,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}