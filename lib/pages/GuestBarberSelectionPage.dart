import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import 'GuestBookingPage.dart';

class GuestBarberSelectionPage extends StatefulWidget {
  final String shopId;
  final String shopName;

  const GuestBarberSelectionPage({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  @override
  State<GuestBarberSelectionPage> createState() => _GuestBarberSelectionPageState();
}

class _GuestBarberSelectionPageState extends State<GuestBarberSelectionPage> {
  List<dynamic> _barbers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBarbers();
  }

  Future<void> _fetchBarbers() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/shop/${widget.shopId}/staff'));
      if (response.statusCode == 200) {
        setState(() {
          _barbers = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception("Berberler yüklenemedi.");
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Berber listesi yüklenemedi. Lütfen tekrar deneyin.', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(title: widget.shopName),
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.lg),
              child: Text('Berber Seçin', style: Theme.of(context).textTheme.headlineMedium),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _barbers.isEmpty
                      ? AppEmptyState(
                          icon: Icons.person_off_rounded,
                          title: 'Kayıtlı berber bulunamadı',
                          subtitle: 'Bu dükkanda henüz berber bulunmuyor',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                          itemCount: _barbers.length,
                          itemBuilder: (context, index) {
                            final barber = _barbers[index];
                            final barberName = barber['name'] ?? 'Bilinmeyen Berber';

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
                                        builder: (_) => GuestBookingPage(
                                          barberId: barber['_id'],
                                          barberName: barberName,
                                          shopName: widget.shopName,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(AppRadius.xl),
                                  child: Container(
                                    padding: const EdgeInsets.all(Spacing.lg),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadius.xl),
                                      border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
                                    ),
                                    child: Row(
                                      children: [
                                        AppAvatar(letter: barberName, size: 56),
                                        const SizedBox(width: Spacing.lg),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(barberName, style: TextStyle(color: context.ct.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                                              const SizedBox(height: Spacing.xs),
                                              Text(
                                                barber['bio'] ?? 'Bio bulunmuyor.',
                                                style: TextStyle(color: context.ct.textSecondary, fontSize: 13),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.chevron_right_rounded, color: context.ct.textHint, size: 24),
                                      ],
                                    ),
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
    );
  }
}
