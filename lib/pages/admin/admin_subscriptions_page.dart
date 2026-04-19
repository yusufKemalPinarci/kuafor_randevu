import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../services/api_client.dart';

class AdminSubscriptionsPage extends StatefulWidget {
  const AdminSubscriptionsPage({super.key});

  @override
  State<AdminSubscriptionsPage> createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends State<AdminSubscriptionsPage> {
  List<dynamic> _subscriptions = [];
  bool _isLoading = true;
  int _page = 1;
  int _totalPages = 1;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
  }

  Future<void> _fetchSubscriptions({int page = 1}) async {
    setState(() => _isLoading = true);
    try {
      String url = '/api/admin/subscriptions?page=$page&limit=20';
      if (_statusFilter != null) url += '&status=$_statusFilter';

      final response = await ApiClient().get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _subscriptions = data['subscriptions'] ?? [];
          _page = data['page'] ?? 1;
          _totalPages = data['totalPages'] ?? 1;
          _isLoading = false;
        });
      } else {
        if (mounted) showAppSnackBar(context, 'Abonelikler yüklenemedi.', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Bağlantı hatası.', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _extendSubscription(String subId, String shopName) async {
    int days = 30;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text('Süre Uzat - $shopName', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextFormField(
          initialValue: '30',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Gün sayısı'),
          onChanged: (v) => days = int.tryParse(v) ?? 30,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: context.ct.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Uzat', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await ApiClient().put(
        '/api/admin/subscriptions/$subId/extend',
        body: {'days': days},
      );
      if (response.statusCode == 200) {
        showAppSnackBar(context, 'Abonelik süresi uzatıldı.');
        _fetchSubscriptions(page: _page);
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Abonelik süresi uzatılamadı. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  Future<void> _cancelSubscription(String subId, String shopName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text('Aboneliği İptal Et', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('"$shopName" için aboneliği iptal etmek istediğinize emin misiniz?', style: TextStyle(color: context.ct.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: context.ct.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('İptal Et', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await ApiClient().put('/api/admin/subscriptions/$subId/cancel');
      if (response.statusCode == 200) {
        showAppSnackBar(context, 'Abonelik iptal edildi.');
        _fetchSubscriptions(page: _page);
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Abonelik iptal edilemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  Future<void> _grantSubscription() async {
    String shopIdInput = '';
    int days = 30;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text('Ücretsiz Abonelik Ver', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dükkan ID girerek o dükkana ücretsiz abonelik tanımlayabilirsiniz.', style: TextStyle(color: context.ct.textTertiary, fontSize: 13)),
            const SizedBox(height: Spacing.lg),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Dükkan ID'),
              onChanged: (v) => shopIdInput = v.trim(),
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              initialValue: '30',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Gün sayısı'),
              onChanged: (v) => days = int.tryParse(v) ?? 30,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: context.ct.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ver', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true || shopIdInput.isEmpty) return;

    try {
      final response = await ApiClient().post(
        '/api/admin/subscriptions/grant',
        body: {'shopId': shopIdInput, 'days': days},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        showAppSnackBar(context, 'Abonelik başarıyla verildi.');
        _fetchSubscriptions(page: _page);
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Abonelik verilemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header: filter + grant button
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtre + Ver butonu
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip(null, 'Tümü'),
                          const SizedBox(width: Spacing.sm),
                  _filterChip('active', 'Aktif'),
                  const SizedBox(width: Spacing.sm),
                  _filterChip('expired', 'Süresi Dolmuş'),
                  const SizedBox(width: Spacing.sm),
                  _filterChip('cancelled', 'İptal'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: InkWell(
                      onTap: _grantSubscription,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm + 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.card_giftcard, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Ver', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _subscriptions.isEmpty
                  ? AppEmptyState(icon: Icons.card_membership_outlined, title: 'Abonelik bulunamadı')
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => _fetchSubscriptions(page: _page),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
                        itemCount: _subscriptions.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i == _subscriptions.length) return _buildPagination();
                          return _buildSubCard(_subscriptions[i]);
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
      onTap: () { setState(() => _statusFilter = value); _fetchSubscriptions(); },
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

  Widget _buildSubCard(dynamic sub) {
    final subId = sub['_id'] ?? '';
    final status = sub['status'] ?? 'expired';
    final tier = sub['tier'] ?? 'standart';
    final billingPeriod = sub['billingPeriod'] ?? '-';
    final startDate = sub['startDate'] ?? '';
    final endDate = sub['endDate'] ?? '';
    final shopId = sub['shopId'];
    final shopName = shopId is Map ? (shopId['name'] ?? '-') : '-';
    final ownerId = sub['ownerId'];
    final ownerName = ownerId is Map ? (ownerId['name'] ?? '-') : '-';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'active':
        statusColor = AppColors.success;
        statusLabel = 'Aktif';
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusLabel = 'İptal';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.warning;
        statusLabel = 'Süresi Dolmuş';
        statusIcon = Icons.access_time;
    }

    String tierLabel;
    switch (tier) {
      case 'standart': tierLabel = 'Standart'; break;
      case 'pro': tierLabel = 'Profesyonel'; break;
      case 'premium': tierLabel = 'Premium'; break;
      default: tierLabel = tier;
    }

    String periodLabel;
    switch (billingPeriod) {
      case 'monthly': periodLabel = 'Aylık'; break;
      case '6month': periodLabel = '6 Aylık'; break;
      case 'yearly': periodLabel = 'Yıllık'; break;
      case 'free_trial': periodLabel = 'Deneme'; break;
      default: periodLabel = billingPeriod;
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.sm + 2),
                  decoration: BoxDecoration(color: statusColor.withAlpha(18), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shopName, style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('Sahibi: $ownerName', style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 2, vertical: Spacing.xs),
                  decoration: BoxDecoration(color: statusColor.withAlpha(18), borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            const SizedBox(height: Spacing.md),

            // Details
            Row(
              children: [
                _detailChip(Icons.sell_outlined, '$tierLabel · $periodLabel'),
                const SizedBox(width: Spacing.md),
                _detailChip(Icons.play_arrow, formatDate(startDate)),
                const SizedBox(width: Spacing.md),
                _detailChip(Icons.stop, formatDate(endDate)),
              ],
            ),

            const SizedBox(height: Spacing.md),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'active' || status == 'expired')
                  TextButton.icon(
                    onPressed: () => _extendSubscription(subId, shopName),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Süre Uzat', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                if (status == 'active')
                  TextButton.icon(
                    onPressed: () => _cancelSubscription(subId, shopName),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('İptal Et', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.ct.textHint),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: context.ct.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox(height: Spacing.huge);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _paginationBtn(Icons.chevron_left, _page > 1, () => _fetchSubscriptions(page: _page - 1)),
          const SizedBox(width: Spacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm + 2),
            decoration: BoxDecoration(color: context.ct.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Text('$_page / $_totalPages', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: Spacing.md),
          _paginationBtn(Icons.chevron_right, _page < _totalPages, () => _fetchSubscriptions(page: _page + 1)),
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
