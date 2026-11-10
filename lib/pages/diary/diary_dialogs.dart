import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/models/diary_entry_model.dart';
import '../../theme/app_theme.dart';
import 'diary_provider.dart';
import '../../services/language_notifier.dart';

class DiaryDialogs {
  /// Older entries stored a Lithuanian "empty entry" text; newer ones store ''.
  static String _previewText(DiaryEntryModel e, LanguageNotifier lang) {
    if (e.preview.isEmpty || e.preview == 'Tuščias įrašas') return lang.t('empty_entry');
    return e.preview;
  }

  static void showUpgradeDialog(BuildContext context, String message) {
    final lang = context.read<LanguageNotifier>();
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.background2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(lang.t('premium_feature_title'), style: TextStyle(fontWeight: FontWeight.bold, color: colors.textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(color: colors.textColor)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.intenseColor.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.t('premium_benefits_title'), style: TextStyle(fontWeight: FontWeight.bold, color: colors.textColor)),
                  const SizedBox(height: 6),
                  Text(lang.t('premium_benefit_unlimited_entries'), style: TextStyle(color: colors.textColor)),
                  Text(lang.t('premium_benefit_unlimited_photos'), style: TextStyle(color: colors.textColor)),
                  Text(lang.t('premium_benefit_stats'), style: TextStyle(color: colors.textColor)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.t('later'), style: TextStyle(color: colors.appBarUnpickedColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: navigate to paywall
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.intenseColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(lang.t('get_premium'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showAddCategoryDialog(BuildContext context, DiaryProvider provider) {
    final lang = context.read<LanguageNotifier>();
    final colors = context.colors;

    // Premium gate: max 1 category for free users
    if (!provider.isPremium && provider.categories.length >= 1) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: colors.background2,
          title: Text('⭐ ${lang.t('premium_feature_title')}', style: TextStyle(color: colors.textColor)),
          content: Text(
            lang.t('premium_category_limit'),
            style: TextStyle(color: colors.appBarUnpickedColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.t('cancel'), style: TextStyle(color: colors.textColor)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: navigate to paywall
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.intenseColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(lang.t('get_premium')),
            ),
          ],
        ),
      );
      return; // ← stop here, don't show add dialog
    }

    // Free user with 0 categories OR premium user — show normal dialog
    final TextEditingController catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.background2,
          title: Text(lang.t('new_category'), style: TextStyle(color: colors.textColor)),
          content: TextField(
            controller: catController,
            style: TextStyle(color: colors.textColor),
            decoration: InputDecoration(
              hintText: lang.t('category_hint'),
              hintStyle: TextStyle(color: colors.appBarUnpickedColor),
              filled: true,
              fillColor: colors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(lang.t('cancel'), style: TextStyle(color: colors.textColor))),
            ElevatedButton(
              onPressed: () {
                final text = catController.text.trim();
                if (text.isNotEmpty && !provider.categories.contains(text)) {
                  provider.addCategory(text);
                  Navigator.pop(context);
                } else if (provider.categories.contains(text)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('category_already_exists'))));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: colors.intenseColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(lang.t('add')),
            ),
          ],
        );
      },
    );
  }

  static void showDeleteCategoryDialog(BuildContext context, DiaryProvider provider, String category) {
    final lang = context.read<LanguageNotifier>();
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.background2,
          title: Text(lang.t('delete_category_confirm'), style: TextStyle(color: colors.textColor)),
          content: Text(lang.tp('delete_category_text', {'category': category}), style: TextStyle(color: colors.textColor)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(lang.t('cancel'), style: TextStyle(color: colors.textColor))),
            ElevatedButton(
              onPressed: () {
                provider.deleteCategory(category);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.tp('category_deleted', {'category': category})), backgroundColor: Colors.redAccent));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(lang.t('delete')),
            ),
          ],
        );
      },
    );
  }

  static void showImagePickerOptions(BuildContext context, DiaryProvider provider) {
    final lang = context.read<LanguageNotifier>();
    final colors = context.colors;
    if (!provider.canAddPhoto) {
      showUpgradeDialog(context, lang.tp('photo_limit_week_msg', {'limit': 3, 'this_week': provider.photosThisWeek}));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.background2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.appBarUnpickedColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2)))),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: colors.textColor),
                title: Text(lang.t('pick_from_gallery'), style: TextStyle(color: colors.textColor)),
                onTap: () {
                  Navigator.pop(context);
                  provider.pickImage(ImageSource.gallery).catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.tp('error_with_details', {'error': e}))));
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: colors.textColor),
                title: Text(lang.t('take_new_photo'), style: TextStyle(color: colors.textColor)),
                onTap: () {
                  Navigator.pop(context);
                  provider.pickImage(ImageSource.camera).catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.tp('error_with_details', {'error': e}))));
                  });
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  static void showEntryDialog(BuildContext context, DiaryEntryModel e) {
    final lang = context.read<LanguageNotifier>();
    final colors = context.colors;
    final dateStr = '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.background2,
        title: Text(dateStr, style: TextStyle(color: colors.textColor)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (e.moodImage != null && e.moodImage!.isNotEmpty)
                    Image.asset(e.moodImage!, width: 32, height: 32),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(8)),
                    child: Text(lang.moodLabel(e.mood), style: TextStyle(color: colors.textColor)),
                  ),
                ],
              ),
              if (e.highlight.isNotEmpty) ...[const SizedBox(height: 12), Text("✨ ${e.highlight}", style: TextStyle(color: colors.textColor))],
              if (e.diaryText.isNotEmpty) ...[const SizedBox(height: 12), Text("📖 ${e.diaryText}", style: TextStyle(color: colors.textColor))],
              if (e.imageUrl != null && e.imageUrl!.isNotEmpty) ...[
                 const SizedBox(height: 16),
                 ClipRRect(
                   borderRadius: BorderRadius.circular(14),
                   child: CachedNetworkImage(imageUrl: e.imageUrl!, fit: BoxFit.contain, placeholder: (context, url) => Center(child: CircularProgressIndicator(color: colors.intenseColor))),
                 ),
              ]
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(lang.t('close'), style: TextStyle(color: colors.textColor)))],
      ),
    );
  }

  static void showEntriesList(BuildContext context, List<DiaryEntryModel> entries) {
    final lang = context.read<LanguageNotifier>();
    final colors = context.colors;
    final dateStr = '${entries.first.createdAt.year}-${entries.first.createdAt.month.toString().padLeft(2, '0')}-${entries.first.createdAt.day.toString().padLeft(2, '0')}';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.background2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.appBarUnpickedColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2))))),
            Text(dateStr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textColor)),
            const SizedBox(height: 16),
            ...entries.map((e) => ListTile(
              leading: e.moodImage != null && e.moodImage!.isNotEmpty
                  ? Image.asset(e.moodImage!, width: 32, height: 32)
                  : Text(e.mood.split(' ')[0], style: const TextStyle(fontSize: 24)),              title: Text('${e.createdAt.hour}:${e.createdAt.minute.toString().padLeft(2, '0')}', style: TextStyle(color: colors.textColor)),
              subtitle: Text(_previewText(e, lang), maxLines: 1, style: TextStyle(color: colors.appBarUnpickedColor)),
              onTap: () { Navigator.pop(context); showEntryDialog(context, e); },
            )),
          ],
        ),
      ),
    );
  }
}