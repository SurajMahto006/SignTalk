import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/isl/text_to_sign_reference.dart';
import '../../theme/sign_talk_colors.dart';

class LearnIslScreen extends StatefulWidget {
  const LearnIslScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<LearnIslScreen> createState() => _LearnIslScreenState();
}

class _LearnIslScreenState extends State<LearnIslScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final favorites = SignTalkScope.of(context).favoriteSigns;
    final steps = TextToSignReference.filterSteps(
      TextToSignReference.learnSteps(),
      _query,
    );
    final ordered = [
      ...steps.where((step) => favorites.isFavorite(step.label)),
      ...steps.where((step) => !favorites.isFavorite(step.label)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to Home',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_ios_new),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learn ISL',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Star a word to keep it at the top.',
                      style: TextStyle(
                        fontSize: 14,
                        color: SignTalkColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Search signs',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ordered.isEmpty
              ? const Center(
                  child: Text(
                    'No sign matches that search.',
                    style: TextStyle(color: SignTalkColors.secondaryText),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: ordered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final step = ordered[index];
                    final starred = favorites.isFavorite(step.label);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: SignTalkColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SignTalkColors.border),
                      ),
                      child: ListTile(
                        title: Text(
                          step.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(step.detail),
                        trailing: IconButton(
                          tooltip: starred ? 'Remove star' : 'Star this sign',
                          onPressed: () => unawaited(favorites.toggle(step.label)),
                          icon: Icon(
                            starred ? Icons.star_rounded : Icons.star_border_rounded,
                            color: SignTalkColors.primaryBlue,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
