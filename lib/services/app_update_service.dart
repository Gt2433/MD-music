import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import 'language_service.dart';

class AppReleaseInfo {
  final String tagName;
  final String versionName;
  final String title;
  final String releaseNotes;
  final String apkDownloadUrl;
  final int? apkSize;
  final String apkFileName;
  final DateTime? publishedAt;

  AppReleaseInfo({
    required this.tagName,
    required this.versionName,
    required this.title,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    this.apkSize,
    required this.apkFileName,
    this.publishedAt,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name']?.toString() ?? '';
    final versionName = tagName.replaceAll(RegExp(r'^[vV]'), '').trim();
    final title = json['name']?.toString() ?? 'MD Music $tagName';
    final releaseNotes = json['body']?.toString() ?? '';
    final publishedStr = json['published_at']?.toString();
    final publishedAt =
        publishedStr != null ? DateTime.tryParse(publishedStr) : null;

    String apkUrl = '';
    int? apkSize;
    String apkFileName = 'MD_Music_$versionName.apk';

    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = asset['name']?.toString().toLowerCase() ?? '';
        final url = asset['browser_download_url']?.toString() ?? '';
        if (name.endsWith('.apk') || url.endsWith('.apk')) {
          apkUrl = url;
          apkFileName = asset['name']?.toString() ?? apkFileName;
          apkSize = (asset['size'] as num?)?.toInt();
          break;
        }
      }
    }

