import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../providers/user_provider.dart';
import '../services/api_client.dart';


class ShopEditPage extends StatefulWidget {
  const ShopEditPage({super.key});

  @override
  State<ShopEditPage> createState() => _ShopEditPageState();
}

class _ShopEditPageState extends State<ShopEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  bool isLoading = true;
  bool isSaving = false;
  String? _shopId;
  bool _autoConfirm = false;

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadShopData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopId = userProvider.user?.shopId;

    if (shopId == null || shopId.trim().isEmpty) {
      if (mounted) {
        setState(() => isLoading = false);
        showAppSnackBar(context, 'Bağlı bir dükkan bulunamadı.', isError: true);
      }
      return;
    }

    try {
      final response = await ApiClient().get('/api/shop/$shopId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _shopId = data['_id'] ?? shopId;
        _nameController.text = data['name'] ?? '';
        _addressController.text = data['fullAddress'] ?? data['adress'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _autoConfirm = data['autoConfirmAppointments'] ?? false;
        // Parse time strings (format: "09:00")
        _openTime = _parseTime(data['openingHour']) ?? const TimeOfDay(hour: 9, minute: 0);
        _closeTime = _parseTime(data['closingHour']) ?? const TimeOfDay(hour: 18, minute: 0);
      }
    } catch (e) {
      showAppSnackBar(context, 'Dükkan bilgileri yüklenemedi. Lütfen tekrar deneyin.', isError: true);
    }

    if (mounted) setState(() => isLoading = false);
  }

  TimeOfDay? _parseTime(String? val) {
    if (val == null || val.isEmpty) return null;
    final parts = val.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _selectTime(bool isOpen) async {
    final defaultTime = isOpen
        ? const TimeOfDay(hour: 9, minute: 0)
        : (_openTime != null
            ? TimeOfDay(hour: (_openTime!.hour + 1).clamp(0, 23), minute: 0)
            : const TimeOfDay(hour: 18, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? (_openTime ?? defaultTime) : (_closeTime ?? defaultTime),
    );
    if (picked == null) return;

    if (!isOpen && _openTime != null) {
      final openMin = _openTime!.hour * 60 + _openTime!.minute;
      final closeMin = picked.hour * 60 + picked.minute;
      if (closeMin <= openMin) {
        if (mounted) showAppSnackBar(context, 'Kapanış saati açılış saatinden sonra olmalıdır.', isError: true);
        return;
      }
    }

    setState(() {
      if (isOpen) {
        _openTime = picked;
        if (_closeTime != null) {
          final openMin = picked.hour * 60 + picked.minute;
          final closeMin = _closeTime!.hour * 60 + _closeTime!.minute;
          if (closeMin <= openMin) _closeTime = null;
        }
      } else {
        _closeTime = picked;
      }
    });
  }

  Future<void> _saveShopData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_openTime == null || _closeTime == null) {
      showAppSnackBar(context, 'Lütfen açılış ve kapanış saatlerini seçin.', isError: true);
      return;
    }
    if (_shopId == null) return;

    setState(() => isSaving = true);

    try {
      final response = await ApiClient().put(
        '/api/shop/$_shopId',
        body: {
          'name': _nameController.text.trim(),
          'fullAddress': _addressController.text.trim(),
          'adress': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
          'openingHour': '${_openTime!.hour.toString().padLeft(2, '0')}:${_openTime!.minute.toString().padLeft(2, '0')}',
          'closingHour': '${_closeTime!.hour.toString().padLeft(2, '0')}:${_closeTime!.minute.toString().padLeft(2, '0')}',
          'autoConfirmAppointments': _autoConfirm,
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          showAppSnackBar(context, 'Dükkan bilgileri güncellendi.');
          Navigator.pop(context, true);
        }
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Güncelleme başarısız.', isError: true);
      }
    } catch (e) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: 'Dükkanı Düzenle'),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, Spacing.xxxl),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputField('Dükkan Adı', _nameController, Icons.storefront_rounded),
                            const SizedBox(height: Spacing.lg),
                            _buildInputField('Adres', _addressController, Icons.location_on_outlined),
                            const SizedBox(height: Spacing.lg),
                            _buildInputField('Telefon', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),
                            const SizedBox(height: Spacing.lg),
                            Row(
                              children: [
                                Expanded(child: _buildTimeButton('Açılış', _openTime, true)),
                                const SizedBox(width: Spacing.md),
                                Expanded(child: _buildTimeButton('Kapanış', _closeTime, false)),
                              ],
                            ),
                            const SizedBox(height: Spacing.xxxl),
                            // ── Randevu Yönetimi ──
                            Text('Randevu Yönetimi',
                                style: TextStyle(
                                    color: context.ct.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: Spacing.md),
                            Container(
                              decoration: BoxDecoration(
                                color: context.ct.surface,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: Border.all(color: context.ct.surfaceBorder),
                              ),
                              child: SwitchListTile.adaptive(
                                title: Text('Otomatik Randevu Onayı',
                                    style: TextStyle(color: context.ct.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  _autoConfirm
                                      ? 'Müşteri randevuları otomatik onaylandı'
                                      : 'Randevular onayınızı bekler',
                                  style: TextStyle(color: context.ct.textSecondary, fontSize: 12),
                                ),
                                value: _autoConfirm,
                                onChanged: (v) => setState(() => _autoConfirm = v),
                                activeColor: AppColors.primary,
                                contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                              ),
                            ),
                            const SizedBox(height: Spacing.xxxl),
                            AppLoadingButton(
                              label: 'Kaydet',
                              icon: Icons.save_rounded,
                              isLoading: isSaving,
                              onPressed: _saveShopData,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(String label, TimeOfDay? time, bool isOpen) {
    final hasValue = time != null;
    return Material(
      color: context.ct.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: () => _selectTime(isOpen),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Spacing.lg, horizontal: Spacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: hasValue ? AppColors.primary : context.ct.surfaceBorder),
          ),
          child: Column(
            children: [
              Icon(isOpen ? Icons.access_time_rounded : Icons.access_time_filled_rounded,
                  color: hasValue ? AppColors.primary : context.ct.textTertiary),
              const SizedBox(height: Spacing.sm),
              Text(
                hasValue
                    ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                    : label,
                style: TextStyle(
                  color: hasValue ? context.ct.textPrimary : context.ct.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return '$label boş olamaz';
        return null;
      },
    );
  }
}
