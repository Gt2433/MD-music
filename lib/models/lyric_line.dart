/// Represents a single line in timed synchronized lyrics.
class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({
    required this.time,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'timeMs': time.inMilliseconds,
        'text': text,
      };

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
        time: Duration(milliseconds: json['timeMs'] as int? ?? 0),
        text: json['text'] as String? ?? '',
      );
}

/// Represents the full lyrics of a song (synced or plain).
class SongLyrics {
  final int songId;
  final String title;
  final String artist;
  final List<LyricLine> lines;
  final String plainLyrics;
  final bool isSynced;
  final String source; // 'local_lrc', 'cached', 'online_lrclib', 'manual'

  const SongLyrics({
    required this.songId,
    required this.title,
    required this.artist,
    required this.lines,
    required this.plainLyrics,
    required this.isSynced,
    required this.source,
  });

  bool get isEmpty => lines.isEmpty && plainLyrics.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Parses standard .lrc format into structured SongLyrics.
  static SongLyrics fromLrc({
    required int songId,
    required String title,
    required String artist,
    required String lrcContent,
    String source = 'online_lrclib',
  }) {
    final List<LyricLine> parsedLines = [];
    final List<String> rawLines = lrcContent.split(RegExp(r'\r?\n'));
    final RegExp timeTagRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');

    final StringBuffer plainTextBuffer = StringBuffer();

    for (final line in rawLines) {
      final matches = timeTagRegex.allMatches(line).toList();
      if (matches.isEmpty) {
        final trimmed = line.trim();
        // Skip metadata header tags like [ti:], [ar:], [al:], [by:], [offset:]
        if (!trimmed.startsWith('[') && trimmed.isNotEmpty) {
          plainTextBuffer.writeln(trimmed);
        }
        continue;
      }

      // Extract text content after all time tags
      final text = line.replaceAll(timeTagRegex, '').trim();
      plainTextBuffer.writeln(text);

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final millisStr = match.group(3) ?? '0';
        int milliseconds = 0;
        if (millisStr.length == 1) {
          milliseconds = (int.tryParse(millisStr) ?? 0) * 100;
        } else if (millisStr.length == 2) {
          milliseconds = (int.tryParse(millisStr) ?? 0) * 10;
        } else {
          milliseconds = int.tryParse(millisStr) ?? 0;
        }

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        parsedLines.add(LyricLine(time: duration, text: text));
      }
    }

    // Sort chronologically
    parsedLines.sort((a, b) => a.time.compareTo(b.time));

    // Filter out completely empty duplicate lines at the very beginning
    final bool hasSynced = parsedLines.isNotEmpty;

    return SongLyrics(
      songId: songId,
      title: title,
      artist: artist,
      lines: parsedLines,
      plainLyrics: plainTextBuffer.toString().trim(),
      isSynced: hasSynced,
      source: source,
    );
  }

  /// Parses plain un-synced text into SongLyrics.
  static SongLyrics fromPlain({
    required int songId,
    required String title,
    required String artist,
    required String plainText,
    String source = 'manual',
  }) {
    final clean = plainText.trim();
    final lines = clean
        .split(RegExp(r'\r?\n'))
        .map((l) => LyricLine(time: Duration.zero, text: l.trim()))
        .toList();

    return SongLyrics(
      songId: songId,
      title: title,
      artist: artist,
      lines: lines,
      plainLyrics: clean,
      isSynced: false,
      source: source,
    );
  }

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'title': title,
        'artist': artist,
        'isSynced': isSynced,
        'source': source,
        'plainLyrics': plainLyrics,
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  factory SongLyrics.fromJson(Map<String, dynamic> json) {
    final linesList = (json['lines'] as List<dynamic>?)
            ?.map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return SongLyrics(
      songId: json['songId'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      isSynced: json['isSynced'] as bool? ?? false,
      source: json['source'] as String? ?? 'cached',
      plainLyrics: json['plainLyrics'] as String? ?? '',
      lines: linesList,
    );
  }
}
