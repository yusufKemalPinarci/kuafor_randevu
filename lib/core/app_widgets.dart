import 'package:flutter/material.dart';
import 'app_theme.dart';

// ─── Snackbar Helper ──────────────────────────────────────────
void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? AppColors.error : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: context.ct.surfaceLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      margin: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
    ),
  );
}

// ─── Page Header with Back Button ─────────────────────────────
class AppPageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  const AppPageHeader({super.key, required this.title, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.sm, Spacing.sm, Spacing.xxl, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: context.ct.textSecondary, size: 20),
            onPressed: onBack ?? () => Navigator.pop(context),
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          if (trailing != null) trailing! else const SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ─── Avatar Circle ────────────────────────────────────────────
class AppAvatar extends StatelessWidget {
  final String letter;
  final double size;
  final bool withShadow;

  const AppAvatar({super.key, required this.letter, this.size = 48, this.withShadow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        boxShadow: withShadow
            ? [BoxShadow(color: AppColors.primary.withAlpha(50), blurRadius: 16, offset: const Offset(0, 4))]
            : null,
      ),
      child: Center(
        child: Text(
          letter.isNotEmpty ? letter[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ─── Header Icon Button ──────────────────────────────────────
class AppIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double? size;
  final Color? iconColor;

  const AppIconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final double btnSize = size ?? 44;
    Widget btn = Material(
      color: context.ct.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: btnSize,
          height: btnSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: context.ct.surfaceBorder),
          ),
          child: Icon(icon, color: iconColor ?? context.ct.textSecondary, size: btnSize * 0.45),
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

// ─── Status Badge ─────────────────────────────────────────────
class AppStatusBadge extends StatelessWidget {
  final String status;

  const AppStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;
    switch (status) {
      case 'confirmed':
        color = AppColors.success;
        text = 'Onaylı';
        icon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        color = AppColors.error;
        text = 'İptal';
        icon = Icons.cancel_outlined;
        break;
      default:
        color = AppColors.warning;
        text = 'Bekliyor';
        icon = Icons.schedule;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 2, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────
class AppStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color bgColor;
  final Color accentColor;
  final VoidCallback? onTap;

  const AppStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.bgColor,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg + 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: accentColor.withAlpha(25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.sm + 2),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(22),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: Spacing.md),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: TextStyle(color: accentColor, fontSize: 22, fontWeight: FontWeight.w800)),
                      Text(label, style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────
class AppSectionLabel extends StatelessWidget {
  final String text;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const AppSectionLabel({super.key, required this.text, this.trailing, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        children: [
          Text(text, style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs + 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(trailing!, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.ct.surface,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                border: Border.all(color: context.ct.surfaceBorder),
              ),
              child: Icon(icon, size: 36, color: context.ct.textHint),
            ),
            const SizedBox(height: Spacing.xxl),
            Text(title, style: TextStyle(color: context.ct.textSecondary, fontSize: 17, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(subtitle!, style: TextStyle(color: context.ct.textTertiary, fontSize: 14), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Spacing.xxl),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 20),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 52),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Menu Item Row ────────────────────────────────────────────
class AppMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const AppMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.primary;
    final textColor = isDestructive ? AppColors.error : context.ct.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Material(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg + 2, vertical: Spacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.sm + 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(isDestructive ? 15 : 18),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Text(label, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.arrow_forward_ios, color: context.ct.textHint, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Primary Loading Button ───────────────────────────────────
class AppLoadingButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final IconData? icon;

  const AppLoadingButton({
    super.key,
    required this.label,
    this.isLoading = false,
    this.onPressed,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          disabledBackgroundColor: (backgroundColor ?? AppColors.primary).withAlpha(80),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          elevation: 0,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: Spacing.sm),
                    ],
                    Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }
}
