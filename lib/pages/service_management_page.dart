import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../providers/user_provider.dart';
import '../services/api_client.dart';

class ServiceManagementPage extends StatefulWidget {
  const ServiceManagementPage({super.key});

  @override
  State<ServiceManagementPage> createState() => _ServiceManagementPageState();
}

class _ServiceManagementPageState extends State<ServiceManagementPage> {
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      final response = await ApiClient().get('/api/service/${user.id}/services');
      if (response.statusCode == 200) {
        setState(() {
          _services = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteService(String serviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text('Servisi Sil', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text('Bu hizmeti silmek istediğinize emin misiniz?', style: TextStyle(color: context.ct.textSecondary, height: 1.5)),
        actionsPadding: const EdgeInsets.fromLTRB(Spacing.xxl, 0, Spacing.xxl, Spacing.xl),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
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
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text('Sil', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await ApiClient().delete('/api/service/$serviceId');
      if (response.statusCode == 200) {
        showAppSnackBar(context, 'Hizmet silindi.');
        _fetchServices();
      } else {
        showAppSnackBar(context, 'Hizmet silinemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? service}) {
    final titleController = TextEditingController(text: service?['title'] ?? '');
    final priceController = TextEditingController(text: service?['price']?.toString() ?? '');
    final durationController = TextEditingController(text: service?['durationMinutes']?.toString() ?? '');
    bool isSaving = false;
    final isEdit = service != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: context.ct.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
          title: Text(
            isEdit ? 'Hizmeti Düzenle' : 'Yeni Hizmet Ekle',
            style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField('Hizmet Adı', titleController, Icons.content_cut),
                const SizedBox(height: Spacing.md),
                _buildDialogField('Fiyat (₺)', priceController, Icons.attach_money, keyboardType: TextInputType.number),
                const SizedBox(height: Spacing.md),
                _buildDialogField('Süre (dk)', durationController, Icons.timer_outlined, keyboardType: TextInputType.number),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.sm, Spacing.xxl, Spacing.xl),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.ct.textSecondary,
                      side: BorderSide(color: context.ct.surfaceBorder),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            final price = double.tryParse(priceController.text.trim());
                            final duration = int.tryParse(durationController.text.trim());

                            if (title.isEmpty || price == null || duration == null) {
                              showAppSnackBar(context, 'Lütfen tüm alanları doğru doldurun.', isError: true);
                              return;
                            }

                            if (price <= 0) {
                              showAppSnackBar(context, 'Fiyat 0\'dan büyük olmalıdır.', isError: true);
                              return;
                            }

                            if (duration <= 0) {
                              showAppSnackBar(context, 'Süre en az 1 dakika olmalıdır.', isError: true);
                              return;
                            }

                            setStateDialog(() => isSaving = true);

                            final user = Provider.of<UserProvider>(context, listen: false).user;
                            if (user == null) return;

                            try {
                              final body = {
                                'title': title,
                                'price': price,
                                'durationMinutes': duration,
                                'barberId': user.id,
                              };

                              final response = isEdit
                                  ? await ApiClient().put(
                                      '/api/service/${service['_id']}',
                                      body: body,
                                    )
                                  : await ApiClient().post(
                                      '/api/service',
                                      body: body,
                                    );

                              if (response.statusCode == 200) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                showAppSnackBar(context, isEdit ? 'Hizmet güncellendi.' : 'Hizmet eklendi.');
                                _fetchServices();
                              } else {
                                showAppSnackBar(context, 'Hizmet kaydedilemedi. Lütfen tekrar deneyin.', isError: true);
                              }
                            } catch (_) {
                              showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
                            } finally {
                              setStateDialog(() => isSaving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(isEdit ? 'Güncelle' : 'Ekle', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.ct.textTertiary),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Hizmetlerim',
              trailing: Material(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: () => _showAddEditDialog(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
                  ),
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _services.isEmpty
                      ? AppEmptyState(
                          icon: Icons.content_cut,
                          title: 'Henüz hizmet eklenmemiş',
                          subtitle: 'Müşterilerinizin randevu alabilmesi için\nhizmet ekleyin',
                          actionLabel: 'Hizmet Ekle',
                          onAction: () => _showAddEditDialog(),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: context.ct.surface,
                          onRefresh: _fetchServices,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                            itemCount: _services.length,
                            itemBuilder: (ctx, i) => _buildServiceCard(_services[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(dynamic service) {
    final title = service['title'] ?? 'Hizmet';
    final price = service['price']?.toString() ?? '0';
    final duration = service['durationMinutes']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(Icons.content_cut, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: Spacing.sm),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.ct.successSoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text('₺$price', style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.ct.infoSoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text('$duration dk', style: const TextStyle(color: AppColors.info, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: context.ct.surfaceLight.withAlpha(120),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InkWell(
              onTap: () => _showAddEditDialog(service: service),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.edit_outlined, color: context.ct.textSecondary, size: 18),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Material(
            color: context.ct.errorSoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InkWell(
              onTap: () => _deleteService(service['_id']),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.delete_outline, color: AppColors.error, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
