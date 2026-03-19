import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, outlined, text, danger }
enum AppButtonSize { small, medium, large }

/// ZirveGo Kurumsal Buton Bileşeni
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isLoading;
  final bool fullWidth;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
    this.fullWidth = true,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final btnHeight = _getHeight();
    final padding = _getPadding();

    return SizedBox(
      width: fullWidth ? double.infinity : width,
      height: height ?? btnHeight,
      child: switch (variant) {
        AppButtonVariant.primary => _buildElevated(isDisabled, padding),
        AppButtonVariant.secondary => _buildSecondary(isDisabled, padding),
        AppButtonVariant.outlined => _buildOutlined(isDisabled, padding),
        AppButtonVariant.text => _buildText(isDisabled, padding),
        AppButtonVariant.danger => _buildDanger(isDisabled, padding),
      },
    );
  }

  Widget _buildElevated(bool isDisabled, EdgeInsets padding) {
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled ? AppColors.textDisabled : AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(10),
        ),
      ),
      child: _buildContent(AppColors.textOnPrimary),
    );
  }

  Widget _buildSecondary(bool isDisabled, EdgeInsets padding) {
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled ? AppColors.textDisabled : AppColors.secondary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(10),
        ),
      ),
      child: _buildContent(AppColors.textOnPrimary),
    );
  }

  Widget _buildOutlined(bool isDisabled, EdgeInsets padding) {
    return OutlinedButton(
      onPressed: isDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDisabled ? AppColors.textDisabled : AppColors.primary,
        side: BorderSide(
          color: isDisabled ? AppColors.textDisabled : AppColors.primary,
          width: 1.5,
        ),
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(10),
        ),
      ),
      child: _buildContent(
        isDisabled ? AppColors.textDisabled : AppColors.primary,
      ),
    );
  }

  Widget _buildText(bool isDisabled, EdgeInsets padding) {
    return TextButton(
      onPressed: isDisabled ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isDisabled ? AppColors.textDisabled : AppColors.secondary,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(10),
        ),
      ),
      child: _buildContent(
        isDisabled ? AppColors.textDisabled : AppColors.secondary,
      ),
    );
  }

  Widget _buildDanger(bool isDisabled, EdgeInsets padding) {
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled ? AppColors.textDisabled : AppColors.error,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(10),
        ),
      ),
      child: _buildContent(AppColors.textOnPrimary),
    );
  }

  Widget _buildContent(Color contentColor) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: contentColor,
        ),
      );
    }

    final textStyle = _getTextStyle().copyWith(color: contentColor);

    if (prefixIcon == null && suffixIcon == null) {
      return Text(label, style: textStyle);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (prefixIcon != null) ...[
          Icon(prefixIcon, size: _getIconSize(), color: contentColor),
          const SizedBox(width: 8),
        ],
        Text(label, style: textStyle),
        if (suffixIcon != null) ...[
          const SizedBox(width: 8),
          Icon(suffixIcon, size: _getIconSize(), color: contentColor),
        ],
      ],
    );
  }

  double _getHeight() => switch (size) {
        AppButtonSize.small => 40,
        AppButtonSize.medium => 52,
        AppButtonSize.large => 58,
      };

  EdgeInsets _getPadding() => switch (size) {
        AppButtonSize.small => const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        AppButtonSize.medium => const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        AppButtonSize.large => const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      };

  TextStyle _getTextStyle() => switch (size) {
        AppButtonSize.small => AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
        AppButtonSize.medium => AppTextStyles.labelLarge,
        AppButtonSize.large => AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
      };

  double _getIconSize() => switch (size) {
        AppButtonSize.small => 16,
        AppButtonSize.medium => 18,
        AppButtonSize.large => 22,
      };
}
