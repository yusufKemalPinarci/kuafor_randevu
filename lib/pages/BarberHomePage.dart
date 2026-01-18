import 'package:flutter/material.dart';
import 'package:kuafor_randevu/pages/appointment_detail_page.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';
import '../providers/user_provider.dart';

class BarberHomePage extends StatefulWidget {
  const BarberHomePage({super.key});

  @override
  State<BarberHomePage> createState() => _BarberHomePageState();
}

class _BarberHomePageState extends State<BarberHomePage> {
  List<dynamic> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/appointment/my_berber'),
        headers: {
          'Authorization': 'Bearer ${userProvider.user?.jwtToken}',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _appointments = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching appointments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    final totalAppointments = _appointments.length;
    final pendingCount = _appointments.where((a) => a['status'] == 'pending').length;
    final confirmedCount = _appointments.where((a) => a['status'] == 'confirmed').length;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final todaysCount = _appointments.where((a) => a['date'].startsWith(today)).length;

    bool isVerified = user?.isPhoneVerified ?? false;
    bool hasShop = user?.shopId != null && user!.shopId!.trim().isNotEmpty;
    int maxAppointments = 10;

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: Text(
          'Hoşgeldin, ${user?.name ?? "Berber"}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Color(0xFFC69749), size: 28),
            onPressed: () {
              // Bildirim sayfası açılacak
            },
          ),
          IconButton(
            icon: Icon(
              Icons.storefront,
              color: hasShop ? const Color(0xFFC69749) : Colors.white24,
              size: 28,
            ),
            onPressed: () {
              if (!hasShop) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Dükkan Gerekli', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Dükkan bilgilerini görüntülemek için önce bir dükkan oluşturmalı veya bir dükkana atanmalısınız.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('İptal', style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/profile_page');
                        },
                        child: const Text('Profil Sayfası', style: TextStyle(color: Color(0xFFC69749))),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.pushNamed(context, '/shop_detail_page');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, size: 32, color: Color(0xFFC69749)),
            onPressed: () {
              Navigator.pushNamed(context, '/profile_page');
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC69749)))
          : RefreshIndicator(
              onRefresh: _fetchAppointments,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('Bugün', '$todaysCount'),
                        ),
                        Expanded(
                          child: _buildStatCard('Bekleyen', '$pendingCount'),
                        ),
                        Expanded(
                          child: _buildStatCard('Onaylı', '$confirmedCount'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('Toplam Randevu', '$totalAppointments'),
                        ),
                        Expanded(
                          child: _buildStatCard('Doluluk Oranı',
                            '${(todaysCount / maxAppointments * 100).clamp(0, 100).toStringAsFixed(1)}%'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        'Randevularınız',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _appointments.isEmpty
                          ? const Center(child: Text('Henüz randevunuz bulunmuyor.', style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              itemCount: _appointments.length,
                              itemBuilder: (context, index) {
                                final appt = _appointments[index];
                                return _buildAppointmentCard(appt);
                              },
                            ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/allAppointments');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC69749),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text(
                                'Randevular',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/manage-services');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC69749),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text(
                                'Hizmetlerim',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Color(0xFFC69749), fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(dynamic appt) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentDetailPage(
              appointment: {
                'customer': appt['customerName'],
                'date': appt['date'],
                'time': appt['startTime'],
                'phone': appt['customerPhone'],
                'status': appt['status'],
                'service': appt['serviceId']?['title'] ?? 'Hizmet Bilgisi Yok',
              },
            ),
          ),
        );
      },
      child: Card(
        color: const Color(0xFF2C2C2C),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt['customerName'] ?? 'Bilinmeyen Müşteri',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${appt['date'].split('T')[0]} - ${appt['startTime']}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    appt['status'] == 'pending' ? 'Bekliyor' : 'Onaylandı',
                    style: TextStyle(
                      color: appt['status'] == 'pending' ? Colors.orange : Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.arrow_forward_ios, color: Color(0xFFC69749), size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
