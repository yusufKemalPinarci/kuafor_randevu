import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../models/user_model.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  // Şifre değiştirme alanları
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _passExpanded = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  bool _isDeleting = false;

  // Bildirim tercihleri
  NotificationPreferences _notifPrefs = NotificationPreferences();
  String? _activeTier;
  bool _notifLoading = true;
  bool _notifSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotificationPreferences();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotificationPreferences();
    }
  }

  Future<void> _loadNotificationPreferences() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null || (user.role != 'Customer' && user.role != 'Barber')) return;

    final result = await UserService().getNotificationPreferences();
    if (!mounted) return;
    setState(() {
      if (result != null) {
        _notifPrefs = result.preferences;
        if (user.role == 'Barber') _activeTier = result.activeTier;
      }
      _notifLoading = false;
    });
  }

  Future<void> _saveNotificationPreferences() async {
    setState(() => _notifSaving = true);

    final user = Provider.of<UserProvider>(context, listen: false).user;
    // Berber: abonelik yoksa kilitli kanalları kapalı gönder
    final prefsToSend = (user?.role == 'Barber')
        ? _notifPrefs.copyWith(
            email: _canUseEmail ? _notifPrefs.email : false,
            sms: _canUseSms ? _notifPrefs.sms : false,
          )
        : _notifPrefs;

    final result = await UserService().updateNotificationPreferences(prefsToSend);
    if (mounted) {
      setState(() {
        _notifSaving = false;
        if (result != null) _notifPrefs = result;
      });
      if (result != null) {
        showAppSnackBar(context, 'Bildirim tercihleri güncellendi.');
      } else {
        showAppSnackBar(context, 'Tercihler kaydedilemedi.', isError: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ─── Şifre Değiştir (Firebase) ─────────────────────────────────
  Future<void> _changePassword() async {
    final current = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      showAppSnackBar(context, 'Tüm alanları doldurun.', isError: true);
      return;
    }
    if (newPass != confirm) {
      showAppSnackBar(context, 'Yeni şifreler eşleşmiyor.', isError: true);
      return;
    }
    if (newPass.length < 6) {
      showAppSnackBar(context, 'Şifre en az 6 karakter olmalıdır.',
          isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final error = await FirebaseAuthService().changePassword(
        currentPassword: current,
        newPassword: newPass,
      );
      if (!mounted) return;
      if (error != null) {
        showAppSnackBar(context, error, isError: true);
      } else {
        showAppSnackBar(context, 'Şifre başarıyla güncellendi.');
        setState(() {
          _passExpanded = false;
          _currentPassCtrl.clear();
          _newPassCtrl.clear();
          _confirmPassCtrl.clear();
        });
      }
    } catch (_) {
      if (mounted)
        showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmailVerification() async {
    setState(() => _isSaving = true);
    try {
      final error = await FirebaseAuthService().sendEmailVerification();
      if (!mounted) return;
      if (error != null) {
        showAppSnackBar(context, error, isError: true);
      } else {
        showAppSnackBar(context, 'Doğrulama e-postası gönderildi. Gelen kutunuzu kontrol edin.');
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'E-posta gönderilemedi. Lütfen tekrar deneyin.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final ct = context.ct;

    if (user == null) {
      return Scaffold(
        backgroundColor: ct.bg,
        body: const Center(
            child:
                CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // Convenience aliases (keep helper methods readable)
    final bg         = ct.bg;
    final card       = ct.surface;
    final border     = ct.surfaceBorder;
    final tPrimary   = ct.textPrimary;
    final tSecondary = ct.textSecondary;
    final tTertiary  = ct.textTertiary;

    final isEmailVerified = user.isEmailVerified ?? false;
    final isPhoneVerified = user.isPhoneVerified ?? false;
    final phone = user.phone ?? '';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: AppPageHeader(title: 'Ayarlar')),

            // ── HESAP BİLGİLERİ ───────────────────────────────────
            SliverToBoxAdapter(
              child: _pad(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('HESAP BİLGİLERİ', tTertiary),
                    const SizedBox(height: Spacing.sm + 2),
                    _card(
                      border: border,
                      card: card,
                      child: Column(
                        children: [
                          _infoRow(
                            icon: Icons.email_outlined,
                            label: 'E-posta',
                            value: user.email,
                            isVerified: isEmailVerified,
                            badgeLabel: isEmailVerified
                                ? 'Doğrulandı'
                                : 'Doğrulanmadı · Doğrula',
                            onBadgeTap: isEmailVerified
                                ? null
                                : _sendEmailVerification,
                            tPrimary: tPrimary,
                            tSecondary: tSecondary,
                            border: border,
                            hasDivider: true,
                          ),
                          _infoRow(
                            icon: Icons.phone_outlined,
                            label: 'Telefon',
                            value: phone.isNotEmpty ? phone : 'Eklenmedi',
                            isVerified: isPhoneVerified,
                            badgeLabel: isPhoneVerified
                                ? 'Doğrulandı'
                                : (phone.isNotEmpty
                                    ? 'Doğrulanmadı · Doğrula'
                                    : 'Ekle ve Doğrula'),
                            onBadgeTap: isPhoneVerified
                                ? null
                                : () => Navigator.pushNamed(
                                    context, '/phone_verification_page'),
                            tPrimary: tPrimary,
                            tSecondary: tSecondary,
                            border: border,
                            hasDivider: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── GÜVENLİK ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _pad(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('GÜVENLİK', tTertiary),
                    const SizedBox(height: Spacing.sm + 2),
                    Container(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          // Şifre Değiştir başlık satırı
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.vertical(
                              top: const Radius.circular(AppRadius.xl),
                              bottom: Radius.circular(
                                  _passExpanded ? 0 : AppRadius.xl),
                            ),
                            child: InkWell(
                              onTap: () => setState(
                                  () => _passExpanded = !_passExpanded),
                              borderRadius: BorderRadius.vertical(
                                top: const Radius.circular(AppRadius.xl),
                                bottom: Radius.circular(
                                    _passExpanded ? 0 : AppRadius.xl),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(Spacing.lg + 2),
                                child: Row(
                                  children: [
                                    _iconBox(
                                        Icons.lock_outline,
                                        AppColors.primary,
                                        AppColors.primary.withAlpha(18)),
                                    const SizedBox(width: Spacing.lg),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Şifre Değiştir',
                                              style: TextStyle(
                                                  color: tPrimary,
                                                  fontSize: 15,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text(
                                              'Hesap güvenliğinizi güncelleyin',
                                              style: TextStyle(
                                                  color: tSecondary,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    AnimatedRotation(
                                      turns: _passExpanded ? 0.5 : 0.0,
                                      duration: const Duration(
                                          milliseconds: 220),
                                      child: Icon(
                                          Icons
                                              .keyboard_arrow_down_rounded,
                                          color: tTertiary,
                                          size: 22),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Şifre formu — yumuşak açılır/kapanır
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _passExpanded
                                ? _passForm(border)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── BİLDİRİM AYARLARI (Sadece Berberler) ─────────────
            if (user.role == 'Barber')
              SliverToBoxAdapter(
                child: _pad(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('BİLDİRİM AYARLARI', tTertiary),
                      const SizedBox(height: Spacing.sm + 2),
                      _card(
                        border: border,
                        card: card,
                        child: _notifLoading
                            ? const Padding(
                                padding: EdgeInsets.all(Spacing.xl),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  _notifChannelRow(
                                    icon: Icons.notifications_outlined,
                                    label: 'Push Bildirimler',
                                    subtitle: 'Anlık bildirimler',
                                    value: _notifPrefs.push,
                                    enabled: true,
                                    onChanged: (v) {
                                      setState(() => _notifPrefs = _notifPrefs.copyWith(push: v));
                                      _saveNotificationPreferences();
                                    },
                                    onTap: () => _showPushDetailSheet(),
                                    tPrimary: tPrimary,
                                    tSecondary: tSecondary,
                                    border: border,
                                    hasDivider: true,
                                  ),
                                  _notifChannelRow(
                                    icon: Icons.email_outlined,
                                    label: 'E-posta Bildirimleri',
                                    subtitle: _canUseEmail
                                        ? 'Randevu e-postaları'
                                        : 'Standart abonelik gerekli',
                                    value: _notifPrefs.email,
                                    enabled: _canUseEmail,
                                    onChanged: (v) {
                                      setState(() => _notifPrefs = _notifPrefs.copyWith(email: v));
                                      _saveNotificationPreferences();
                                    },
                                    onTap: _canUseEmail
                                        ? () => _showEmailDetailSheet()
                                        : () => _showSubscriptionRequiredDialog(
                                            'E-posta Bildirimleri',
                                            'E-posta bildirimlerini kullanabilmek için Standart veya üzeri bir aboneliğe sahip olmanız gerekmektedir.',
                                            'Standart'),
                                    tPrimary: tPrimary,
                                    tSecondary: tSecondary,
                                    border: border,
                                    hasDivider: true,
                                    locked: !_canUseEmail,
                                  ),
                                  _notifChannelRow(
                                    icon: Icons.sms_outlined,
                                    label: 'SMS Bildirimleri',
                                    subtitle: _canUseSms
                                        ? 'SMS ile bildirimler'
                                        : 'Pro+ abonelik gerekli',
                                    value: _notifPrefs.sms,
                                    enabled: _canUseSms,
                                    onChanged: (v) {
                                      setState(() => _notifPrefs = _notifPrefs.copyWith(sms: v));
                                      _saveNotificationPreferences();
                                    },
                                    onTap: _canUseSms
                                        ? () => _showSmsDetailSheet()
                                        : () => _showSubscriptionRequiredDialog(
                                            'SMS Bildirimleri',
                                            'SMS bildirimlerini kullanabilmek için Pro veya Premium aboneliğe sahip olmanız gerekmektedir.',
                                            'Pro'),
                                    tPrimary: tPrimary,
                                    tSecondary: tSecondary,
                                    border: border,
                                    hasDivider: false,
                                    locked: !_canUseSms,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── MÜŞTERİ BİLDİRİM AYARLARI ─────────────────────
            if (user.role == 'Customer')
              SliverToBoxAdapter(
                child: _pad(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('BİLDİRİM AYARLARI', tTertiary),
                      const SizedBox(height: Spacing.sm + 2),
                      _card(
                        border: border,
                        card: card,
                        child: _notifLoading
                            ? const Padding(
                                padding: EdgeInsets.all(Spacing.xl),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  _notifChannelRow(
                                    icon: Icons.notifications_outlined,
                                    label: 'Push Bildirimler',
                                    subtitle: 'Randevu hatırlatma ve durum bildirimleri',
                                    value: _notifPrefs.push,
                                    enabled: true,
                                    onChanged: (v) {
                                      setState(() => _notifPrefs = _notifPrefs.copyWith(push: v));
                                      _saveNotificationPreferences();
                                    },
                                    onTap: () => _showCustomerPushDetailSheet(),
                                    tPrimary: tPrimary,
                                    tSecondary: tSecondary,
                                    border: border,
                                    hasDivider: true,
                                  ),
                                  _notifChannelRow(
                                    icon: Icons.email_outlined,
                                    label: 'E-posta Hatırlatma',
                                    subtitle: 'Randevu öncesi e-posta hatırlatması alın',
                                    value: _notifPrefs.customerEmailReminder,
                                    enabled: true,
                                    onChanged: (v) {
                                      setState(() => _notifPrefs = _notifPrefs.copyWith(customerEmailReminder: v));
                                      _saveNotificationPreferences();
                                    },
                                    tPrimary: tPrimary,
                                    tSecondary: tSecondary,
                                    border: border,
                                    hasDivider: true,
                                    showArrow: false,
                                  ),
                                  _notifChannelRow(
                                    icon: Icons.sms_outlined,
                                    label: 'SMS Hatırlatma',
                                    subtitle: 'Berberiniz SMS hizmeti sunuyorsa hatırlatma alırsınız',
                                    value: _notifPrefs.customerSmsReminder,
                                    enabled: true,
                                    onChanged: (v) {
                                      setState(() => _notifPrefs = _notifPrefs.copyWith(customerSmsReminder: v));
                                      _saveNotificationPreferences();
                                    },
                                    tPrimary: tPrimary,
                                    tSecondary: tSecondary,
                                    border: border,
                                    hasDivider: false,
                                    showArrow: false,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── GÖRÜNÜM ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _pad(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('GÖRÜNÜM', tTertiary),
                    const SizedBox(height: Spacing.sm + 2),
                    _card(
                      border: border,
                      card: card,
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _iconBox(
                                    Icons.palette_outlined,
                                    AppColors.primary,
                                    AppColors.primary.withAlpha(18)),
                                const SizedBox(width: Spacing.lg),
                                Text('Uygulama Teması',
                                    style: TextStyle(
                                        color: tPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: Spacing.xl),
                            Row(
                              children: [
                                Expanded(
                                  child: _themeOption(
                                    icon: Icons.dark_mode_rounded,
                                    label: 'Koyu',
                                    sublabel: 'Gece modu',
                                    isSelected: themeProvider.isDark,
                                    onTap: () =>
                                        themeProvider.setDark(true),
                                    border: border,
                                    tPrimary: tPrimary,
                                  ),
                                ),
                                const SizedBox(width: Spacing.md),
                                Expanded(
                                  child: _themeOption(
                                    icon: Icons.light_mode_rounded,
                                    label: 'Açık',
                                    sublabel: 'Gündüz modu',
                                    isSelected: !themeProvider.isDark,
                                    onTap: () =>
                                        themeProvider.setDark(false),
                                    border: border,
                                    tPrimary: tPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── UYGULAMA ────────────────────────────────────────
            SliverToBoxAdapter(
              child: _pad(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('UYGULAMA', tTertiary),
                    const SizedBox(height: Spacing.sm + 2),
                    _card(
                      border: border,
                      card: card,
                      child: Column(
                        children: [
                          _staticRow(
                            icon: Icons.info_outline,
                            label: 'Sürüm',
                            value: '1.0.0',
                            tPrimary: tPrimary,
                            tSecondary: tSecondary,
                            border: border,
                            hasDivider: true,
                          ),
                          _tapRow(
                            icon: Icons.description_outlined,
                            label: 'Kullanım Koşulları',
                            tPrimary: tPrimary,
                            border: border,
                            isTopRadius: false,
                            isBottomRadius: false,
                            onTap: () => _showInfoDialog(
                              'Kullanım Koşulları',
                              'Bu uygulama KuaFlex platformu tarafından sunulmaktadır. Uygulamayı kullanarak hizmet koşullarımızı kabul etmiş sayılırsınız.',
                            ),
                          ),
                          _tapRow(
                            icon: Icons.privacy_tip_outlined,
                            label: 'Gizlilik Politikası',
                            tPrimary: tPrimary,
                            border: border,
                            isTopRadius: false,
                            isBottomRadius: true,
                            onTap: () => _showInfoDialog(
                              'Gizlilik Politikası',
                              'Kişisel verileriniz 6698 sayılı KVKK kapsamında işlenmekte ve '
                                  'üçüncü taraflarla paylaşılmamaktadır.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    // Hesabı Sil — kırmızı / tehlikeli eylem
                    Material(
                      color: context.ct.errorSoft,
                      borderRadius:
                          BorderRadius.circular(AppRadius.xl),
                      child: InkWell(
                        onTap: _isDeleting ? null : _confirmDelete,
                        borderRadius:
                            BorderRadius.circular(AppRadius.xl),
                        child: Container(
                          padding:
                              const EdgeInsets.all(Spacing.lg + 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                AppRadius.xl),
                            border: Border.all(
                                color:
                                    AppColors.error.withAlpha(45)),
                          ),
                          child: Row(
                            children: [
                              _isDeleting
                                  ? const SizedBox(
                                      width: 38,
                                      height: 38,
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    )
                                  : _iconBox(
                                      Icons.delete_forever_outlined,
                                      AppColors.error,
                                      AppColors.error.withAlpha(22)),
                              const SizedBox(width: Spacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_isDeleting ? 'Hesap siliniyor...' : 'Hesabı Sil',
                                        style: const TextStyle(
                                            color: AppColors.error,
                                            fontSize: 15,
                                            fontWeight:
                                                FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    const Text(
                                        'Tüm verileriniz kalıcı olarak silinir',
                                        style: TextStyle(
                                            color: AppColors.error,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (!_isDeleting)
                                const Icon(Icons.arrow_forward_ios,
                                    color: AppColors.error, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: Spacing.huge)),
          ],
        ),
      ),
    );
  }

  // ─── Şifre formu widget'ı ────────────────────────────────────
  Widget _passForm(Color border) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg + 2, 0, Spacing.lg + 2, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: border),
          const SizedBox(height: Spacing.xl),
          _passField(
              ctrl: _currentPassCtrl,
              hint: 'Mevcut şifre',
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent)),
          const SizedBox(height: Spacing.md),
          _passField(
              ctrl: _newPassCtrl,
              hint: 'Yeni şifre',
              obscure: _obscureNew,
              onToggle: () =>
                  setState(() => _obscureNew = !_obscureNew)),
          const SizedBox(height: Spacing.md),
          _passField(
              ctrl: _confirmPassCtrl,
              hint: 'Yeni şifre (tekrar)',
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm)),
          const SizedBox(height: Spacing.xl),
          AppLoadingButton(
            label: 'Şifreyi Güncelle',
            isLoading: _isSaving,
            onPressed: _changePassword,
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    if (_isDeleting) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
            'Bu işlem geri alınamaz. Tüm randevularınız, profil bilgileriniz '
            've abonelik verileriniz kalıcı olarak silinir. Devam etmek istiyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style:
                TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;
    final userProvider = context.read<UserProvider>();
    final jwt = userProvider.user?.jwtToken;
    if (jwt == null || jwt.isEmpty) {
      if (mounted) showAppSnackBar(context, 'Oturum bulunamadı. Lütfen tekrar giriş yapın.', isError: true);
      return;
    }

    setState(() => _isDeleting = true);
    try {
      final result = await UserService().deleteAccount(jwt);
      if (!mounted) return;

      if (result.success) {
        await userProvider.logout();
        if (!mounted) return;
        showAppSnackBar(context, result.message);
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      } else {
        showAppSnackBar(context, result.message, isError: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Hesap silme hatası: $e');
      if (mounted) showAppSnackBar(context, 'Hesap silinirken bir hata oluştu.', isError: true);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ─── Küçük yardımcı widget'lar ────────────────────────────────

  Widget _pad({required Widget child}) => Padding(
      padding:
          const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.xxl, Spacing.xxl, 0),
      child: child);

  Widget _label(String text, Color color) => Text(text,
      style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1));

  Widget _card(
          {required Color card,
          required Color border,
          required Widget child}) =>
      Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: border),
          ),
          child: child);

  Widget _iconBox(IconData icon, Color iconColor, Color bgColor) =>
      Container(
        padding: const EdgeInsets.all(Spacing.sm + 2),
        decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Icon(icon, color: iconColor, size: 20),
      );

  // Hesap bilgisi satırı (e-posta / telefon)
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isVerified,
    required String badgeLabel,
    required VoidCallback? onBadgeTap,
    required Color tPrimary,
    required Color tSecondary,
    required Color border,
    required bool hasDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Spacing.lg + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(icon, AppColors.primary,
                  AppColors.primary.withAlpha(18)),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: tSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: TextStyle(
                            color: tPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.sm + 2),
                    GestureDetector(
                      onTap: onBadgeTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm + 2,
                            vertical: Spacing.xs + 1),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? context.ct.successSoft
                              : context.ct.warningSoft,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color: isVerified
                                  ? AppColors.success.withAlpha(45)
                                  : AppColors.warning.withAlpha(45)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                isVerified
                                    ? Icons.verified_rounded
                                    : Icons.warning_amber_rounded,
                                color: isVerified
                                    ? AppColors.success
                                    : AppColors.warning,
                                size: 13),
                            const SizedBox(width: 4),
                            Text(badgeLabel,
                                style: TextStyle(
                                    color: isVerified
                                        ? AppColors.success
                                        : AppColors.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                            if (!isVerified && onBadgeTap != null) ...[
                              const SizedBox(width: 3),
                              Icon(Icons.arrow_forward_ios,
                                  color: AppColors.warning, size: 10),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (hasDivider) Divider(height: 1, color: border),
      ],
    );
  }

  // Şifre input alanı
  Widget _passField({
    required TextEditingController ctrl,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        style:
            TextStyle(color: context.ct.textPrimary, fontSize: 15),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.lock_outline, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18),
            onPressed: onToggle,
          ),
        ),
      );

  // Tema seçim kutusu (Koyu / Açık)
  Widget _themeOption({
    required IconData icon,
    required String label,
    required String sublabel,
    required bool isSelected,
    required VoidCallback onTap,
    required Color border,
    required Color tPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            vertical: Spacing.xl, horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(18)
              : context.ct.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
              color: isSelected ? AppColors.primary : border,
              width: isSelected ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected
                    ? AppColors.primary
                    : context.ct.textTertiary,
                size: 28),
            const SizedBox(height: Spacing.sm),
            Text(label,
                style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : context.ct.textSecondary,
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500)),
            const SizedBox(height: 2),
            Text(sublabel,
                style: TextStyle(
                    color: isSelected
                        ? AppColors.primary.withAlpha(160)
                        : context.ct.textTertiary,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // Statik bilgi satırı (örn: Sürüm 1.0.0)
  Widget _staticRow({
    required IconData icon,
    required String label,
    required String value,
    required Color tPrimary,
    required Color tSecondary,
    required Color border,
    required bool hasDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg + 2, vertical: Spacing.lg + 2),
          child: Row(
            children: [
              _iconBox(icon, AppColors.primary,
                  AppColors.primary.withAlpha(18)),
              const SizedBox(width: Spacing.lg),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: tPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600))),
              Text(value,
                  style: TextStyle(
                      color: tSecondary, fontSize: 14)),
            ],
          ),
        ),
        if (hasDivider) Divider(height: 1, color: border),
      ],
    );
  }

  // Tıklanabilir satır (Kullanım Koşulları vb.)
  Widget _tapRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color tPrimary,
    required Color border,
    required bool isTopRadius,
    required bool isBottomRadius,
    bool hasDivider = true,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.vertical(
            top: isTopRadius
                ? const Radius.circular(AppRadius.xl)
                : Radius.zero,
            bottom: isBottomRadius
                ? const Radius.circular(AppRadius.xl)
                : Radius.zero,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.vertical(
              top: isTopRadius
                  ? const Radius.circular(AppRadius.xl)
                  : Radius.zero,
              bottom: isBottomRadius
                  ? const Radius.circular(AppRadius.xl)
                  : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg + 2, vertical: Spacing.lg + 2),
              child: Row(
                children: [
                  _iconBox(icon, AppColors.primary,
                      AppColors.primary.withAlpha(18)),
                  const SizedBox(width: Spacing.lg),
                  Expanded(
                      child: Text(label,
                          style: TextStyle(
                              color: tPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600))),
                  Icon(Icons.arrow_forward_ios,
                      color: context.ct.textHint, size: 14),
                ],
              ),
            ),
          ),
        ),
        if (hasDivider) Divider(height: 1, color: border),
      ],
    );
  }

  // ─── Bildirim tercihi yardımcıları ─────────────────────────

  static const _tierOrder = ['standart', 'pro', 'premium'];

  bool get _canUseEmail =>
      _activeTier != null && _tierOrder.indexOf(_activeTier!) >= 0;

  bool get _canUseSms =>
      _activeTier != null && _tierOrder.indexOf(_activeTier!) >= 1;

  // ─── Abonelik gereksinim dialogu ──────────────────────────

  void _showSubscriptionRequiredDialog(String title, String message, String requiredTier) {
    final ct = context.ct;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: AppColors.warning, size: 22),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(title,
                  style: TextStyle(color: ct.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Text(message, style: TextStyle(color: ct.textSecondary, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat', style: TextStyle(color: ct.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/subscription');
            },
            child: const Text('Abonelik Planları', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Detaylı Bildirim Ayarları Bottom Sheet'leri ───────────

  void _showPushDetailSheet() {
    _showDetailSheet(
      title: 'Push Bildirim Ayarları',
      icon: Icons.notifications_outlined,
      masterValue: _notifPrefs.push,
      onMasterChanged: (v) {
        setState(() => _notifPrefs = _notifPrefs.copyWith(push: v));
        _saveNotificationPreferences();
      },
      items: [
        _DetailItem(
          label: 'Yeni Randevu',
          subtitle: 'Müşteri randevu oluşturduğunda bildirim alın',
          value: _notifPrefs.pushNewAppointment,
          onChanged: (v) {
            setState(() => _notifPrefs = _notifPrefs.copyWith(pushNewAppointment: v));
            _saveNotificationPreferences();
          },
        ),
        _DetailItem(
          label: 'Müşteri İptali',
          subtitle: 'Müşteri randevuyu iptal ettiğinde bildirim alın',
          value: _notifPrefs.pushCancellation,
          onChanged: (v) {
            setState(() => _notifPrefs = _notifPrefs.copyWith(pushCancellation: v));
            _saveNotificationPreferences();
          },
        ),
        _DetailItem(
          label: 'Randevu Hatırlatma',
          subtitle: 'Randevu yaklaşınca (1 saat ve 15 dk önce) bildirim alın',
          value: _notifPrefs.pushReminder,
          onChanged: (v) {
            setState(() => _notifPrefs = _notifPrefs.copyWith(pushReminder: v));
            _saveNotificationPreferences();
          },
        ),
      ],
    );
  }

  void _showEmailDetailSheet() {
    _showDetailSheet(
      title: 'E-posta Bildirim Ayarları',
      icon: Icons.email_outlined,
      masterValue: _notifPrefs.email,
      onMasterChanged: (v) {
        setState(() => _notifPrefs = _notifPrefs.copyWith(email: v));
        _saveNotificationPreferences();
      },
      items: [
        _DetailItem(
          label: 'Günlük Özet',
          subtitle: 'Her gün ertesi günün randevu programını e-posta ile alın',
          value: _notifPrefs.emailDailySummary,
          onChanged: (v) {
            setState(() => _notifPrefs = _notifPrefs.copyWith(emailDailySummary: v));
            _saveNotificationPreferences();
          },
        ),
        _DetailItem(
          label: 'Randevu Hatırlatma',
          subtitle: 'Randevu yaklaşınca müşteriye e-posta hatırlatma gönderilsin',
          value: _notifPrefs.emailReminder,
          onChanged: (v) {
            setState(() => _notifPrefs = _notifPrefs.copyWith(emailReminder: v));
            _saveNotificationPreferences();
          },
        ),
      ],
    );
  }

  void _showSmsDetailSheet() {
    _showDetailSheet(
      title: 'SMS Bildirim Ayarları',
      icon: Icons.sms_outlined,
      masterValue: _notifPrefs.sms,
      onMasterChanged: (v) {
        setState(() => _notifPrefs = _notifPrefs.copyWith(sms: v));
        _saveNotificationPreferences();
      },
      items: [
        _DetailItem(
          label: 'Yeni Randevu',
          subtitle: 'Müşteri randevu aldığında SMS bildirim alın',
          value: _notifPrefs.smsNewAppointment,
          onChanged: (v) {
            setState(() => _notifPrefs = _notifPrefs.copyWith(smsNewAppointment: v));
            _saveNotificationPreferences();
          },
        ),
        _DetailItem(
          label: 'Randevu Hatırlatma',
          subtitle: 'Randevu yaklaşınca SMS hatırlatma gönderilsin',
          value: _notifPrefs.smsReminder,
          onChanged: (v) {
            setState(() => _notifPrefs = _notifPrefs.copyWith(smsReminder: v));
            _saveNotificationPreferences();
          },
        ),
      ],
    );
  }

  void _showCustomerPushDetailSheet() {
    _showDetailSheet(
      title: 'Push Bildirim Ayarları',
      icon: Icons.notifications_outlined,
      masterValue: _notifPrefs.push,
      onMasterChanged: (v) {
        setState(() => _notifPrefs = _notifPrefs.copyWith(push: v));
        _saveNotificationPreferences();
      },
      items: [
        _DetailItem(
          label: 'Randevu Durumu',
          subtitle: 'Randevunuz onaylandığında veya iptal edildiğinde bildirim alın',
          value: _notifPrefs.customerPushStatusChange,
          onChanged: (v) {
            setState(() => _notifPrefs = _notifPrefs.copyWith(customerPushStatusChange: v));
            _saveNotificationPreferences();
          },
        ),
        _DetailItem(
          label: 'Randevu Hatırlatma',
          subtitle: 'Randevu yaklaşınca bildirim alın',
          value: _notifPrefs.customerPushReminder,
          onChanged: (v) {
            setState(() => _notifPrefs = _notifPrefs.copyWith(customerPushReminder: v));
            _saveNotificationPreferences();
          },
        ),
      ],
    );
  }

  void _showDetailSheet({
    required String title,
    required IconData icon,
    required bool masterValue,
    required ValueChanged<bool> onMasterChanged,
    required List<_DetailItem> items,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final ct = ctx.ct;
          return Container(
            decoration: BoxDecoration(
              color: ct.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sürükleme çubuğu
                  Container(
                    margin: const EdgeInsets.only(top: Spacing.md),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ct.textHint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Başlık + ana toggle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.xl, Spacing.lg, Spacing.sm),
                    child: Row(
                      children: [
                        _iconBox(icon, AppColors.primary, AppColors.primary.withAlpha(18)),
                        const SizedBox(width: Spacing.lg),
                        Expanded(
                          child: Text(title,
                              style: TextStyle(color: ct.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                        Switch.adaptive(
                          value: masterValue,
                          onChanged: (v) {
                            onMasterChanged(v);
                            setSheetState(() {});
                          },
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: ct.surfaceBorder),
                  // Alt tercihler
                  AnimatedOpacity(
                    opacity: masterValue ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !masterValue || _notifSaving,
                      child: Column(
                        children: items.map((item) => _detailToggleRow(
                          ctx: ctx,
                          label: item.label,
                          subtitle: item.subtitle,
                          value: item.value,
                          onChanged: (v) {
                            item.value = v;
                            item.onChanged(v);
                            setSheetState(() {});
                          },
                        )).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailToggleRow({
    required BuildContext ctx,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final ct = ctx.ct;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl, vertical: Spacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: ct.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: ct.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ─── Kanal satırı (tıklanabilir + toggle) ─────────────────

  Widget _notifChannelRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTap,
    required Color tPrimary,
    required Color tSecondary,
    required Color border,
    required bool hasDivider,
    bool locked = false,
    bool showArrow = true,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg + 2, vertical: Spacing.lg),
              child: Row(
                children: [
                  _iconBox(
                    locked ? Icons.lock_outline : icon,
                    locked ? tSecondary : AppColors.primary,
                    locked
                        ? tSecondary.withAlpha(18)
                        : AppColors.primary.withAlpha(18),
                  ),
                  const SizedBox(width: Spacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                color: enabled ? tPrimary : tSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(subtitle,
                                  style: TextStyle(
                                      color: tSecondary,
                                      fontSize: 12)),
                            ),
                            if (enabled && showArrow) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios,
                                  color: context.ct.textHint, size: 10),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    ignoring: !enabled || _notifSaving,
                    child: Opacity(
                      opacity: enabled ? 1.0 : 0.4,
                      child: Switch.adaptive(
                        value: enabled ? value : false,
                        onChanged: onChanged,
                        activeColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasDivider) Divider(height: 1, color: border),
      ],
    );
  }
}

class _DetailItem {
  final String label;
  final String subtitle;
  bool value;
  final ValueChanged<bool> onChanged;

  _DetailItem({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
}
