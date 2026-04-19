import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../services/api_client.dart';

class AdminPromoCodesPage extends StatefulWidget {
  const AdminPromoCodesPage({super.key});

  @override
  State<AdminPromoCodesPage> createState() => _AdminPromoCodesPageState();
}

class _AdminPromoCodesPageState extends State<AdminPromoCodesPage> {
  List<dynamic> _codes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().get('/api/admin/promo-codes');
      if (res.statusCode == 200) {
        setState(() {
          _codes = jsonDecode(res.body);
          _isLoading = false;
        });
      } else {
        if (mounted) showAppSnackBar(context, 'Promo kodlar yüklenemedi.', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Bağlantı hatası.', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createCode() async {
    String code = '';
    String label = '';
    int bonusDays = 30;
    int maxUsage = 0;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text('Yeni Promo Kod',
            style: TextStyle(
                color: context.ct.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bu kodu arkadaşlarınıza/tanıtımcılara verin.\nKodu kullanan dükkanlar avantaj kazanır.',
                style: TextStyle(
                    color: context.ct.textTertiary,
                    fontSize: 12,
                    height: 1.5),
              ),
              const SizedBox(height: Spacing.lg),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Kod (büyük harf/rakam)',
                  hintText: 'AHMET2024',
                  prefixIcon: Icon(Icons.tag),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.trim().length < 3) {
                    return 'En az 3 karakter girin';
                  }
                  return null;
                },
                onChanged: (v) => code = v.trim().toUpperCase(),
              ),
              const SizedBox(height: Spacing.md),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Etiket / Kime verildi',
                  hintText: 'Ahmet\'e verilen kod',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Etiket girin';
                  return null;
                },
                onChanged: (v) => label = v.trim(),
              ),
              const SizedBox(height: Spacing.md),
              TextFormField(
                initialValue: '30',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Avantaj (gün)',
                  hintText: '30',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixText: 'gün',
                ),
                onChanged: (v) => bonusDays = int.tryParse(v) ?? 30,
              ),
              const SizedBox(height: Spacing.md),
              TextFormField(
                initialValue: '0',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Kullanım',
                  hintText: '0 = sınırsız',
                  prefixIcon: Icon(Icons.group_outlined),
                  suffixText: 'kişi',
                ),
                onChanged: (v) => maxUsage = int.tryParse(v) ?? 0,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal',
                style: TextStyle(color: context.ct.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Oluştur',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || code.isEmpty || label.isEmpty) return;

    try {
      final res = await ApiClient().post(
        '/api/admin/promo-codes',
        body: {'code': code, 'label': label, 'bonusDays': bonusDays, 'maxUsage': maxUsage},
      );
      if (res.statusCode == 201) {
        showAppSnackBar(context, 'Promo kod oluşturuldu.');
        _fetch();
      } else {
        final err = jsonDecode(res.body);
        if (mounted) showAppSnackBar(context, err['error'] ?? 'Promo kod oluşturulamadı. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  Future<void> _toggleCode(String id, bool isActive, String label) async {
    try {
      final res = await ApiClient().put('/api/admin/promo-codes/$id/toggle');
      if (res.statusCode == 200) {
        showAppSnackBar(
            context, isActive ? '"$label" pasife alındı.' : '"$label" aktif edildi.');
        _fetch();
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  Future<void> _deleteCode(String id, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text('Kodu Sil',
            style: TextStyle(
                color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
            '"$label" kodunu silmek istediğinize emin misiniz?\nBu kodu kullanan abonelikler etkilenmez.',
            style: TextStyle(
                color: context.ct.textSecondary, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: TextStyle(color: context.ct.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil',
                style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final res = await ApiClient().delete('/api/admin/promo-codes/$id');
      if (res.statusCode == 200) {
        showAppSnackBar(context, 'Promo kod silindi.');
        _fetch();
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  Future<void> _showUsages(String code, String label, int usageCount) async {
    if (usageCount == 0) {
      showAppSnackBar(context, 'Bu kodu henüz kimse kullanmamış.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _UsagesDialog(
        code: code,
        label: label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.xxl, Spacing.lg, Spacing.xxl, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Promo Kodlar',
                        style: TextStyle(
                            color: context.ct.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    Text(
                      '${_codes.length} kod · Arkadaşlarınıza dağıtın',
                      style: TextStyle(
                          color: context.ct.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: InkWell(
                  onTap: _createCode,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.sm + 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Yeni Kod',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _codes.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.qr_code_outlined,
                      title: 'Henüz promo kod yok',
                      subtitle:
                          'Yeni Kod butonuna tıklayarak başlayın',
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _fetch,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.xxl),
                        itemCount: _codes.length,
                        itemBuilder: (ctx, i) =>
                            _buildCodeCard(_codes[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildCodeCard(dynamic item) {
    final id = item['_id'] ?? '';
    final code = item['code'] ?? '';
    final label = item['label'] ?? '';
    final bonusDays = item['bonusDays'] ?? 30;
    final usageCount = item['usageCount'] ?? 0;
    final maxUsage = item['maxUsage'] ?? 0;
    final isActive = item['isActive'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      decoration: BoxDecoration(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withAlpha(40)
              : context.ct.surfaceBorder,
        ),
      ),
      child: Column(
        children: [
          // Üst: kod + kopyala + aktif badge
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withAlpha(20)
                        : context.ct.surfaceBorder,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      color: isActive
                          ? AppColors.primary
                          : context.ct.textTertiary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    showAppSnackBar(context, '"$code" panoya kopyalandı.');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.ct.bg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: context.ct.surfaceBorder),
                    ),
                    child: Icon(Icons.copy_outlined,
                        size: 14, color: context.ct.textSecondary),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm + 2, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.success.withAlpha(20)
                        : AppColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    isActive ? 'Aktif' : 'Pasif',
                    style: TextStyle(
                      color: isActive ? AppColors.success : AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Orta: etiket + istatistikler
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: context.ct.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  children: [
                    _stat(Icons.group_outlined,
                        maxUsage > 0
                            ? '$usageCount / $maxUsage kullanım'
                            : '$usageCount kullanım',
                        maxUsage > 0 && usageCount >= maxUsage
                            ? AppColors.error
                            : AppColors.primary),
                    const SizedBox(width: Spacing.lg),
                    _stat(Icons.calendar_today_outlined,
                        '$bonusDays gün avantaj', AppColors.success),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Divider(color: context.ct.surfaceBorder, height: 1),
          // Alt: aksiyonlar
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  icon: usageCount > 0
                      ? Icons.visibility_outlined
                      : Icons.info_outline,
                  label: 'Kullananlar ($usageCount)',
                  color: AppColors.primary,
                  onTap: () => _showUsages(code, label, usageCount),
                ),
              ),
              Container(width: 1, height: 44, color: context.ct.surfaceBorder),
              Expanded(
                child: _actionBtn(
                  icon: isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  label: isActive ? 'Pasife Al' : 'Aktif Et',
                  color: isActive ? AppColors.warning : AppColors.success,
                  onTap: () => _toggleCode(id, isActive, label),
                ),
              ),
              Container(width: 1, height: 44, color: context.ct.surfaceBorder),
              Expanded(
                child: _actionBtn(
                  icon: Icons.delete_outline,
                  label: 'Sil',
                  color: AppColors.error,
                  onTap: () => _deleteCode(id, label),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: context.ct.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Kullananlar Dialog ──────────────────────────────────────────────────────
class _UsagesDialog extends StatefulWidget {
  final String code;
  final String label;

  const _UsagesDialog({
    required this.code,
    required this.label,
  });

  @override
  State<_UsagesDialog> createState() => _UsagesDialogState();
}

class _UsagesDialogState extends State<_UsagesDialog> {
  List<dynamic> _usages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiClient().get(
            '/api/admin/promo-codes/${widget.code}/usages');
      if (res.statusCode == 200) {
        setState(() {
          _usages = jsonDecode(res.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.ct.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.group_outlined,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.code,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 1.5),
                      ),
                      Text(
                        widget.label,
                        style: TextStyle(
                            color: context.ct.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close,
                      color: context.ct.textTertiary, size: 20),
                ),
              ],
            ),
          ),
          Divider(color: context.ct.surfaceBorder, height: 1),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(Spacing.xxl),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else if (_usages.isEmpty)
            Padding(
              padding: EdgeInsets.all(Spacing.xxl),
              child: Text('Henüz kullanım yok.',
                  style: TextStyle(color: context.ct.textTertiary)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(Spacing.lg),
                itemCount: _usages.length,
                separatorBuilder: (_, __) => Divider(
                    color: context.ct.surfaceBorder, height: 1),
                itemBuilder: (ctx, i) {
                  final u = _usages[i];
                  final shop = u['shopId'];
                  final owner = u['ownerId'];
                  final shopName =
                      shop is Map ? (shop['name'] ?? '-') : '-';
                  final shopCity =
                      shop is Map ? (shop['city'] ?? '') : '';
                  final ownerName =
                      owner is Map ? (owner['name'] ?? '-') : '-';
                  final ownerEmail =
                      owner is Map ? (owner['email'] ?? '') : '';
                  final endDate = u['endDate'] ?? '';
                  String endDateStr = '';
                  if (endDate.isNotEmpty) {
                    try {
                      final dt = DateTime.parse(endDate).toLocal();
                      endDateStr =
                          '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
                    } catch (_) {}
                  }

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: Spacing.sm),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_outlined,
                              color: AppColors.primary, size: 16),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(shopName,
                                  style: TextStyle(
                                      color: context.ct.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              Text(
                                '$ownerName · $shopCity',
                                style: TextStyle(
                                    color: context.ct.textSecondary,
                                    fontSize: 11),
                              ),
                              if (ownerEmail.isNotEmpty)
                                Text(
                                  ownerEmail,
                                  style: TextStyle(
                                      color: context.ct.textTertiary,
                                      fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                        if (endDateStr.isNotEmpty)
                          Column(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 10, color: context.ct.textTertiary),
                              const SizedBox(height: 2),
                              Text(endDateStr,
                                  style: TextStyle(
                                      color: context.ct.textTertiary,
                                      fontSize: 9)),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