    return AppReleaseInfo(
      tagName: tagName,
      versionName: versionName,
      title: title,
      releaseNotes: releaseNotes,
      apkDownloadUrl: apkUrl,
      apkSize: apkSize,
      apkFileName: apkFileName,
      publishedAt: publishedAt,
    );
  }
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  static const String githubOwner = 'Gt2433';
  static const String githubRepo = 'MD-music';
  static const String releasesApiUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'MD-Music-App',
      },
    ),
  );

  /// Checks if a newer version is available on GitHub Releases
  Future<AppReleaseInfo?> checkForUpdate() async {
    try {
      final response = await _dio.get(releasesApiUrl);
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final release = AppReleaseInfo.fromJson(response.data);
        if (release.apkDownloadUrl.isEmpty) {
          // No APK attached to the latest release
          return null;
        }

        final packageInfo = await PackageInfo.fromPlatform();
        var currentVersion = packageInfo.version;
        if (currentVersion == '1.0.0' || currentVersion == '1.1.0' || currentVersion.isEmpty) {
          currentVersion = '2.0.0';
        }

        if (_isVersionNewer(currentVersion, release.versionName)) {
          return release;
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }

  /// Compares two semver strings (e.g. "1.0.0" and "1.0.1")
  bool _isVersionNewer(String current, String remote) {
    try {
      final currParts = current
          .split('+')[0]
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final remoteParts = remote
          .split('+')[0]
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();

      while (currParts.length < 3) {
        currParts.add(0);
      }
      while (remoteParts.length < 3) {
        remoteParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (remoteParts[i] > currParts[i]) return true;
        if (remoteParts[i] < currParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Format bytes to human readable string (e.g. 15.4 MB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Shows the update bottom sheet dialog
  static Future<void> showUpdateDialog(
    BuildContext context,
    AppReleaseInfo release, {
    String currentVersion = '2.0.0',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => _UpdateDialogSheet(
        release: release,
        currentVersion: currentVersion,
      ),
    );
  }
}

class _UpdateDialogSheet extends StatefulWidget {
  final AppReleaseInfo release;
  final String currentVersion;

  const _UpdateDialogSheet({
    required this.release,
    required this.currentVersion,
  });

  @override
  State<_UpdateDialogSheet> createState() => _UpdateDialogSheetState();
}

enum _DownloadState { idle, downloading, completed, error }

class _UpdateDialogSheetState extends State<_UpdateDialogSheet> {
  _DownloadState _state = _DownloadState.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String _errorMessage = '';
  String? _downloadedApkPath;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _checkExistingDownload();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('User closed update dialog');
    super.dispose();
  }

  Future<String> _resolveSavePath() async {
    try {
      final extDirs = await getExternalCacheDirectories();
      if (extDirs != null && extDirs.isNotEmpty) {
        return '${extDirs.first.path}/${widget.release.apkFileName}';
      }
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        return '${extDir.path}/${widget.release.apkFileName}';
      }
    } catch (_) {}
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/${widget.release.apkFileName}';
  }

  Future<void> _checkExistingDownload() async {
    try {
      final path = await _resolveSavePath();
      final file = File(path);
      if (await file.exists()) {
        final length = await file.length();
        if (length > 10 * 1024 * 1024) {
          if (mounted) {
            setState(() {
              _downloadedApkPath = path;
              _state = _DownloadState.completed;
              _progress = 1.0;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = _DownloadState.downloading;
      _progress = 0.0;
      _errorMessage = '';
    });

    try {
      final savePath = await _resolveSavePath();
      final file = File(savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      _cancelToken = CancelToken();
      final dio = Dio();

      await dio.download(
        widget.release.apkDownloadUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() {
              _progress = received / total;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _downloadedApkPath = savePath;
          _state = _DownloadState.completed;
          _progress = 1.0;
        });

        // Trigger installer immediately upon download completion
        await _installApk();
      }
    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) return;
      if (mounted) {
        setState(() {
          _state = _DownloadState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _installApk() async {
    final path = _downloadedApkPath;
    if (path == null) {
      await _startDownload();
      return;
    }

    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await _startDownload();
      return;
    }

    // 1. Native Android installer via MethodChannel
    try {
      const channel = MethodChannel('com.mbd.music/artwork');
      final result = await channel.invokeMethod<String>('installApk', {'path': path});

      if (result == 'PERMISSION_REQUIRED') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LanguageService().t('allow_install_unknown_sources')),
              duration: const Duration(seconds: 5),
              backgroundColor: AppTheme.surface,
            ),
          );
        }
        return;
      }

      if (result == 'SUCCESS') {
        return;
      }
    } catch (_) {}

    // 2. Fallback via OpenFilex
    try {
      final openResult = await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );

      if (openResult.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageService()
                  .t('update_downloaded_in')
                  .replaceAll('{path}', path),
            ),
            backgroundColor: AppTheme.surface,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentColor;

    return Directionality(
      textDirection: LanguageService().textDirection,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header Icon & Title
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageService().t('new_update_available'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v${widget.release.versionName}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            LanguageService()
                                .t('current_version_label')
                                .replaceAll('{version}', widget.currentVersion),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Release Notes Card
            if (widget.release.releaseNotes.trim().isNotEmpty) ...[
              Text(
                LanguageService().t('whats_new_in_update'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.background.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    widget.release.releaseNotes.trim(),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.textPrimary.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Download Status / Progress Area
            if (_state == _DownloadState.downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 8,
                  backgroundColor: AppTheme.background,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  if (_totalBytes > 0)
                    Text(
                      '${AppUpdateService.formatBytes(_receivedBytes)} / ${AppUpdateService.formatBytes(_totalBytes)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            if (_state == _DownloadState.error) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage.isNotEmpty
                      ? _errorMessage
                      : LanguageService().t('update_error_connection'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Action Buttons
            if (_state == _DownloadState.idle || _state == _DownloadState.error) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _startDownload,
                icon: const Icon(Icons.cloud_download_rounded, size: 20),
                label: Text(
                  LanguageService().t('download_install_now'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  LanguageService().t('remind_me_later'),
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ] else if (_state == _DownloadState.downloading) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.errorColor.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  _cancelToken?.cancel();
                  setState(() => _state = _DownloadState.idle);
                },
                child: Text(
                  LanguageService().t('cancel_download'),
                  style: TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else if (_state == _DownloadState.completed) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _installApk,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        LanguageService().t('open_installer'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.cardBorder, width: 1),
                    ),
                    child: IconButton(
                      tooltip: LanguageService().t('redownload_update'),
                      icon: Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
                      onPressed: _startDownload,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
