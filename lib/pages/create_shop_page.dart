import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../models/shop_model.dart';
import '../models/user_model.dart';
import '../providers/shop_provider.dart';
import '../providers/user_provider.dart';
import '../services/address_service.dart';
import '../services/shop_service.dart';
import '../services/subscription_service.dart';

class CreateShopPage extends StatefulWidget {
  @override
  _CreateShopPageState createState() => _CreateShopPageState();
}

class _CreateShopPageState extends State<CreateShopPage> {
  final _formKey = GlobalKey<FormState>();
  final AddressService _addressService = AddressService();
  final ShopService _shopService = ShopService();

  String? _shopName;
  String? _address;
  int? _selectedProvinceId;
  String? _selectedNeighborhoodName;
  String? _selectedProvinceName;
  String? _selectedDistrictName;

  List<dynamic> _provinces = [];
  List<dynamic> _districts = [];
  List<dynamic> _neighborhoods = [];

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<String> _workingDays = [];
  String? _shopPhone;
  bool _isCreating = false;
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();
  String? _referralValidation;
  String? _referralShopName;
  int _referralBonusDays = 30;
  bool _referralIsPromo = false;
  bool _isCheckingReferral = false;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    final provinces = await _addressService.getProvinces();
    setState(() => _provinces = provinces);
  }

  Future<void> _loadDistricts(int provinceId) async {
    final districts = await _addressService.getDistricts(provinceId);
    setState(() {
      _districts = districts;
      _selectedDistrictName = null;
      _neighborhoods = [];
      _selectedNeighborhoodName = null;
    });
  }

  Future<void> _loadNeighborhoods(int districtId) async {
    final neighborhoods = await _addressService.getNeighborhoods(districtId);
    setState(() {
      _neighborhoods = neighborhoods;
      _selectedNeighborhoodName = null;
    });
  }

  void onProvinceSelected(int id, String name) async {
    _selectedProvinceId = id;
    _selectedProvinceName = name;
  }

  void onDistrictSelected(int id, String name) async {}

  Future<void> _selectTime(bool isStart) async {
    final defaultTime = isStart
        ? const TimeOfDay(hour: 9, minute: 0)
        : (_startTime != null
            ? TimeOfDay(hour: (_startTime!.hour + 1).clamp(0, 23), minute: 0)
            : const TimeOfDay(hour: 18, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? defaultTime) : (_endTime ?? defaultTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: context.ct.surface,
              dialHandColor: AppColors.primary,
              hourMinuteColor: context.ct.surfaceLight,
              hourMinuteTextColor: context.ct.textPrimary,
              dayPeriodColor: AppColors.primary.withAlpha(30),
              dayPeriodTextColor: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;

    if (!isStart && _startTime != null) {
      final startMin = _startTime!.hour * 60 + _startTime!.minute;
      final endMin = picked.hour * 60 + picked.minute;
      if (endMin <= startMin) {
        if (mounted) showAppSnackBar(context, 'Kapanış saati açılış saatinden sonra olmalıdır.', isError: true);
        return;
      }
    }

    setState(() {
      if (isStart) {
        _startTime = picked;
        // Kapanış daha önce seçildiyse ve artık geçersizse sıfırla
        if (_endTime != null) {
          final startMin = picked.hour * 60 + picked.minute;
          final endMin = _endTime!.hour * 60 + _endTime!.minute;
          if (endMin <= startMin) _endTime = null;
        }
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _checkReferralCode() async {
    final code = _referralController.text.trim();
    if (code.isEmpty) {
      setState(() { _referralValidation = null; _referralShopName = null; _referralIsPromo = false; });
      return;
    }
    setState(() => _isCheckingReferral = true);
    final result = await SubscriptionService.instance.checkReferralCode(code);
    setState(() {
      _referralValidation = result.valid ? 'valid' : 'invalid';
      _referralShopName = result.shopName;
      _referralBonusDays = result.bonusDays ?? 30;
      _referralIsPromo = result.isPromo;
      _isCheckingReferral = false;
    });
  }

  Future<void> _createShop() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final user = userProvider.user;

    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    _shopName = _shopNameController.text.trim();
    _address = _addressController.text.trim();
    _shopPhone = _phoneController.text.trim();

    if (_startTime == null || _endTime == null) {
      showAppSnackBar(context, "Lütfen dükkan açılış ve kapanış saatlerini seçin.", isError: true);
      return;
    }

    if (_workingDays.isEmpty) {
      showAppSnackBar(context, "Lütfen dükkanın çalıştığı günleri işaretleyin.", isError: true);
      return;
    }

    setState(() => _isCreating = true);

    final shopData = {
      "name": _shopName,
      "fullAddress": _address,
      "city": _selectedProvinceName,
      "district": _selectedDistrictName,
      "neighborhood": _selectedNeighborhoodName,
      "phone": _shopPhone,
      "adress": _address,
      "openingHour": _startTime?.format(context),
      "closingHour": _endTime?.format(context),
      "workingDays": _workingDays,
      "ownerId": user!.id,
    };

    try {
      final response = await _shopService.createShop(shopData, token: user.jwtToken);

      if (response['shop'] != null) {
        final newShop = ShopModel.fromJson(response['shop']);
        await shopProvider.saveShopToLocal(newShop);
      }

      if (response['user'] != null) {
        final currentToken = user.jwtToken;
        final updatedUser = UserModel.fromJson(response['user']).copyWith(jwtToken: currentToken);
        await userProvider.saveUserToLocalAndProvider(updatedUser);
      }

      // Referans kodu varsa otomatik abonelik oluştur
      final referralCode = _referralController.text.trim();
      if (referralCode.isNotEmpty && _referralValidation == 'valid' && response['shop'] != null) {
        final result = await SubscriptionService.instance.subscribeWithReferral(
          shopId: response['shop']['_id'],
          referralCode: referralCode,
          jwtToken: user.jwtToken!,
        );
        if (!result.success && mounted) {
          showAppSnackBar(context, result.message, isError: true);
        }
      }

      if (!mounted) return;
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.ct.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
          title: Text("Dükkan Oluşturuldu 🎉", style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Dükkanınız başarıyla kuruldu. Çalışanlarınızın dükkana katılabilmesi için aşağıdaki davet kodunu paylaşın:",
                style: TextStyle(color: context.ct.textSecondary, height: 1.5),
              ),
              const SizedBox(height: Spacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.primary.withAlpha(40)),
                ),
                child: Center(
                  child: Text(
                    response['shop']?['shopCode'] ?? "KOD_BULUNAMADI",
                    style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamedAndRemoveUntil(context, '/barberHome', (route) => false);
              },
              child: const Text("Kapat", style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, "Dükkan oluşturulurken bir sorun oluştu. Lütfen tekrar deneyin.", isError: true);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ct.bg,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: 'Dükkan Oluştur'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const SizedBox(height: Spacing.lg),
                      _buildSectionTitle("Dükkan Bilgileri"),
                      _buildTextInput(
                        controller: _shopNameController,
                        label: "Dükkan Adı",
                        hint: "Örn: Klasik Erkek Kuaförü",
                        icon: Icons.storefront,
                        onSaved: (val) => _shopName = val,
                        validator: (val) => val == null || val.isEmpty ? "Lütfen dükkan adını girin." : null,
                      ),
                      const SizedBox(height: Spacing.md + 2),
                      _buildTextInput(
                        controller: _addressController,
                        label: "Açık Adres",
                        hint: "Örn: Atatürk Cad. No:12 Kat:2",
                        icon: Icons.location_on_outlined,
                        onSaved: (val) => _address = val,
                        validator: (val) => val == null || val.isEmpty ? "Açık adres zorunludur." : null,
                      ),
                      const SizedBox(height: Spacing.md + 2),
                      _buildTextInput(
                        controller: _phoneController,
                        label: "Dükkan Telefonu",
                        hint: "Örn: 05551234567",
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        onSaved: (val) => _shopPhone = val?.trim(),
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Telefon zorunludur.";
                          final pattern = RegExp(r'^\+?[0-9]{10,15}$');
                          if (!pattern.hasMatch(val)) return "Geçerli bir telefon numarası girin.";
                          return null;
                        },
                      ),
                      const SizedBox(height: Spacing.xxl),

                      _buildSectionTitle("Bölge Seçimi"),
                      _buildDropdown<int>(
                        label: "İl Seçiniz",
                        value: _selectedProvinceId,
                        items: _provinces.map((p) => DropdownMenuItem<int>(
                          value: p["id"],
                          child: Text(p["name"]),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedProvinceId = val;
                              _selectedProvinceName = _provinces.firstWhere((p) => p["id"] == val)["name"];
                              _districts = [];
                              _selectedDistrictName = null;
                              _neighborhoods = [];
                              _selectedNeighborhoodName = null;
                            });
                            _loadDistricts(val);
                          }
                        },
                      ),
                      const SizedBox(height: Spacing.md + 2),
                      _buildDropdown<Map<String, dynamic>>(
                        key: ValueKey('district_$_selectedProvinceId'),
                        label: "İlçe Seçiniz",
                        value: null,
                        items: _districts.map((d) => DropdownMenuItem<Map<String, dynamic>>(
                          value: d,
                          child: Text(d["name"]),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedDistrictName = val["name"];
                              _neighborhoods = [];
                              _selectedNeighborhoodName = null;
                            });
                            _loadNeighborhoods(val["id"]);
                          }
                        },
                      ),
                      const SizedBox(height: Spacing.md + 2),
                      _buildDropdown<String>(
                        key: ValueKey('neighborhood_${_selectedProvinceId}_$_selectedDistrictName'),
                        label: "Mahalle Seçiniz",
                        value: _selectedNeighborhoodName,
                        items: _neighborhoods.map((n) => DropdownMenuItem<String>(
                          value: n["name"],
                          child: Text(n["name"]),
                        )).toList(),
                        onChanged: (val) => setState(() => _selectedNeighborhoodName = val),
                      ),
                      const SizedBox(height: Spacing.xxxl),

                      _buildSectionTitle("Çalışma Saatleri"),
                      Row(
                        children: [
                          Expanded(child: _buildTimePickerButton(title: "Açılış", time: _startTime, isStart: true)),
                          const SizedBox(width: Spacing.lg),
                          Expanded(child: _buildTimePickerButton(title: "Kapanış", time: _endTime, isStart: false)),
                        ],
                      ),
                      const SizedBox(height: Spacing.xxl),

                      _buildSectionTitle("Çalışma Günleri"),
                      Wrap(
                        spacing: Spacing.md,
                        runSpacing: Spacing.md,
                        children: ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"].map((day) {
                          final isSelected = _workingDays.contains(day);
                          return FilterChip(
                            label: Text(
                              day,
                              style: TextStyle(
                                color: isSelected ? Colors.white : context.ct.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: context.ct.surface,
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                              side: BorderSide(color: isSelected ? AppColors.primary : context.ct.surfaceBorder),
                            ),
                            onSelected: (bool val) {
                              setState(() {
                                val ? _workingDays.add(day) : _workingDays.remove(day);
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: Spacing.huge),

                      // Referans Kodu
                      _buildSectionTitle("Referans Kodu (Opsiyonel)"),
                      Text(
                        'Bir referans veya tanıtım kodunuz varsa girin, ücretsiz listeleme kazanın!',
                        style: TextStyle(color: context.ct.textSecondary, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: Spacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _referralController,
                              textCapitalization: TextCapitalization.characters,
                              style: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2),
                              decoration: InputDecoration(
                                hintText: 'Referans kodu',
                                prefixIcon: const Icon(Icons.card_giftcard, size: 22),
                                suffixIcon: _isCheckingReferral
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                      )
                                    : _referralValidation == 'valid'
                                        ? const Icon(Icons.check_circle, color: AppColors.success, size: 22)
                                        : _referralValidation == 'invalid'
                                            ? const Icon(Icons.cancel, color: AppColors.error, size: 22)
                                            : null,
                              ),
                              onChanged: (_) {
                                if (_referralValidation != null) {
                                  setState(() { _referralValidation = null; _referralShopName = null; });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Material(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            child: InkWell(
                              onTap: _isCheckingReferral ? null : _checkReferralCode,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: Container(
                                padding: const EdgeInsets.all(Spacing.lg + 2),
                                child: const Icon(Icons.search, color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_referralValidation == 'valid' && _referralShopName != null) ...[
                        const SizedBox(height: Spacing.sm + 2),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: Spacing.md + 2, vertical: Spacing.md),
                          decoration: BoxDecoration(color: context.ct.successSoft, borderRadius: BorderRadius.circular(AppRadius.sm + 2)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                                  const SizedBox(width: Spacing.sm),
                                  Flexible(child: Text(
                                    'Geçerli! $_referralBonusDays gün ücretsiz listeleme kazandınız.',
                                    style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600),
                                  )),
                                ],
                              ),
                              const SizedBox(height: Spacing.xs),
                              Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: Text(
                                  _referralIsPromo ? _referralShopName! : 'Referans: $_referralShopName',
                                  style: TextStyle(color: AppColors.success.withAlpha(180), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_referralValidation == 'invalid') ...[
                        const SizedBox(height: Spacing.sm + 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: Spacing.md + 2, vertical: Spacing.sm + 2),
                          decoration: BoxDecoration(color: context.ct.errorSoft, borderRadius: BorderRadius.circular(AppRadius.sm + 2)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: AppColors.error, size: 16),
                              SizedBox(width: Spacing.sm),
                              Text('Geçersiz referans kodu.', style: TextStyle(color: AppColors.error, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: Spacing.huge),
                      AppLoadingButton(
                        label: 'Dükkanı Kur ve Kaydet',
                        isLoading: _isCreating,
                        onPressed: _createShop,
                      ),
                      const SizedBox(height: Spacing.xxxl),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }

  Widget _buildTextInput({
    required String label,
    required String hint,
    required IconData icon,
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
    required Function(String?) onSaved,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 22),
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }

  Widget _buildDropdown<T>({
    Key? key,
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: key,
      value: value,
      decoration: InputDecoration(
        labelText: label,
      ),
      dropdownColor: context.ct.surface,
      style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
      iconEnabledColor: AppColors.primary,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildTimePickerButton({
    required String title,
    required TimeOfDay? time,
    required bool isStart,
  }) {
    final hasValue = time != null;
    return Material(
      color: context.ct.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: () => _selectTime(isStart),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Spacing.lg, horizontal: Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: hasValue ? AppColors.primary : context.ct.surfaceBorder),
          ),
          child: Column(
            children: [
              Icon(Icons.access_time, color: hasValue ? AppColors.primary : context.ct.textTertiary),
              const SizedBox(height: Spacing.sm),
              Text(
                hasValue ? time.format(context) : title,
                style: TextStyle(color: hasValue ? context.ct.textPrimary : context.ct.textTertiary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
