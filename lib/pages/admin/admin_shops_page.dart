import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../services/api_client.dart';

class AdminShopsPage extends StatefulWidget {
  const AdminShopsPage({super.key});

  @override
  State<AdminShopsPage> createState() => _AdminShopsPageState();
}

class _AdminShopsPageState extends State<AdminShopsPage> {
  List<dynamic> _shops = [];
  bool _isLoading = true;
  int _page = 1;
  int _totalPages = 1;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchShops({int page = 1}) async {
    setState(() => _isLoading = true);
    try {
      String url = '/api/admin/shops?page=$page&limit=20';
      final search = _searchController.text.trim();
      if (search.isNotEmpty) url += '&search=${Uri.encodeComponent(search)}';

      final response = await ApiClient().get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _shops = data['shops'] ?? [];
          _page = data['page'] ?? 1;
          _totalPages = data['totalPages'] ?? 1;
          _isLoading = false;
        });
      } else {
        if (mounted) showAppSnackBar(context, 'Dükkanlar yüklenemedi.', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Bağlantı hatası.', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteShop(String shopId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text('Dükkanı Sil', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('"$name" dükkanını ve tüm ilişkili verilerini silmek istediğinize emin misiniz?', style: TextStyle(color: context.ct.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: context.ct.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await ApiClient().delete('/api/admin/shops/$shopId');
      if (response.statusCode == 200) {
        showAppSnackBar(context, 'Dükkan silindi.');
        _fetchShops(page: _page);
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Dükkan silinemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  Future<void> _grantSubscription(String shopId, String shopName) async {
    int days = 30;
    String plan = 'monthly';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setDialogState) {
          return AlertDialog(
            backgroundColor: context.ct.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
            title: Text('Abonelik Ver - $shopName', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: plan,
                  dropdownColor: context.ct.surface,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: const [
                    DropdownMenuItem(value: 'free_trial', child: Text('Deneme')),
                    DropdownMenuItem(value: 'monthly', child: Text('Aylık')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yıllık')),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      plan = val!;
                      if (plan == 'monthly') days = 30;
                      else if (plan == 'yearly') days = 365;
                      else days = 14;
                    });
                  },
                ),
                const SizedBox(height: Spacing.md),
                TextFormField(
                  initialValue: days.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Gün sayısı'),
                  onChanged: (v) => days = int.tryParse(v) ?? days,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: context.ct.textSecondary))),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ver', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        });
      },
    );
    if (confirmed != true) return;

    try {
      final response = await ApiClient().post(
        '/api/admin/subscriptions/grant',
        body: {'shopId': shopId, 'plan': plan, 'days': days},
      );
      if (response.statusCode == 201) {
        showAppSnackBar(context, 'Abonelik verildi.');
        _fetchShops(page: _page);
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Abonelik verilemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  void _showShopDetail(dynamic shop) {
    final shopId = shop['_id'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ShopDetailSheet(shopId: shopId, onAction: () => _fetchShops(page: _page)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, 0),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: context.ct.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Dükkan adı veya şehir ile ara...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: Spacing.md),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _searchController.clear(); _fetchShops(); })
                  : null,
            ),
            onSubmitted: (_) => _fetchShops(),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () => _fetchShops());
            },
          ),
        ),
        const SizedBox(height: Spacing.md),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _shops.isEmpty
                  ? AppEmptyState(icon: Icons.storefront_outlined, title: 'Dükkan bulunamadı')
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => _fetchShops(page: _page),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
                        itemCount: _shops.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i == _shops.length) return _buildPagination();
                          return _buildShopCard(_shops[i]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildShopCard(dynamic shop) {
    final name = shop['name'] ?? '-';
    final city = shop['city'] ?? '';
    final district = shop['district'] ?? '';
    final shopId = shop['_id'] ?? '';
    final owner = shop['ownerId'];
    final ownerName = owner is Map ? (owner['name'] ?? '-') : '-';
    final sub = shop['subscription'];
    final subActive = sub != null && sub['status'] == 'active';

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Material(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: () => _showShopDetail(shop),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(18),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.storefront, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: Spacing.md + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                          if (city.isNotEmpty || district.isNotEmpty)
                            Text('$district, $city', style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                        ],
                      ),
                    ),
                    // Subscription badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 2, vertical: Spacing.xs),
                      decoration: BoxDecoration(
                        color: subActive ? AppColors.success.withAlpha(18) : AppColors.error.withAlpha(18),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(subActive ? Icons.verified : Icons.cancel_outlined, color: subActive ? AppColors.success : AppColors.error, size: 14),
                          const SizedBox(width: 4),
                          Text(subActive ? 'Aktif' : 'Pasif', style: TextStyle(color: subActive ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm + 2),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: context.ct.textHint),
                    const SizedBox(width: 4),
                    Expanded(child: Text('Sahibi: $ownerName', style: TextStyle(color: context.ct.textTertiary, fontSize: 12))),
                    // Actions
                    AppIconBtn(
                      icon: Icons.card_giftcard,
                      tooltip: 'Abonelik Ver',
                      size: 30,
                      onTap: () => _grantSubscription(shopId, name),
                    ),
                    const SizedBox(width: Spacing.xs),
                    AppIconBtn(
                      icon: Icons.delete_outline,
                      tooltip: 'Sil',
                      size: 30,
                      iconColor: AppColors.error,
                      onTap: () => _deleteShop(shopId, name),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          _paginationBtn(Icons.chevron_left, _page > 1, () => _fetchShops(page: _page - 1)),
          const SizedBox(width: Spacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm + 2),
            decoration: BoxDecoration(color: context.ct.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Text('$_page / $_totalPages', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: Spacing.md),
          _paginationBtn(Icons.chevron_right, _page < _totalPages, () => _fetchShops(page: _page + 1)),
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

// ─── Shop Detail Bottom Sheet ───────────────────────────────
class _ShopDetailSheet extends StatefulWidget {
  final String shopId;
  final VoidCallback onAction;

  const _ShopDetailSheet({required this.shopId, required this.onAction});

  @override
  State<_ShopDetailSheet> createState() => _ShopDetailSheetState();
}

class _ShopDetailSheetState extends State<_ShopDetailSheet> {
  Map<String, dynamic>? _shop;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final response = await ApiClient().get('/api/admin/shops/${widget.shopId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { _shop = data['shop']; _isLoading = false; });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.ct.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _shop == null
              ? Center(child: Text('Dükkan bulunamadı', style: TextStyle(color: context.ct.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, Spacing.xxxl),
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.ct.surfaceBorder, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: Spacing.xxl),

                    // Icon + name
                    Center(
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(color: AppColors.primary.withAlpha(22), borderRadius: BorderRadius.circular(AppRadius.xl)),
                        child: const Icon(Icons.storefront, color: AppColors.primary, size: 36),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    Center(child: Text(_shop!['name'] ?? '-', style: TextStyle(color: context.ct.textPrimary, fontSize: 22, fontWeight: FontWeight.w700))),

                    if ((_shop!['fullAddress'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Center(child: Text(_shop!['fullAddress'], style: TextStyle(color: context.ct.textTertiary, fontSize: 13), textAlign: TextAlign.center)),
                    ],

                    const SizedBox(height: Spacing.xxl),

                    // Info rows
                    _infoRow('Şehir', _shop!['city'] ?? '-'),
                    _infoRow('İlçe', _shop!['district'] ?? '-'),
                    _infoRow('Mahalle', _shop!['neighborhood'] ?? '-'),
                    _infoRow('Telefon', _shop!['phone'] ?? '-'),
                    _infoRow('Dükkan Kodu', _shop!['shopCode'] ?? '-'),
                    _infoRow('Çalışma Saatleri', '${_shop!['openingHour'] ?? '-'} - ${_shop!['closingHour'] ?? '-'}'),
                    _infoRow('Çalışma Günleri', (_shop!['workingDays'] as List?)?.join(', ') ?? '-'),

                    // Owner
                    if (_shop!['ownerId'] is Map) ...[
                      const SizedBox(height: Spacing.lg),
                      Text('SAHİBİ', style: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: Spacing.sm),
                      Container(
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(color: context.ct.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Row(
                          children: [
                            AppAvatar(letter: _shop!['ownerId']['name'] ?? '?', size: 36, withShadow: false),
                            const SizedBox(width: Spacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_shop!['ownerId']['name'] ?? '-', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                                Text(_shop!['ownerId']['email'] ?? '', style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Subscription
                    if (_shop!['subscription'] != null) ...[
                      const SizedBox(height: Spacing.lg),
                      Text('ABONELİK', style: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: Spacing.sm),
                      _buildSubInfo(_shop!['subscription']),
                    ],

                    // Stats
                    const SizedBox(height: Spacing.lg),
                    Row(
                      children: [
                        _statChip('Personel', '${_shop!['staffCount'] ?? 0}', Icons.people),
                        const SizedBox(width: Spacing.md),
                        _statChip('Randevu', '${_shop!['appointmentCount'] ?? 0}', Icons.calendar_today),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.ct.textTertiary, fontSize: 13)),
          Text(value, style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSubInfo(Map<String, dynamic> sub) {
    final status = sub['status'] ?? 'expired';
    final plan = sub['plan'] ?? '-';
    final end = sub['endDate'] ?? '';
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withAlpha(12) : AppColors.error.withAlpha(12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: (isActive ? AppColors.success : AppColors.error).withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isActive ? Icons.verified : Icons.cancel, color: isActive ? AppColors.success : AppColors.error, size: 18),
              const SizedBox(width: Spacing.sm),
              Text(isActive ? 'Aktif' : 'Pasif', style: TextStyle(color: isActive ? AppColors.success : AppColors.error, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(plan, style: TextStyle(color: context.ct.textSecondary, fontSize: 12)),
            ],
          ),
          if (end.isNotEmpty) ...[
            const SizedBox(height: Spacing.xs),
            Text('Bitiş: ${end.toString().substring(0, 10)}', style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(color: context.ct.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: Spacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                Text(label, style: TextStyle(color: context.ct.textTertiary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
