import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../services/api_client.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  int _page = 1;
  int _totalPages = 1;
  String? _roleFilter;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers({int page = 1}) async {
    setState(() => _isLoading = true);
    try {
      String url = '/api/admin/users?page=$page&limit=20';
      if (_roleFilter != null) url += '&role=$_roleFilter';
      final search = _searchController.text.trim();
      if (search.isNotEmpty) url += '&search=${Uri.encodeComponent(search)}';

      final response = await ApiClient().get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _users = data['users'] ?? [];
          _page = data['page'] ?? 1;
          _totalPages = data['totalPages'] ?? 1;
          _isLoading = false;
        });
      } else {
        if (mounted) showAppSnackBar(context, 'Kullanıcılar yüklenemedi.', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Bağlantı hatası.', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      final response = await ApiClient().put(
        '/api/admin/users/$userId',
        body: {'role': newRole},
      );
      if (response.statusCode == 200) {
        showAppSnackBar(context, 'Rol güncellendi.');
        _fetchUsers(page: _page);
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Rol güncellenemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  Future<void> _deleteUser(String userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text('Kullanıcıyı Sil', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('"$name" kullanıcısını ve tüm ilişkili verilerini silmek istediğinize emin misiniz?', style: TextStyle(color: context.ct.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: context.ct.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await ApiClient().delete('/api/admin/users/$userId');
      if (response.statusCode == 200) {
        showAppSnackBar(context, 'Kullanıcı silindi.');
        _fetchUsers(page: _page);
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Kullanıcı silinemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'İnternet bağlantınızı kontrol edip tekrar deneyin.', isError: true);
    }
  }

  void _showUserDetail(dynamic user) {
    final userId = user['_id'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _UserDetailSheet(userId: userId, onAction: () => _fetchUsers(page: _page)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search + Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: context.ct.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'İsim, e-posta veya telefon ara...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: Spacing.md),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _searchController.clear(); _fetchUsers(); })
                        : null,
                  ),
                  onSubmitted: (_) => _fetchUsers(),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () => _fetchUsers());
                  },
                ),
              ),
              const SizedBox(width: Spacing.sm + 2),
              PopupMenuButton<String?>(
                icon: Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: context.ct.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: _roleFilter != null ? AppColors.primary : context.ct.surfaceBorder),
                  ),
                  child: Icon(Icons.filter_list, color: _roleFilter != null ? AppColors.primary : context.ct.textSecondary, size: 20),
                ),
                color: context.ct.surface,
                onSelected: (val) {
                  setState(() => _roleFilter = val);
                  _fetchUsers();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: null, child: Text('Tümü')),
                  const PopupMenuItem(value: 'Customer', child: Text('Müşteri')),
                  const PopupMenuItem(value: 'Barber', child: Text('Berber')),
                  const PopupMenuItem(value: 'Admin', child: Text('Admin')),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: Spacing.md),

        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _users.isEmpty
                  ? AppEmptyState(icon: Icons.people_outline, title: 'Kullanıcı bulunamadı')
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => _fetchUsers(page: _page),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
                        itemCount: _users.length + 1, // +1 for pagination
                        itemBuilder: (ctx, i) {
                          if (i == _users.length) return _buildPagination();
                          return _buildUserCard(_users[i]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildUserCard(dynamic user) {
    final name = user['name'] ?? '-';
    final email = user['email'] ?? '-';
    final role = user['role'] ?? 'Customer';
    final phone = user['phone'] ?? '';
    final userId = user['_id'] ?? '';

    String roleLabel;
    Color roleColor;
    IconData roleIcon;
    switch (role) {
      case 'Barber':
        roleLabel = 'Berber';
        roleColor = AppColors.primary;
        roleIcon = Icons.content_cut;
        break;
      case 'Admin':
        roleLabel = 'Admin';
        roleColor = AppColors.info;
        roleIcon = Icons.shield;
        break;
      default:
        roleLabel = 'Müşteri';
        roleColor = AppColors.success;
        roleIcon = Icons.person;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Material(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: () => _showUserDetail(user),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
            ),
            child: Row(
              children: [
                AppAvatar(letter: name, size: 44, withShadow: false),
                const SizedBox(width: Spacing.md + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(email, style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(phone, style: TextStyle(color: context.ct.textHint, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 2, vertical: Spacing.xs),
                  decoration: BoxDecoration(color: roleColor.withAlpha(18), borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(roleIcon, color: roleColor, size: 14),
                      const SizedBox(width: 4),
                      Text(roleLabel, style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                // Actions
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: context.ct.textHint, size: 20),
                  color: context.ct.surface,
                  onSelected: (action) {
                    switch (action) {
                      case 'make_barber': _updateUserRole(userId, 'Barber'); break;
                      case 'make_customer': _updateUserRole(userId, 'Customer'); break;
                      case 'delete': _deleteUser(userId, name); break;
                    }
                  },
                  itemBuilder: (_) => [
                    if (role != 'Barber') const PopupMenuItem(value: 'make_barber', child: Text('Berber Yap')),
                    if (role != 'Customer') const PopupMenuItem(value: 'make_customer', child: Text('Müşteri Yap')),
                    const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.error))),
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
          _paginationBtn(Icons.chevron_left, _page > 1, () => _fetchUsers(page: _page - 1)),
          const SizedBox(width: Spacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm + 2),
            decoration: BoxDecoration(color: context.ct.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Text('$_page / $_totalPages', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: Spacing.md),
          _paginationBtn(Icons.chevron_right, _page < _totalPages, () => _fetchUsers(page: _page + 1)),
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

// ─── User Detail Bottom Sheet ─────────────────────────────────
class _UserDetailSheet extends StatefulWidget {
  final String userId;
  final VoidCallback onAction;

  const _UserDetailSheet({required this.userId, required this.onAction});

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  Map<String, dynamic>? _user;
  List<dynamic> _appointments = [];
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final response = await ApiClient().get('/api/admin/users/${widget.userId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _user = data['user'];
          _appointments = data['appointments'] ?? [];
          _services = data['services'] ?? [];
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.ct.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _user == null
              ? Center(child: Text('Kullanıcı bulunamadı', style: TextStyle(color: context.ct.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, Spacing.xxxl),
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.ct.surfaceBorder, borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: Spacing.xxl),
                    Center(child: AppAvatar(letter: _user!['name'] ?? '?', size: 72)),
                    const SizedBox(height: Spacing.lg),
                    Center(child: Text(_user!['name'] ?? '-', style: TextStyle(color: context.ct.textPrimary, fontSize: 22, fontWeight: FontWeight.w700))),
                    Center(child: Text(_user!['email'] ?? '-', style: TextStyle(color: context.ct.textSecondary, fontSize: 14))),
                    if ((_user!['phone'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Center(child: Text(_user!['phone'], style: TextStyle(color: context.ct.textTertiary, fontSize: 13))),
                    ],
                    const SizedBox(height: Spacing.md),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.md + 2, vertical: Spacing.xs + 2),
                        decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: Text(_user!['role'] ?? '-', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),

                    if (_services.isNotEmpty) ...[
                      const SizedBox(height: Spacing.xxl),
                      Text('HİZMETLER', style: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: Spacing.sm + 2),
                      ..._services.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.xs + 2),
                        child: Container(
                          padding: const EdgeInsets.all(Spacing.md),
                          decoration: BoxDecoration(color: context.ct.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: context.ct.surfaceBorder.withAlpha(80))),
                          child: Row(
                            children: [
                              Expanded(child: Text(s['title'] ?? '-', style: TextStyle(color: context.ct.textPrimary, fontSize: 14))),
                              Text('₺${s['price'] ?? 0}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(width: Spacing.sm),
                              Text('${s['durationMinutes'] ?? 0} dk', style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                            ],
                          ),
                        ),
                      )),
                    ],

                    if (_appointments.isNotEmpty) ...[
                      const SizedBox(height: Spacing.xxl),
                      Text('SON RANDEVULAR', style: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: Spacing.sm + 2),
                      ..._appointments.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.xs + 2),
                        child: Container(
                          padding: const EdgeInsets.all(Spacing.md),
                          decoration: BoxDecoration(color: context.ct.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: context.ct.surfaceBorder.withAlpha(80))),
                          child: Row(
                            children: [
                              Expanded(child: Text(a['customerName'] ?? '-', style: TextStyle(color: context.ct.textPrimary, fontSize: 14))),
                              AppStatusBadge(status: a['status'] ?? 'pending'),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ],
                ),
    );
  }
}
