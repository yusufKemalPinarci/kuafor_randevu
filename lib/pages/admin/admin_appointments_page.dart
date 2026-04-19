import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../services/api_client.dart';

class AdminAppointmentsPage extends StatefulWidget {
  const AdminAppointmentsPage({super.key});

  @override
  State<AdminAppointmentsPage> createState() => _AdminAppointmentsPageState();
}

class _AdminAppointmentsPageState extends State<AdminAppointmentsPage> {
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  int _page = 1;
  int _totalPages = 1;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments({int page = 1}) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().get('/api/admin/appointments?page=$page&limit=20${_statusFilter != null ? '&status=$_statusFilter' : ''}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _appointments = data['appointments'] ?? [];
          _page = data['page'] ?? 1;
          _totalPages = data['totalPages'] ?? 1;
          _isLoading = false;
        });
      } else {
        if (mounted) showAppSnackBar(context, 'Randevular yüklenemedi.', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Bağlantı hatası.', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String apptId, String newStatus) async {
    try {
      final response = await ApiClient().put(
        '/api/admin/appointments/$apptId',
        body: jsonEncode({'status': newStatus}),
      );
      if (response.statusCode == 200) {
        showAppSnackBar(context, 'Randevu güncellendi.');
        _fetchAppointments(page: _page);
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Randevu güncellenemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  Future<void> _deleteAppointment(String apptId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text('Randevuyu Sil', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Bu randevuyu silmek istediğinize emin misiniz?', style: TextStyle(color: context.ct.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: context.ct.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await ApiClient().delete('/api/admin/appointments/$apptId');
      if (response.statusCode == 200) {
        showAppSnackBar(context, 'Randevu silindi.');
        _fetchAppointments(page: _page);
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Randevu silinemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(null, 'Tümü'),
                const SizedBox(width: Spacing.sm),
                _filterChip('pending', 'Bekliyor'),
                const SizedBox(width: Spacing.sm),
                _filterChip('confirmed', 'Onaylandı'),
                const SizedBox(width: Spacing.sm),
                _filterChip('completed', 'Tamamlandı'),
                const SizedBox(width: Spacing.sm),
                _filterChip('cancelled', 'İptal'),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _appointments.isEmpty
                  ? AppEmptyState(icon: Icons.calendar_today_outlined, title: 'Randevu bulunamadı')
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => _fetchAppointments(page: _page),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
                        itemCount: _appointments.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i == _appointments.length) return _buildPagination();
                          return _buildAppointmentCard(_appointments[i]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String? value, String label) {
    final selected = _statusFilter == value;
    return GestureDetector(
      onTap: () { setState(() => _statusFilter = value); _fetchAppointments(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : context.ct.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.primary : context.ct.surfaceBorder),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : context.ct.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildAppointmentCard(dynamic appt) {
    final apptId = appt['_id'] ?? '';
    final status = appt['status'] ?? 'pending';
    final customerName = appt['customerName'] ?? (appt['customerId'] is Map ? appt['customerId']['name'] ?? '-' : '-');
    final barber = appt['barberId'];
    final barberName = barber is Map ? (barber['name'] ?? '-') : '-';
    final service = appt['serviceId'];
    final serviceTitle = service is Map ? (service['title'] ?? '-') : '-';
    final date = appt['date'] ?? '';
    final startTime = appt['startTime'] ?? '';
    final endTime = appt['endTime'] ?? '';
    final notes = appt['notes'] ?? '';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'confirmed':
        statusColor = AppColors.success;
        statusLabel = 'Onaylandı';
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor = AppColors.info;
        statusLabel = 'Tamamlandı';
        statusIcon = Icons.done_all;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusLabel = 'İptal';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.warning;
        statusLabel = 'Bekliyor';
        statusIcon = Icons.schedule;
    }

    String formatDate(String d) {
      if (d.isEmpty) return '-';
      try { return d.substring(0, 10); } catch (_) { return d; }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: context.ct.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Customer + Status
            Row(
              children: [
                AppAvatar(letter: customerName, size: 40, withShadow: false),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName, style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      Row(
                        children: [
                          Icon(Icons.content_cut, size: 12, color: context.ct.textHint),
                          const SizedBox(width: 3),
                          Text(barberName, style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 2, vertical: Spacing.xs),
                  decoration: BoxDecoration(color: statusColor.withAlpha(18), borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 13),
                      const SizedBox(width: 3),
                      Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: Spacing.md),

            // Details row
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(color: context.ct.bg, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  _detailItem(Icons.spa_outlined, serviceTitle),
                  const SizedBox(width: Spacing.lg),
                  _detailItem(Icons.calendar_today, formatDate(date)),
                  const SizedBox(width: Spacing.lg),
                  _detailItem(Icons.access_time, '$startTime - $endTime'),
                ],
              ),
            ),

            if (notes.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              Text('Not: $notes', style: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontStyle: FontStyle.italic)),
            ],

            const SizedBox(height: Spacing.md),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'pending') ...[
                  _actionBtn('Onayla', AppColors.success, () => _updateStatus(apptId, 'confirmed')),
                  const SizedBox(width: Spacing.sm),
                ],
                if (status == 'confirmed')
                  _actionBtn('Tamamla', AppColors.info, () => _updateStatus(apptId, 'completed')),
                if (status != 'cancelled' && status != 'completed') ...[
                  const SizedBox(width: Spacing.sm),
                  _actionBtn('İptal Et', AppColors.warning, () => _updateStatus(apptId, 'cancelled')),
                ],
                const SizedBox(width: Spacing.sm),
                AppIconBtn(
                  icon: Icons.delete_outline,
                  tooltip: 'Sil',
                  size: 32,
                  iconColor: AppColors.error,
                  onTap: () => _deleteAppointment(apptId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String label) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: context.ct.textHint),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: TextStyle(color: context.ct.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withAlpha(15),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
          child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox(height: Spacing.huge);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _paginationBtn(Icons.chevron_left, _page > 1, () => _fetchAppointments(page: _page - 1)),
          const SizedBox(width: Spacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm + 2),
            decoration: BoxDecoration(color: context.ct.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Text('$_page / $_totalPages', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: Spacing.md),
          _paginationBtn(Icons.chevron_right, _page < _totalPages, () => _fetchAppointments(page: _page + 1)),
        ],
      ),
    );
  }

  Widget _paginationBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: enabled ? AppColors.primary : context.ct.surfaceLight,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm + 2),
          child: Icon(icon, color: enabled ? Colors.white : context.ct.textHint, size: 22),
        ),
      ),
    );
  }
}
