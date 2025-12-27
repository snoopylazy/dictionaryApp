import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  static const String _baseUrl = 'https://nubbdictapi.kode4u.tech';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('🌐 Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      print('📍 Attempting login to: $_baseUrl/api/auth/login');
      print('📧 Email: $email');
      
      final uri = Uri.parse('$_baseUrl/api/auth/login');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Connection timeout after 15 seconds');
        },
      );

      print('📊 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['token'] == null) {
          return {'success': false, 'error': 'No token received from server'};
        }
        
        final token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userKey, json.encode(data['user']));
        
        print('✅ Login successful!');
        return {'success': true};
      } else {
        try {
          final err = json.decode(response.body);
          final errorMsg = err['error'] ?? 'Login failed (${response.statusCode})';
          print('❌ Login failed: $errorMsg');
          return {'success': false, 'error': errorMsg};
        } catch (e) {
          return {'success': false, 'error': 'Login failed: ${response.statusCode}'};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Timeout: ${e.message}');
      return {
        'success': false,
        'error': 'Connection timeout. Please check your internet connection.'
      };
    } on http.ClientException catch (e) {
      print('🔌 Network error: ${e.message}');
      
      // Special handling for CORS on web
//       if (kIsWeb && e.message != null && e.message!.contains('XMLHttpRequest')) {
//         return {
//           'success': false,
//           'error': '''CORS Error: You're running on Flutter Web.
          
// Solution: Run on mobile instead:
//   flutter run

// Or disable CORS for testing:
//   flutter run -d chrome --web-browser-flag "--disable-web-security"

// Mobile apps (Android/iOS) don't have CORS issues.'''
//         };
//       }
      
      return {
        'success': false,
        // 'error': 'Network error: ${e.message ?? "Unable to connect to server"}'
      };
    } catch (e) {
      print('💥 Unexpected error: $e');
      return {
        'success': false,
        'error': 'Error: ${e.toString()}'
      };
    }
  }

  Future<Map<String, dynamic>> signup(String name, String email, String password) async {
    try {
      print('🌐 Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      print('📍 Attempting signup to: $_baseUrl/api/auth/signup');
      print('📧 Email: $email');
      print('👤 Name: $name');
      
      final uri = Uri.parse('$_baseUrl/api/auth/signup');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Connection timeout after 15 seconds');
        },
      );

      print('📊 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['token'] == null) {
          return {'success': false, 'error': 'No token received from server'};
        }
        
        final token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userKey, json.encode(data['user']));
        
        print('✅ Signup successful!');
        return {'success': true};
      } else {
        try {
          final err = json.decode(response.body);
          final errorMsg = err['error'] ?? 'Signup failed (${response.statusCode})';
          print('❌ Signup failed: $errorMsg');
          return {'success': false, 'error': errorMsg};
        } catch (e) {
          return {'success': false, 'error': 'Signup failed: ${response.statusCode}'};
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ Timeout: ${e.message}');
      return {
        'success': false,
        'error': 'Connection timeout. Please check your internet connection.'
      };
    } on http.ClientException catch (e) {
      print('🔌 Network error: ${e.message}');
      
      // Special handling for CORS on web
//       if (kIsWeb && e.message != null && e.message!.contains('XMLHttpRequest')) {
//         return {
//           'success': false,
//           'error': '''CORS Error: You're running on Flutter Web.
          
// Solution: Run on mobile instead:
//   flutter run

// Or disable CORS for testing:
//   flutter run -d chrome --web-browser-flag "--disable-web-security"

// Mobile apps (Android/iOS) don't have CORS issues.'''
//         };
//       }
      
      return {
        'success': false,
        // 'error': 'Network error: ${e.message ?? "Unable to connect to server"}'
      };
    } catch (e) {
      print('💥 Unexpected error: $e');
      return {
        'success': false,
        'error': 'Error: ${e.toString()}'
      };
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    print('🚪 User logged out');
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    return userJson != null ? json.decode(userJson) : null;
  }
}