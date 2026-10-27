import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/isl/sign_video_catalog.dart';
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
  String? _word;
  int _clipIndex = 0;
  VideoPlayerController? _player;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SignVideoCatalog.words.isNotEmpty) {
        unawaited(_open(SignVideoCatalog.words.first, 0));
      }
    });
  }

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _open(String word, int clipIndex) async {
    final clips = SignVideoCatalog.clips[word];
    if (clips == null || clips.isEmpty) return;
    final index = clipIndex.clamp(0, clips.length - 1);
    final previous = _player;
    _player = null;
    await previous?.dispose();
    final next = VideoPlayerController.asset(clips[index]);
    _player = next;
    if (mounted) {
      setState(() {
        _word = word;
        _clipIndex = index;
        _ready = false;
        _error = null;
      });
    }
    try {
      await next.initialize();
      await next.play();
      if (mounted && identical(_player, next)) {
        setState(() => _ready = true);
      }
    } catch (_) {
      if (mounted && identical(_player, next)) {
        setState(() => _error = 'This clip could not be opened.');
      }
    }
  }

  Future<void> _restart() async {
    final player = _player;
    if (player == null || !_ready) return;
    await player.seekTo(Duration.zero);
    await player.play();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = SignTalkScope.of(context).favoriteSigns;
    final needle = _query.trim().toLowerCase();
    final videoWords = [
      for (final word in SignVideoCatalog.words)
        if (needle.isEmpty || word.contains(needle)) word,
    ];
    final glossary = TextToSignReference.filterSteps(
      TextToSignReference.learnSteps(),
      _query,
    ).where((step) => !SignVideoCatalog.clips.containsKey(step.label.toLowerCase()));
    final clips = _word == null ? const <String>[] : SignVideoCatalog.clips[_word] ?? const <String>[];

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
                      'Tap a letter or number to watch its sign. Restart plays the same clip again.',
                      style: TextStyle(
                        fontSize: 13,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _SignPlayer(
            word: _word,
            clipIndex: _clipIndex,
            clipCount: clips.length,
            asset: clips.isEmpty ? null : clips[_clipIndex],
            player: _player,
            ready: _ready,
            error: _error,
            onRestart: () => unawaited(_restart()),
            onPrevious: _clipIndex > 0 && _word != null
                ? () => unawaited(_open(_word!, _clipIndex - 1))
                : null,
            onNext: _word != null && _clipIndex + 1 < clips.length
                ? () => unawaited(_open(_word!, _clipIndex + 1))
                : null,
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
          child: videoWords.isEmpty && glossary.isEmpty
              ? const Center(
                  child: Text(
                    'No sign matches that search.',
                    style: TextStyle(color: SignTalkColors.secondaryText),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    if (videoWords.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Letters and numbers',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    for (final word in videoWords) ...[
                      _WordTile(
                        title: word.toUpperCase(),
                        subtitle:
                            '${SignVideoCatalog.clips[word]!.length} sign clips',
                        selected: word == _word,
                        starred: favorites.isFavorite(word),
                        onTap: () => unawaited(_open(word, 0)),
                        onStar: () => unawaited(favorites.toggle(word)),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (glossary.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                          'Other words',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      for (final step in glossary) ...[
                        _WordTile(
                          title: step.label,
                          subtitle: step.detail,
                          selected: false,
                          starred: favorites.isFavorite(step.label),
                          onStar: () => unawaited(favorites.toggle(step.label)),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SignPlayer extends StatelessWidget {
  const _SignPlayer({
    required this.word,
    required this.clipIndex,
    required this.clipCount,
    required this.asset,
    required this.player,
    required this.ready,
    required this.error,
    required this.onRestart,
    required this.onPrevious,
    required this.onNext,
  });

  final String? word;
  final int clipIndex;
  final int clipCount;
  final String? asset;
  final VideoPlayerController? player;
  final bool ready;
  final String? error;
  final VoidCallback onRestart;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final split = asset != null && asset!.contains('/test_') ? 'Test' : 'Train';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: ready && player != null && player!.value.aspectRatio > 0
                  ? player!.value.aspectRatio
                  : 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: Colors.black,
                  child: error != null
                      ? Center(
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        )
                      : ready && player != null
                          ? VideoPlayer(player!)
                          : const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              word == null
                  ? 'Choose a sign'
                  : '${word!.toUpperCase()} · $split clip ${clipIndex + 1} of $clipCount',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: onPrevious,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Previous'),
                ),
                TextButton(
                  onPressed: ready ? onRestart : null,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Restart'),
                ),
                TextButton(
                  onPressed: onNext,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.starred,
    required this.onStar,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool starred;
  final VoidCallback onStar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? SignTalkColors.primaryBlue : SignTalkColors.border,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: starred ? 'Remove star' : 'Star this sign',
          onPressed: onStar,
          icon: Icon(
            starred ? Icons.star_rounded : Icons.star_border_rounded,
            color: SignTalkColors.primaryBlue,
          ),
        ),
      ),
    );
  }
}
