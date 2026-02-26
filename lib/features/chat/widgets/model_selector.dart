import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../auth/auth_provider.dart';
import '../chat_provider.dart';

class ModelSelector extends ConsumerWidget {
  const ModelSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).valueOrNull;
    final selectedModel = ref.watch(selectedModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isPro = user?.isPro == true;
    final hasZaiKey = user?.isByok == true || user?.isPro == true;

    return _buildModelSelector(context, ref, selectedModel, isDark, isPro, hasZaiKey);
  }

  Widget _buildModelSelector(BuildContext context, WidgetRef ref, String selectedModel, bool isDark, bool isPro, bool hasZaiKey) {
    final displayName = _getDisplayName(selectedModel);
    final isProModel = ApiConstants.proModels.any((m) => m.modelId == selectedModel);
    final accentColor = isProModel ? const Color(0xFFFFB74D) : const Color(0xFF00D9A6);

    return PopupMenuButton<String>(
      onSelected: (model) {
        ref.read(selectedModelProvider.notifier).state = model;
      },
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDark ? const Color(0xFF2A2B45) : Colors.white,
      constraints: const BoxConstraints(maxHeight: 450),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2A2B45)
              : const Color(0xFFF0F0F8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 14,
              color: accentColor,
            ),
            const SizedBox(width: 4),
            Text(
              displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more,
              size: 16,
              color: accentColor,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];

        // 1. PRO models (if subscribed)
        if (isPro) {
          items.add(const PopupMenuItem<String>(
            enabled: false,
            height: 28,
            child: Text('PRO MODELS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFB74D))),
          ));
          for (final model in ApiConstants.proModels) {
            items.add(_modelItem(model.modelId, model.displayName, selectedModel,
              const Color(0xFFFFB74D), model.supportsImages));
          }
          items.add(const PopupMenuDivider());
        }

        // 2. Z.ai models (if BYOK key)
        if (hasZaiKey) {
          items.add(const PopupMenuItem<String>(
            enabled: false,
            height: 28,
            child: Text('Z.AI MODELS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6C63FF))),
          ));
          for (final model in ApiConstants.zaiModels) {
            items.add(_modelItem(model, model.toUpperCase(), selectedModel,
              const Color(0xFF6C63FF), false));
          }
          items.add(const PopupMenuDivider());
        }

        // 3. Free models (always)
        items.add(const PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text('FREE MODELS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF00D9A6))),
        ));
        for (final model in ApiConstants.chutesModels) {
          items.add(_modelItem(model.modelId, model.displayName, selectedModel,
            const Color(0xFF00D9A6), model.supportsImages));
        }

        return items;
      },
    );
  }

  PopupMenuItem<String> _modelItem(String modelId, String displayName, String selectedModel, Color accentColor, bool supportsImages) {
    final isSelected = modelId == selectedModel;
    return PopupMenuItem<String>(
      value: modelId,
      child: Row(
        children: [
          if (isSelected)
            Icon(Icons.check, size: 16, color: accentColor)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? accentColor : null,
              ),
            ),
          ),
          if (supportsImages)
            Icon(Icons.image_outlined, size: 14,
                color: Colors.blue.withOpacity(0.6)),
        ],
      ),
    );
  }

  String _getDisplayName(String model) {
    // Check Pro models
    final proMatch = ApiConstants.proModels.where((m) => m.modelId == model);
    if (proMatch.isNotEmpty) return proMatch.first.displayName;
    // Check free models
    final freeMatch = ApiConstants.chutesModels.where((m) => m.modelId == model);
    if (freeMatch.isNotEmpty) return freeMatch.first.displayName;
    // Z.ai models
    switch (model) {
      case 'glm-5': return 'GLM-5';
      case 'glm-4.7': return 'GLM-4.7';
      case 'glm-4.7-flash': return 'Flash';
      default: return model.split('/').last;
    }
  }
}
