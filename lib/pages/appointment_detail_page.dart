import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../services/api_client.dart';

enum AppointmentStatus { pending, confirmed, cancelled }

class AppointmentDetailPage extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const AppointmentDetailPage({super.key, required this.appointment});

  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  final TextEditingController _noteController = TextEditingController();
  late AppointmentStatus _status;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final statusStr = widget.appointment['status'] ?? 'pending';
    _status = _parseStatus(statusStr);
    _noteController.text = widget.appointment['notes'] ?? '';
  }

  AppointmentStatus _parseStatus(String status) {
    switch (status) {
      case 'confirmed': return AppointmentStatus.confirmed;
      case 'cancelled': return AppointmentStatus.cancelled;
      default: return AppointmentStatus.pending;
    }
  }

  String _statusToString(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.confirmed: return 'confirmed';
      case AppointmentStatus.cancelled: return 'cancelled';
      default: return 'pending';
    }
  }

  bool get _isConfirmed => _status == AppointmentStatus.confirmed;
  bool get _isCancelled => _status == AppointmentStatus.cancelled;

  Future<void> _updateAppointmentStatus(AppointmentStatus newStatus) async {
    final appointmentId = widget.appointment['id'] ?? widget.appointment['_id'];
    if (appointmentId == null) {
      showAppSnackBar(context, 'Randevu kimliği bulunamadı.', isError: true);
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final body = <String, dynamic>{'status': _statusToString(newStatus)};
      if (_noteController.text.trim().isNotEmpty) {
        body['notes'] = _noteController.text.trim();
      }

      final response = await ApiClient().put(
        '/api/appointment/$appointmentId',
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        setState(() => _status = newStatus);
        showAppSnackBar(context, newStatus == AppointmentStatus.confirmed
            ? 'Randevu onaylandı.'
            : 'Randevu iptal edildi.');
      } else if (response.statusCode == 409) {
        final data = jsonDecode(response.body);
        showAppSnackBar(context, data['error'] ?? 'Bu işlem şu anda gerçekleştirilemiyor.', isError: true);
      } else if (response.statusCode == 403) {
        showAppSnackBar(context, 'Bu işlem için yetkiniz yok.', isError: true);
      } else {
        showAppSnackBar(context, 'Randevu durumu güncellenemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (e) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _saveNotes() async {
    final appointmentId = widget.appointment['id'] ?? widget.appointment['_id'];
    if (appointmentId == null) {
      showAppSnackBar(context, 'Randevu kimliği bulunamadı.', isError: true);
      return;
    }

    try {
      final response = await ApiClient().put(
        '/api/appointment/$appointmentId',
        body: jsonEncode({'notes': _noteController.text.trim()}),
      );

      if (response.statusCode == 200) {
        showAppSnackBar(context, 'Not kaydedildi.');
      } else {
        showAppSnackBar(context, 'Not kaydedilemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (e) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  void _confirmAppointment() {
    if (_isCancelled || _isUpdating) return;
    _updateAppointmentStatus(AppointmentStatus.confirmed);
  }

  void _cancelAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(color: context.ct.errorSoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: Spacing.md),
            Text('Randevuyu İptal Et', style: TextStyle(color: context.ct.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Bu randevuyu iptal etmek istediğinize emin misiniz?\nMüşteri bilgilendirilecektir.',
          style: TextStyle(color: context.ct.textSecondary, fontSize: 14, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(Spacing.xxl, 0, Spacing.xxl, Spacing.xl),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.ct.textSecondary,
                    side: BorderSide(color: context.ct.surfaceBorder),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text('Vazgeç'),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text('Evet, İptal Et', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _updateAppointmentStatus(AppointmentStatus.cancelled);
    }
  }

  void _handleCancelPressed() {
    if (_isConfirmed && !_isCancelled) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: context.ct.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(color: context.ct.warningSoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(child: Text('Randevuyu İptal Et', style: TextStyle(color: context.ct.textPrimary, fontSize: 18, fontWeight: FontWeight.w700))),
            ],
          ),
          content: Text(
            'Bu randevu onaylanmış durumda. İptal ederseniz müşteri bilgilendirilecektir. Devam etmek istiyor musunuz?',
            style: TextStyle(color: context.ct.textSecondary, fontSize: 14, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(Spacing.xxl, 0, Spacing.xxl, Spacing.xl),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.ct.textSecondary,
                      side: BorderSide(color: context.ct.surfaceBorder),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelAppointment();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('Evet, İptal Et', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      _cancelAppointment();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appointment;

    String statusLabel;
    switch (_status) {
      case AppointmentStatus.confirmed:
        statusLabel = 'confirmed';
        break;
      case AppointmentStatus.cancelled:
        statusLabel = 'cancelled';
        break;
      default:
        statusLabel = 'pending';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: 'Randevu Detayı'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, Spacing.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Status Badge ──
                    AppStatusBadge(status: statusLabel),
                    const SizedBox(height: Spacing.xl),

                    // ── Customer Name ──
                    Text(
                      appt['customer'] ?? 'Bilinmeyen Müşteri',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: Spacing.xl),

                    // ── Info Cards ──
                    _buildDetailTile(Icons.calendar_today_rounded, 'Tarih', appt['date'] ?? 'Bilinmiyor'),
                    _buildDetailTile(Icons.access_time_rounded, 'Saat', appt['time'] ?? 'Bilinmiyor'),
                    if (appt['phone'] != null && appt['phone'] != '-')
                      _buildDetailTile(Icons.phone_rounded, 'Telefon', appt['phone']),

                    const SizedBox(height: Spacing.xxl),

                    // ── Notes Section ──
                    Row(
                      children: [
                        Text('Notlar', style: Theme.of(context).textTheme.headlineSmall),
                        const Spacer(),
                        Material(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: InkWell(
                            onTap: _saveNotes,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.save_outlined, color: AppColors.primary, size: 16),
                                  SizedBox(width: Spacing.xs),
                                  Text('Kaydet', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      controller: _noteController,
                      maxLines: 4,
                      style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Not ekleyin...',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Action Buttons ──
            if (!_isCancelled)
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_isCancelled || _isUpdating) ? null : _confirmAppointment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isConfirmed ? AppColors.success : AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ),
                          child: _isUpdating && !_isCancelled
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text(
                                  _isConfirmed ? 'Onaylandı ✓' : 'Onayla',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isUpdating ? null : _handleCancelPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.ct.surfaceLight,
                            foregroundColor: context.ct.textPrimary,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ),
                          child: const Text('İptal Et', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: Material(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: Spacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
