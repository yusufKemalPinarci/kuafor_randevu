import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../services/address_service.dart';
import 'GuestBarberSelectionPage.dart';

class GuestShopSelectionPage extends StatefulWidget {
  const GuestShopSelectionPage({super.key});

  @override
  State<GuestShopSelectionPage> createState() => _GuestShopSelectionPageState();
}

class _GuestShopSelectionPageState extends State<GuestShopSelectionPage> {
  final AddressService _addressService = AddressService();
  List<dynamic> _shops = [];
  List<dynamic> _filteredShops = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Address filter state
  List<dynamic> _provinces = [];
  List<dynamic> _districts = [];
  String? _selectedCity;
  String? _selectedDistrict;
  int? _selectedProvinceId;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _fetchShops();
    _loadProvinces();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    try {
      final provinces = await _addressService.getProvinces();
      if (mounted) setState(() => _provinces = provinces);
    } catch (_) {}
  }

  Future<void> _loadDistricts(int provinceId) async {
    try {
      final districts = await _addressService.getDistricts(provinceId);
      if (mounted) setState(() => _districts = districts);
    } catch (_) {}
  }

  Future<void> _fetchShops() async {
    setState(() => _isLoading = true);
    try {
      String url = '${AppConstants.baseUrl}/api/shop';
      final params = <String, String>{};
      if (_selectedCity != null && _selectedCity!.isNotEmpty) params['city'] = _selectedCity!;
      if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) params['district'] = _selectedDistrict!;
      if (params.isNotEmpty) {
        url += '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final shops = jsonDecode(response.body);
        setState(() {
          _shops = shops;
          _applyTextFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyTextFilter() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      _filteredShops = _shops;
    } else {
      _filteredShops = _shops.where((shop) {
        final name = (shop['name'] ?? '').toString().toLowerCase();
        final city = (shop['city'] ?? '').toString().toLowerCase();
        final district = (shop['district'] ?? '').toString().toLowerCase();
        final neighborhood = (shop['neighborhood'] ?? '').toString().toLowerCase();
        return name.contains(query) || city.contains(query) || district.contains(query) || neighborhood.contains(query);
      }).toList();
    }
  }

  void _onTextFilterChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _applyTextFilter());
    });
  }

  void _showCodeDialog() {
    final codeController = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.ct.surface,
          title: Text('Kodla Randevu Al', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Berberin size ilettiği randevu kodunu girin:', style: TextStyle(color: context.ct.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: context.ct.textPrimary, letterSpacing: 2, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: 'Örn: A8B2X9',
                  prefixIcon: Icon(Icons.tag_rounded, color: AppColors.primary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('İptal', style: TextStyle(color: context.ct.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isLoading
                  ? null
                  : () async {
                      final code = codeController.text.trim().toUpperCase();
                      if (code.isEmpty) return;
                      setDialogState(() => isLoading = true);
                      try {
                        final response = await http.get(
                          Uri.parse('${AppConstants.baseUrl}/api/shop/by-code/$code'),
                        );
                        if (!ctx.mounted) return;
                        if (response.statusCode == 200) {
                          final shop = jsonDecode(response.body);
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GuestBarberSelectionPage(
                                shopId: shop['_id'],
                                shopName: shop['name'],
                              ),
                            ),
                          );
                        } else {
                          setDialogState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Geçersiz kod. Lütfen kontrol edin.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } catch (_) {
                        if (!ctx.mounted) return;
                        setDialogState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('İnternet bağlantınızı kontrol edip tekrar deneyin.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Devam Et', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _onCitySelected(String? cityName, int? provinceId) {
    setState(() {
      _selectedCity = cityName;
      _selectedProvinceId = provinceId;
      _selectedDistrict = null;
      _districts = [];
    });
    if (provinceId != null) _loadDistricts(provinceId);
    _fetchShops();
  }

  void _onDistrictSelected(String? districtName) {
    setState(() => _selectedDistrict = districtName);
    _fetchShops();
  }

  void _clearFilters() {
    setState(() {
      _selectedCity = null;
      _selectedDistrict = null;
      _selectedProvinceId = null;
      _districts = [];
    });
    _fetchShops();
  }

  bool get _hasActiveFilter => _selectedCity != null || _selectedDistrict != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: 'Dükkan Seçin'),
            const SizedBox(height: Spacing.sm),

            // ── Code Entry ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
              child: GestureDetector(
                onTap: _showCodeDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
                  decoration: BoxDecoration(
                    color: context.ct.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.primary.withAlpha(60)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Kodla Randevu Al',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),

            // ── Search + Filter Toggle ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onTextFilterChanged,
                      style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, color: context.ct.textTertiary, size: 22),
                        hintText: 'Dükkan adı ara...',
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded, color: context.ct.textTertiary, size: 20),
                                onPressed: () { _searchController.clear(); _onTextFilterChanged(''); },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm + 2),
                  GestureDetector(
                    onTap: () => setState(() => _showFilters = !_showFilters),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(Spacing.md + 2),
                      decoration: BoxDecoration(
                        color: _hasActiveFilter ? AppColors.primary.withAlpha(18) : context.ct.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: _hasActiveFilter ? AppColors.primary : context.ct.surfaceBorder),
                      ),
                      child: Icon(
                        _showFilters ? Icons.filter_list_off : Icons.filter_list,
                        color: _hasActiveFilter ? AppColors.primary : context.ct.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Address Filters ──
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _showFilters ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: _buildFilterPanel(),
              secondChild: const SizedBox.shrink(),
            ),

            // ── Active filter chips ──
            if (_hasActiveFilter)
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
                child: Row(
                  children: [
                    if (_selectedCity != null)
                      _buildActiveChip(_selectedCity!, () => _onCitySelected(null, null)),
                    if (_selectedDistrict != null) ...[
                      const SizedBox(width: Spacing.sm),
                      _buildActiveChip(_selectedDistrict!, () => _onDistrictSelected(null)),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: _clearFilters,
                      child: const Text('Temizle', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

            // ── Results count ──
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.xxl + 4, Spacing.md, Spacing.xxl, Spacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filteredShops.length} dükkan bulundu',
                  style: TextStyle(color: context.ct.textTertiary, fontSize: 13),
                ),
              ),
            ),

            // ── Shop List ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filteredShops.isEmpty
                      ? AppEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Sonuç bulunamadı',
                          subtitle: 'Farklı filtre veya anahtar kelime deneyin',
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _fetchShops,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                            itemCount: _filteredShops.length,
                            itemBuilder: (context, index) => _buildShopCard(_filteredShops[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, 0),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: AppColors.primary, size: 18),
              SizedBox(width: Spacing.sm),
              Text('Adrese Göre Filtrele', style: TextStyle(color: context.ct.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: Spacing.lg),

          // İl seçimi
          DropdownButtonFormField<int>(
            value: _selectedProvinceId,
            isExpanded: true,
            dropdownColor: context.ct.surface,
            decoration: const InputDecoration(
              labelText: 'İl',
              prefixIcon: Icon(Icons.location_city, size: 20),
              contentPadding: EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.md),
            ),
            items: _provinces.map<DropdownMenuItem<int>>((p) {
              return DropdownMenuItem<int>(value: p['id'], child: Text(p['name'] ?? '', style: const TextStyle(fontSize: 14)));
            }).toList(),
            onChanged: (id) {
              if (id == null) return;
              final province = _provinces.firstWhere((p) => p['id'] == id, orElse: () => null);
              if (province != null) {
                _onCitySelected(province['name'], id);
              }
            },
          ),

          const SizedBox(height: Spacing.md),

          // İlçe seçimi
          DropdownButtonFormField<String>(
            value: _selectedDistrict,
            isExpanded: true,
            dropdownColor: context.ct.surface,
            decoration: const InputDecoration(
              labelText: 'İlçe',
              prefixIcon: Icon(Icons.map_outlined, size: 20),
              contentPadding: EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.md),
            ),
            items: _districts.map<DropdownMenuItem<String>>((d) {
              final name = d['name'] ?? '';
              return DropdownMenuItem<String>(value: name, child: Text(name, style: const TextStyle(fontSize: 14)));
            }).toList(),
            onChanged: _districts.isEmpty ? null : (val) => _onDistrictSelected(val),
            disabledHint: Text('Önce il seçin', style: TextStyle(color: context.ct.textHint, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs + 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: Spacing.xs + 2),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: AppColors.primary, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(dynamic shop) {
    final name = shop['name'] ?? 'Dükkan';
    final city = shop['city'] ?? '';
    final district = shop['district'] ?? '';
    final neighborhood = shop['neighborhood'] ?? '';
    final location = [neighborhood, district, city].where((s) => s.isNotEmpty).join(', ');
    final openingHour = shop['openingHour'] ?? '';
    final closingHour = shop['closingHour'] ?? '';
    final hasHours = openingHour.isNotEmpty && closingHour.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Material(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GuestBarberSelectionPage(
                  shopId: shop['_id'],
                  shopName: name,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg + 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: Spacing.xs),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, color: context.ct.textTertiary, size: 14),
                            const SizedBox(width: Spacing.xs),
                            Expanded(
                              child: Text(location, style: TextStyle(color: context.ct.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                      if (hasHours) ...[
                        const SizedBox(height: Spacing.xs),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, color: context.ct.textHint, size: 13),
                            const SizedBox(width: Spacing.xs),
                            Text('$openingHour - $closingHour', style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: context.ct.textHint, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
