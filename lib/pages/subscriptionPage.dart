import 'dart:convert';
import 'package:dictionaryapp/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SubscriptionPlan {
  final String id;
  final String name;
  final int rateLimit;
  final double price;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.rateLimit,
    required this.price,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'],
      name: json['name'],
      rateLimit: json['rateLimit'],
      price: json['price'].toDouble(),
    );
  }
}

class RateLimitInfo {
  final int rateLimit;
  final int currentCount;
  final int remaining;
  final String resetAt;

  RateLimitInfo({
    required this.rateLimit,
    required this.currentCount,
    required this.remaining,
    required this.resetAt,
  });

  factory RateLimitInfo.fromJson(Map<String, dynamic> json) {
    return RateLimitInfo(
      rateLimit: json['rateLimit'],
      currentCount: json['currentCount'],
      remaining: json['remaining'],
      resetAt: json['resetAt'],
    );
  }
}

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  List<SubscriptionPlan> plans = [];
  String? currentPlanId;
  RateLimitInfo? rateLimitInfo;
  bool isLoading = true;
  String? errorMessage;
  final AuthService _authService = AuthService();
  String? token;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    token = await _authService.getToken();
    if (token == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }
    await _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    await Future.wait([
      _loadPlans(),
      _loadCurrentSubscription(),
      _loadRateLimitInfo(),
    ]);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadPlans() async {
    try {
      final uri = Uri.parse(
        'https://nubbdictapi.kode4u.tech/api/subscription/plans',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final planList = (data['plans'] as List)
            .map((j) => SubscriptionPlan.fromJson(j))
            .toList();
        setState(() {
          plans = planList;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading plans: ${e.toString()}';
      });
    }
  }

  Future<void> _loadCurrentSubscription() async {
    if (token == null) return;

    try {
      final uri = Uri.parse(
        'https://nubbdictapi.kode4u.tech/api/subscription/current',
      );
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentPlanId = data['plan'];
        });
      } else if (response.statusCode == 401) {
        await _authService.logout();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading subscription: ${e.toString()}';
      });
    }
  }

  Future<void> _loadRateLimitInfo() async {
    if (token == null) return;

    try {
      final uri = Uri.parse(
        'https://nubbdictapi.kode4u.tech/api/subscription/rate-limit',
      );
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          rateLimitInfo = RateLimitInfo.fromJson(data);
        });
      }
    } catch (e) {
      // Rate limit info is optional, don't show error
    }
  }

  Future<void> _subscribe(String planId) async {
    if (token == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('បញ្ជាក់ការជាវ'),
        content: Text(
          'Subscribe to ${plans.firstWhere((p) => p.id == planId).name} plan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('បោះបង់'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ជាវ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uri = Uri.parse(
        'https://nubbdictapi.kode4u.tech/api/subscription/subscribe',
      );
      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({'planId': planId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ជាវសេវាថ្លើកាលវិភាគដោយជោគជ័យ!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadAllData();
      } else if (response.statusCode == 401) {
        await _authService.logout();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'ការជាវបរាជ័យ។'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            if (rateLimitInfo != null)
              Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.speed,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'អត្រាកំណត់ការប្រើប្រាស់',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value:
                                rateLimitInfo!.remaining /
                                rateLimitInfo!.rateLimit,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              rateLimitInfo!.remaining >
                                      rateLimitInfo!.rateLimit * 0.2
                                  ? Colors.greenAccent.shade400
                                  : Colors.orangeAccent.shade400,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'នៅសល់',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${rateLimitInfo!.remaining} / ${rateLimitInfo!.rateLimit}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'បានប្រើប្រាស់ ${rateLimitInfo!.currentCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (errorMessage != null)
              Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final isActive = plan.id == currentPlanId;
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isActive ? null : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive
                          ? Colors.blue.shade300
                          : Colors.grey.shade300,
                      width: isActive ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isActive
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                        blurRadius: isActive ? 12 : 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getPlanIcon(plan.id),
                                size: 28,
                                color: isActive
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        plan.name,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isActive
                                              ? Colors.blue.shade700
                                              : Colors.grey.shade800,
                                        ),
                                      ),
                                      if (isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.green.shade400,
                                                Colors.green.shade600,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.green.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Text(
                                            'ដំណើរការ',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plan.price == 0
                                        ? 'ឥតគិតថ្លៃ'
                                        : '\$${plan.price.toStringAsFixed(2)}/ខែ',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: plan.price == 0
                                          ? Colors.green.shade600
                                          : Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white.withOpacity(0.7)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${plan.rateLimit} ស្នើរក្នុង១ម៉ោងម្ដង',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isActive) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _subscribe(plan.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'ជាវ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPlanIcon(String planId) {
    switch (planId) {
      case 'free':
        return Icons.free_breakfast;
      case 'basic':
        return Icons.star_border;
      case 'premium':
        return Icons.star;
      case 'enterprise':
        return Icons.business;
      default:
        return Icons.subscriptions;
    }
  }
}
