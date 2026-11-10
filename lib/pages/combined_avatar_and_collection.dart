import 'package:flutter/material.dart';
import 'package:well_being_app/pages/avatar.dart';
import 'package:well_being_app/pages/minigames.dart';
import '../widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/language_notifier.dart';

class CombinedAvatarAndCollectionPage extends StatelessWidget {
  final String userId;

  const CombinedAvatarAndCollectionPage({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,

      appBar: CustomAppBar(title: context.watch<LanguageNotifier>().t('nav_avatar')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.transparent,
              child: AvatarPage(userId: userId),
            ),

            const SizedBox(height: 20),

            SizedBox(
              child: CollectionPage(userId: userId),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}