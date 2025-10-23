// lib/widgets/lang_builder.dart
import 'package:flutter/material.dart';
import '../services/language_service.dart';

class LangBuilder extends StatelessWidget {
  final Widget Function(BuildContext, LanguageService) builder;
  const LangBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final L = LanguageService.instance;
    return ValueListenableBuilder<String>(
      valueListenable: L.langCode,
      builder: (_, __, ___) => builder(context, L),
    );
  }
}
