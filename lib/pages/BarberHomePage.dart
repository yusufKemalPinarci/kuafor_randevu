import 'package:flutter/material.dart';
import 'package:kuafor_randevu/pages/appointment_detail_page.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';

class BarberHomePage extends StatefulWidget {
  const BarberHomePage({super.key});

  @override
  State<BarberHomePage> createState() => _BarberHomePageState();
}


class _BarberHomePageState extends State<BarberHomePage> {
  final List<Map<String, String>> todaysAppointments = [
    {
      'customer': 'Ahmet Yılmaz',
      'time': '10:00',
      'phone': '+90 555 111 2233',
    },
    {
      'customer': 'Mehmet Kaya',
      'time': '11:30',
      'phone': '+90 555 222 3344',
    },
    {
      'customer': 'Ayşe Demir',
      'time': '14:00',
      'phone': '+90 555 333 4455',
    },
  ];

 @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context,listen: false);

    final totalAppointments = todaysAppointments.length;
    bool isVerified = true; // Bunu sen API’den çekeceksin
    bool hasShop = userProvider.user?.shopId != " ";   // dükkanı var mı yok mu bunu da api den çekicez
    int maxAppointments = 10; // bu gün ne kadar randevu alabilecek.bu kısmı nasıl ayarlıyacaz.
    print("dükkan id");
    print(userProvider.user?.shopId);
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: const Text(
          'Berber Paneli',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Color(0xFFC69749), size: 28),
            onPressed: () {
              // Bildirim sayfası açılacak (şimdilik boş)
            },
          ),
          IconButton(
            icon: Icon(
              Icons.storefront,
              color: isVerified && hasShop ? const Color(0xFFC69749) : Colors.white24,
              size: 28,
            ),
            onPressed: () {
              if (!isVerified) {
                // Telefon veya e-posta doğrulanmamışsa
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Doğrulama Gerekli', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Dükkan bilgilerine erişmek için önce telefon ve e-posta doğrulaması yapmalısınız.',
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
              } else if (!hasShop) {
                // Doğrulanmış ama dükkan oluşturulmamışsa
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Dükkan Gerekli', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Dükkan bilgilerini görüntülemek için önce bir dükkan oluşturmalısınız.',
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
                // Doğrulanmış ve dükkan seçilmişse
                Navigator.pushNamed(context, '/shop_detail_page');
              }
            },
          ),

          IconButton(
            icon: const Icon(Icons.account_circle, size: 32, color: Color(0xFFC69749)),
            onPressed: () {
              Navigator.pushNamed(context, '/profile_page');
              // Profil sayfasına yönlendirme ekle
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Toplam Randevu',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalAppointments',
                          style: const TextStyle(
                            color: Color(0xFFC69749),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/set-daily-capacity');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Doluluk Oranı',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(totalAppointments / maxAppointments * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Color(0xFFC69749),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  ,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Bugünün Randevuları Listesi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'Bugünün Randevuları',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: todaysAppointments.length,
                      itemBuilder: (context, index) {
                        final appt = todaysAppointments[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AppointmentDetailPage(
                                  appointment: {
                                    'customer': appt['customer'],
                                    'date': '2025-08-05', // API’den ya da uygun şekilde dinamik alınabilir
                                    'time': appt['time'],
                                    'phone': appt['phone'],
                                  },
                                ),
                              ),
                            );
                          },
                          child: Card(
                            color: const Color(0xFF2C2C2C),
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Müşteri adı ve saat
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        appt['customer'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        appt['time'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Telefon numarası ve ok ikonu
                                  Row(
                                    children: [
                                      Text(
                                        appt['phone'] ?? '',
                                        style: const TextStyle(
                                          color: Color(0xFFC69749),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_ios, color: Color(0xFFC69749), size: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
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
                  'Tüm Randevuları Görüntüle',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),


          ],
        ),
      ),
    );
  }
}
