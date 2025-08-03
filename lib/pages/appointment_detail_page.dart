import 'package:flutter/material.dart';

enum AppointmentStatus { pending, confirmed, cancelled }

class AppointmentDetailPage extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const AppointmentDetailPage({super.key, required this.appointment});

  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  final TextEditingController _noteController = TextEditingController();

  AppointmentStatus _status = AppointmentStatus.pending;

  bool get _isConfirmed => _status == AppointmentStatus.confirmed;
  bool get _isCancelled => _status == AppointmentStatus.cancelled;

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _confirmAppointment() {
    if (_isCancelled) return; // İptal edilmişse onaylama engellenir
    setState(() {
      _status = AppointmentStatus.confirmed;
    });
    _showMessage('Randevu onaylandı.');
    // API entegrasyonu yapılabilir
  }


  void _cancelAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          'Randevuyu İptal Et',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Bu randevuyu iptal etmek istediğinize emin misiniz?\nMüşteri bilgilendirilecektir.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _status = AppointmentStatus.cancelled;
      });
      _showMessage('Randevu iptal edildi, müşteri bilgilendirildi.');
      // API ile iptal ve bilgilendirme işlemi yapılmalı
    }
  }



  void _showCancellationWarningDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Randevuyu İptal Et'),
        content: const Text(
            'Bu randevu onaylanmış durumda. İptal ederseniz müşteri bilgilendirilecektir. Devam etmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelAppointment();
            },
            child: const Text('Evet, İptal Et'),
          ),
        ],
      ),
    );
  }

  void _handleCancelPressed() {
    if (_isConfirmed && !_isCancelled) {
      _showCancellationWarningDialog();
    } else {
      _cancelAppointment();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appointment;

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        title: const Text('Randevu Detayı'),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appt['customer'] ?? 'Bilinmeyen Müşteri',
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Tarih: ${appt['date'] ?? 'Bilinmiyor'}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Saat: ${appt['time'] ?? 'Bilinmiyor'}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),

            const Text(
              'Notlar',
              style: TextStyle(
                  color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                hintText: 'Not ekleyin...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const Spacer(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isCancelled ? null : _confirmAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    _isConfirmed ? Colors.green : const Color(0xFFC69749),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _isConfirmed ? 'Onaylandı' : 'Onayla',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isCancelled ? null : _handleCancelPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCancelled ? Colors.red : Colors.grey[800],
                    padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _isCancelled ? 'İptal Edildi' : 'İptal Et',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
