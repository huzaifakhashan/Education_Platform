import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/course.dart';
import '../widgets/app_scope.dart';

class LessonPlayerScreen extends StatefulWidget {
  const LessonPlayerScreen({super.key, required this.course, required this.index});

  final Course course;
  final int index;

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;
  bool _autoMarked = false;

  Lesson get lesson => widget.course.lessons[widget.index];

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(lesson.videoUrl))
      ..addListener(_onTick);
    _controller.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppScope.of(context).progress.markVisited(lesson.id);
  }

  void _onTick() {
    final v = _controller.value;
    if (!_autoMarked && v.isInitialized && v.duration > Duration.zero) {
      // Consider the lesson complete once 95% has been watched.
      if (v.position.inMilliseconds >= v.duration.inMilliseconds * 0.95) {
        _autoMarked = true;
        AppScope.of(context).progress.setDone(lesson.id, true);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _goTo(int index) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LessonPlayerScreen(course: widget.course, index: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    final theme = Theme.of(context);
    final hasNext = widget.index < widget.course.lessons.length - 1;
    final hasPrev = widget.index > 0;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            children: [
              AspectRatio(aspectRatio: 16 / 9, child: _buildVideo()),
              if (_ready) _buildControls(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(lesson.description, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    ListenableBuilder(
                      listenable: progress,
                      builder: (_, _) {
                        final done = progress.isDone(lesson.id);
                        return FilledButton.icon(
                          style: done
                              ? FilledButton.styleFrom(backgroundColor: Colors.green)
                              : null,
                          onPressed: () => progress.setDone(lesson.id, !done),
                          icon: Icon(done ? Icons.check_circle : Icons.check_circle_outline),
                          label: Text(done ? 'تم إكمال الدرس' : 'تعليم كمكتمل'),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: hasPrev ? () => _goTo(widget.index - 1) : null,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('السابق'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: hasNext ? () => _goTo(widget.index + 1) : null,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('التالي'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_failed) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('تعذّر تشغيل الفيديو. تحقق من الاتصال بالإنترنت.',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    if (!_ready) {
      return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()));
    }
    return GestureDetector(
      onTap: () => _controller.value.isPlaying ? _controller.pause() : _controller.play(),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            if (!_controller.value.isPlaying)
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.black54,
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final v = _controller.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            IconButton(
              icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () => v.isPlaying ? _controller.pause() : _controller.play(),
            ),
            Text(_fmt(v.position)),
            Expanded(
              child: Slider(
                value: v.position.inMilliseconds.clamp(0, v.duration.inMilliseconds).toDouble(),
                max: v.duration.inMilliseconds.toDouble(),
                onChanged: (x) => _controller.seekTo(Duration(milliseconds: x.round())),
              ),
            ),
            Text(_fmt(v.duration)),
          ],
        ),
      ),
    );
  }
}
