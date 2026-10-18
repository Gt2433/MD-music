import 'dart:ui';
import 'package:flutter/material.dart';
import 'settings_repository.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static const String arabic = 'ar';
  static const String english = 'en';
  static const String french = 'fr';
  static const String system = 'system';

  final ValueNotifier<String> currentLanguage = ValueNotifier<String>('system');

  bool get isArabic => activeLanguageCode == 'ar';
  bool get isEnglish => activeLanguageCode == 'en';
  bool get isFrench => activeLanguageCode == 'fr';

  String get activeLanguageCode {
    if (currentLanguage.value == 'system') {
      final code =
          PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      if (code == 'ar') return 'ar';
      if (code == 'fr') return 'fr';
      return 'en';
    }
    return currentLanguage.value;
  }

  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  Locale get currentLocale => Locale(activeLanguageCode);

  String get languageDisplayName {
    switch (currentLanguage.value) {
      case 'system':
        return t('language_system');
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      case 'ar':
      default:
        return 'العربية';
    }
  }

  void init() {
    final repo = SettingsRepository();
    currentLanguage.value = repo.language;
    repo.onSettingChanged.listen((key) {
      if (key == SettingsRepository.keyLanguage || key == 'reset') {
        currentLanguage.value = repo.language;
      }
    });
  }

  Future<void> setLanguage(String lang) async {
    if (['system', 'ar', 'en', 'fr'].contains(lang)) {
      currentLanguage.value = lang;
      await SettingsRepository().setLanguage(lang);
    }
  }

  static String tr(String key) => _instance.t(key);

  String t(String key) {
    final code = activeLanguageCode;
    return _translations[code]?[key] ??
        _translations['en']?[key] ??
        _translations['ar']?[key] ??
        key;
  }

  static String formatSongCount(int count) => _instance.songsCountString(count);

  String songsCountString(int count) {
    final code = activeLanguageCode;
    if (code == 'fr') {
      if (count == 0) return 'Aucun morceau';
      if (count == 1) return '1 morceau';
      return '$count morceaux';
    } else if (code == 'ar') {
      if (count == 0) return 'لا توجد أغانٍ';
      if (count == 1) return 'أغنية واحدة';
      if (count == 2) return '٢ أغنيتان';
      if (count >= 3 && count <= 10) return '$count أغانٍ';
      return '$count أغنية';
    } else {
      if (count == 0) return 'No songs';
      if (count == 1) return '1 song';
      return '$count songs';
    }
  }

  static const Map<String, Map<String, String>> _translations = {
    // =========================================================
    // ARABIC (العربية)
    // =========================================================
    'ar': {
      // Common & Navigation
      'settings': 'الإعدادات',
      'close': 'إغلاق',
      'cancel': 'إلغاء',
      'ok': 'موافق',
      'reset': 'إعادة تعيين',
      'save': 'حفظ',
      'remove': 'إزالة',
      'add': 'إضافة',
      'undo': 'تراجع',
      'all': 'الكل',
      'songs': 'الأغاني',
      'albums': 'الألبومات',
      'artists': 'الفنانون',
      'playlists': 'قوائم التشغيل',
      'favorites': 'المفضلة',
      'search': 'بحث',
      'search_hint': 'ابحث عن أغنية أو فنان أو ألبوم...',
      'all_songs': 'جميع الأغاني',
      'songs_list': 'قائمة الأغاني',
      'play_all': 'تشغيل الكل',
      'shuffle_all': 'عشوائي',
      'now_playing': 'قيد التشغيل',
      'no_songs': 'لا توجد أغانٍ',
      'no_favorites': 'لا توجد أغانٍ مفضلة بعد',
      'edit': 'تعديل',
      'delete': 'حذف',
      'success': 'نجاح',
      'error': 'خطأ',
      'unknown': 'غير معروف',
      'unknown_artist': 'فنان غير معروف',
      'unknown_album': 'ألبوم غير معروف',
      'mb': 'ميغابايت',
      'details': 'معلومات الأغنية',
      'queue': 'قائمة الانتظار',
      'play': 'تشغيل',
      'shuffle': 'عشوائي',
      'back': 'رجوع',

      // Song Actions & Details
      'play_now': 'تشغيل الآن',
      'add_to_favorites': 'إضافة إلى المفضلة',
      'remove_from_favorites': 'إزالة من المفضلة',
      'favorite_badge': 'مفضلة',
      'trim_and_edit': 'تعديل اسم الأغنية والفنان',
      'edit_song_info': 'تعديل اسم الأغنية والفنان',
      'set_as_ringtone': 'تعيين كنغمة رنين للهاتف',
      'setting_ringtone': 'جارِ تعيين الأغنية كنغمة رنين...',
      'ringtone_success': 'تم تعيين الأغنية كنغمة رنين بنجاح 🔔',
      'ringtone_permission': 'يرجى تفعيل صلاحية تعديل إعدادات النظام لتعيين نغمة الرنين',
      'ringtone_error': 'تعذر تعيين نغمة الرنين',
      'retry': 'إعادة المحاولة',
      'add_to_custom_album': 'إضافة إلى ألبوم خاص',
      'song_details': 'معلومات وتفاصيل الملف',
      'delete_permanently': 'حذف نهائياً من الهاتف',
      'delete_song_title': 'حذف الأغنية',
      'delete_song_confirm': 'هل أنت متأكد من حذف أغنية "{title}" نهائياً؟',
      'delete_song_success': 'تم حذف الأغنية بنجاح 🗑️',
      'delete_song_error': 'تعذر حذف الأغنية',
      'detail_title': 'العنوان',
      'detail_artist': 'الفنان',
      'detail_album': 'الألبوم',
      'detail_duration': 'المدة',
      'detail_size': 'الحجم',

      // Custom Albums
      'custom_albums': 'الألبومات الخاصة',
      'create_new_album': 'إنشاء ألبوم جديد',
      'album_name_hint': 'اسم الألبوم...',
      'create_and_add': 'إنشاء وإضافة',
      'create_album_and_add_song': 'إنشاء ألبوم جديد وإضافة الأغنية إليه',
      'no_custom_albums_yet': 'لا توجد ألبومات خاصة بعد.\nاضغط على الزر أعلاه لإنشاء ألبومك الأول!',
      'no_albums_yet': 'لا توجد ألبومات بعد',
      'create_album_prompt': 'أنشئ ألبوماتك الخاصة وخصص لها غلافاً وأغانٍ تعجبك.',
      'added_to_album': 'تمت إضافة "{title}" إلى "{album}"',
      'removed_from_album': 'تمت إزالة "{title}" من "{album}"',
      'album_created_and_song_added': 'تم إنشاء ألبوم "{album}" وإضافة "{title}" إليه',
      'added_badge': 'مضافة',
      'add_badge': 'إضافة',
      'songs_count': '{count} أغنية',
      'album_options': 'خيارات الألبوم',
      'change_album_cover': 'تغيير غلاف الألبوم',
      'change_cover_subtitle': 'اختيار صورة جديدة من المعرض',
      'rename_album': 'تغيير اسم الألبوم',
      'rename_album_subtitle': 'تعديل عنوان الألبوم الحالي',
      'add_music_to_album': 'إضافة موسيقى للألبوم',
      'add_music_subtitle': 'اختيار وتحديد الأغاني للألبوم',
      'reorder_songs': 'تغيير ترتيب الأغاني',
      'reorder_songs_subtitle': 'سحب وإفلات لإعادة ترتيب القائمة',
      'delete_album': 'حذف الألبوم',
      'delete_album_confirm': 'هل أنت متأكد من حذف ألبوم "{album}"؟ لن يتم حذف أي أغنية من ذاكرة هاتفك.',
      'album_empty': 'هذا الألبوم فارغ حالياً',
      'album_empty_desc': 'قم باختيار الأغاني التي ترغب بإضافتها لهذا الألبوم بنقرة واحدة.',
      'add_songs_now': 'إضافة أغانٍ الآن',
      'album_cover_updated': 'تم تحديث غلاف الألبوم بنجاح ✨',
      'album_cover_error': 'تعذر تغيير غلاف الألبوم',
      'edit_album_name': 'تعديل اسم الألبوم',
      'save_order': 'حفظ الترتيب الجديد',
      'order_saved': 'تم حفظ ترتيب الأغاني بنجاح 🎶',
      'reorder_instructions': 'اضغط مطولاً واسحب لتغيير ترتيب الأغاني ↕️',
      'no_songs_in_album_to_reorder': 'لا توجد أغانٍ في الألبوم لإعادة ترتيبها',
      'add_songs_to_album': 'إضافة أغانٍ إلى "{album}"',
      'selected_songs_count': 'تم تحديد {selected} من أصل {total} أغنية',
      'select_all': 'تحديد الكل',
      'deselect_all': 'إلغاء الكل',
      'save_changes': 'حفظ التغييرات',
      'songs_saved_in_album': 'تم حفظ الأغاني في "{album}" ({count} أغنية)',
      'create_first_album_now': 'إنشاء ألبومك الأول الآن',
      'type_album_name': 'اكتب اسم الألبوم...',
      'shuffle_all_play': 'تشغيل الكل عشوائياً',
      'play_album': 'تشغيل',
      'remove_from_this_album': 'إزالة من هذا الألبوم',
      'song_removed_from_album_msg': 'تمت إزالة "{title}" من هذا الألبوم',

      // Speed & Pitch
      'speed_pitch': 'السرعة والنبرة',
      'speed_normal': 'طبيعي',
      'speed_fast': 'تسريع',
      'speed_slow': 'سلو',
      'link_pitch_speed': 'ضبط نبرة الصوت مع السرعة',
      'pitch_changes_with_speed': 'النبرة تتغير مع السرعة',
      'pitch_fixed': 'النبرة ثابتة',
      'reset_speed': 'استعادة',

      // Song Edit & Trim
      'basic_info': 'المعلومات الأساسية',
      'song_title_label': 'اسم الأغنية / الموسيقى',
      'song_title_hint': 'أدخل عنوان الأغنية',
      'artist_name_label': 'اسم الفنان / المغني',
      'artist_name_hint': 'أدخل اسم الفنان',
      'select_artist_title': 'اختيار أو إضافة فنان',
      'search_artist_placeholder': 'ابحث عن مغني أو فنان...',
      'create_artist_btn': 'إنشاء الفنان وحفظه',
      'create_artist_prefix': 'إضافة فنان جديد باسم:',
      'registered_artists': 'الفنانون الموجودون',
      'no_artist_found': 'لم يتم العثور على فنان بهذا الاسم، يمكنك إنشاؤه وحفظه الآن',
      'artist_created_success': 'تم إنشاء وحفظ الفنان بنجاح ✨',
      'waveform_instructions': 'اسحب طرفي الأمواج لتحديد بداية ونهاية المقطع المقصوص',
      'trim_section_title': 'قص وتحديد المقطع',
      'trim_start': 'البداية',
      'trim_end': 'النهاية',
      'clip_duration': 'مدة المقطع',
      'preview_trim': 'معاينة المقطع المقصوص',
      'stop_preview': 'إيقاف المعاينة',
      'saving_trim': 'جارِ الحفظ والقص...',
      'save_edits': 'حفظ التعديلات',
      'revert_to_original': 'إرجاع للنسخة الأصلية',
      'revert_dialog_title': 'استعادة النسخة الأصلية',
      'revert_dialog_desc': 'هل أنت متأكد من إلغاء كافة التعديلات واستعادة المقطع الأصلي بالكامل بدون أي قص وباسمائه الأصلية؟',
      'revert_confirm_btn': 'نعم، استعادة الأصلية',
      'revert_success': 'تمت استعادة الأغنية الأصلية بنجاح 🔄',
      'revert_error': 'تعذر استعادة النسخة الأصلية',
      'save_edits_success': 'تم حفظ التعديلات بنجاح ✨',
      'save_edits_error': 'حدث خطأ أثناء حفظ التعديلات',
      'change_cover_gallery': 'تغيير صورة الغلاف من المعرض',
      'pick_image_error': 'تعذر اختيار الصورة',

      // Playlists Screen
      'new_playlist': 'قائمة تشغيل جديدة',
      'playlist_name': 'اسم قائمة التشغيل...',
      'recent_songs': 'الأغاني الأخيرة',
      'recent_songs_sub': '{count} أغنية تم تشغيلها',
      'phone_library': 'مكتبة الهاتف الكاملة',
      'phone_library_sub': '{count} ملف محلي',
      'create_custom_playlist': 'إنشاء قائمة تشغيل مخصصة',
      'playlist_created_success': 'تم إنشاء القائمة "{name}" بنجاح',
      'no_songs_in_playlist': 'لا توجد أغانٍ في {name}',
      'saved_songs_count': '{count} أغنية محفوظة',
      'favorites_title': 'الأغاني المفضلة',

      // Favorites Screen
      'no_favorites_title': 'لا توجد أغانٍ مفضلة بعد',
      'no_favorites_hint': 'انقر على أيقونة القلب بجانب أي أغنية لتجدها محفوظة هنا للوصول السريع.',

      // Songs Screen
      'sort_date_added': 'الأحدث إضافة',
      'sort_name': 'الاسم أبجدياً',
      'sort_artist': 'اسم الفنان',
      'sort_duration': 'المدة الزمنية',
      'no_local_songs': 'لا توجد أغانٍ محلية على الهاتف',
      'scan_device': 'فحص الجهاز',

      // Onboarding Screen
      'skip': 'تخطي',
      'onboarding_subtitle': 'مشغّل الموسيقى المحلي لهاتفك',
      'offline_feature_title': 'تشغيل محلي بالكامل',
      'offline_feature_desc': 'استمع إلى أغانيك المحفوظة بدون الحاجة لأي اتصال بالإنترنت.',
      'auto_discovery_title': 'اكتشاف تلقائي للملفات',
      'auto_discovery_desc': 'يتعرف التطبيق فوراً على المقاطع الصوتية الجديدة التي تحمّلها.',
      'design_feature_title': 'تصميم فخم وهوية MBD',
      'design_feature_desc': 'تجربة داكنة بلمسات خضراء نيونية مريحة للعين وعالية الأداء.',
      'next': 'التالي',
      'partnership_badge': 'شراكة التطوير والهوية',
      'contract_partnership': 'تعاقد وشراكة',
      'mbd_project_label': 'من مشاريع MBD',
      'connect_developer': 'تواصل مع المطور ومتابعة المشاريع',
      'enter_app_start_listening': 'دخول التطبيق وبدء الاستماع',

      // Appearance
      'appearance': 'المظهر',
      'language': 'اللغة',
      'language_desc': 'تغيير لغة واجهة التطبيق',
      'language_system': 'حسب لغة النظام (System)',
      'theme_mode': 'وضع المظهر',
      'theme_system': 'حسب النظام (System)',
      'theme_light': 'فاتح (Light)',
      'theme_dark': 'داكن (Dark)',
      'accent_color': 'لون التمييز',
      'accent_color_desc': 'اختر لون التطبيق والأزرار التفاعلية',
      'select_accent_color': 'اختر لون التطبيق',
      'live_preview': 'معاينة حية للمظهر',
      'apply_color': 'تطبيق هذا اللون',
      'sample_song_title': 'أغنية تجريبية للمعاينة',
      'sample_song_artist': 'اسم الفنان • ألبوم الموسيقى',
      'color_applied': 'تم تطبيق لون التطبيق بنجاح',
      'amoled_black': 'وضع الأسود الفاحم (AMOLED)',
      'amoled_black_desc': 'خلفيات سوداء نقية 100% لشاشات أوليد وتوفير البطارية',
      'amoled_dark_only': 'متاح فقط في الوضع الداكن',

      // Custom Background System
      'custom_bg': 'خلفية التطبيق',
      'custom_bg_color': 'لون خلفية مخصص',
      'custom_bg_color_desc': 'اختر أي لون تريده لخلفية التطبيق بالكامل',
      'custom_bg_image': 'صورة خلفية من المعرض',
      'custom_bg_image_desc': 'تعيين صورة من هاتفك كخلفية مع تحكم بالتمويه والشفافية والتكبير',
      'bg_image_active': 'صورة مخصصة مفعّلة',
      'bg_image_none': 'استخدام لون الثيم',
      'edit_bg_image': 'تعديل صورة الخلفية والتأثيرات',
      'remove_custom_bg': 'إزالة الخلفية المخصصة',
      'remove_custom_bg_confirm': 'هل تريد إزالة الخلفية المخصصة والعودة لمظهر الثيم الافتراضي؟',
      'custom_bg_removed': 'تمت استعادة الخلفية الافتراضية بنجاح',
      'bg_editor_title': 'معاينة وضبط الخلفية',
      'bg_blur_slider': 'درجة التمويه (Blur)',
      'bg_blur_none': 'بدون تمويه',
      'bg_blur_max': 'تمويه قوي',
      'bg_opacity_slider': 'الشفافية والظهور (Transparency)',
      'bg_opacity_hint': 'تخفيف الظهور لإظهار اللون الخلفي وتوضيح النصوص',
      'save_background': 'حفظ وتطبيق الخلفية',
      'saving_background': 'جارِ حفظ الخلفية وتطبيقها...',
      'background_applied_success': 'تم تطبيق الخلفية الجديدة بنجاح ✨',
      'toggle_ui_preview': 'معاينة شكل التطبيق',
      'zoom_pan_hint': 'يمكنك تحريك وتكبير الصورة (Zoom & Pan) لتحديد الجزء المرغوب',
      'custom_color_picker_title': 'اختيار لون خلفية مخصص',
      'restore_default_color': 'استعادة اللون الافتراضي',
      'bg_color_applied': 'تم تطبيق لون الخلفية الجديد بنجاح ✨',

      // Now Playing Themes
      'player_theme': 'شكل واجهة المشغل',
      'player_theme_desc': 'تغيير نمط وتأثيرات واجهة تشغيل الموسيقى',
      'select_player_theme': 'اختيار ثيم واجهة التشغيل',
      'player_theme_default': 'الافتراضي (غلاف الألبوم)',
      'player_theme_default_desc': 'تصميم كلاسيكي فخم يركز على غلاف الألبوم مع سحب الأغاني',
      'player_theme_vinyl': 'قرص الفينيل (Vinyl Disc 💿)',
      'player_theme_vinyl_desc': 'أسطوانة فينيل كلاسيكية تدور بسلاسة أثناء تشغيل الموسيقى',
      'player_theme_waves': 'أمواج صوتية (Audio Waves 🌊)',
      'player_theme_waves_desc': 'غلاف دائري محاط بأمواج صوتية وترددات بصرية متفاعلة مع الموسيقى',

      // Landscape Display Colors
      'landscape_mode': 'وضع العرض الأفقي',
      'more_options': 'المزيد من الخيارات',
      'landscape_display_colors': 'ألوان وضع العرض',
      'landscape_display_colors_subtitle': 'تخصيص ألوان واجهة العرض السينمائية',
      'landscape_color_app': 'ألوان التطبيق',
      'landscape_color_app_desc': 'الاعتماد على لون السمة المخصص في التطبيق',
      'landscape_color_artwork': 'ألوان غلاف الموسيقى',
      'landscape_color_artwork_desc': 'استخراج ألوان متناسقة وديناميكية من صورة الغلاف',

      // About
      'about': 'حول التطبيق',
      'about_app_desc': 'معلومات التطبيق والمطور',
      'developer_title': 'مطور التطبيق',
      'developer_name': 'محمد باحيو',
      'developer_name_en': 'Mohammed Bahayou',
      'social_media': 'تواصل معي على وسائل التواصل',
      'offline_music_tagline': 'مشغل الموسيقى المحلي دون إنترنت',
      'version': 'الإصدار',
      'version_copied': 'تم نسخ رقم الإصدار إلى الحافظة',
      'rate_app': 'تقييم التطبيق',
      'rate_app_sub': 'دعم التطبيق بملاحظاتك على المتجر',
      'share_app': 'مشاركة التطبيق',
      'share_app_sub': 'مشاركة مشغل الموسيقى مع الأصدقاء',
      'contact_feedback': 'التواصل والملاحظات',
      'contact_feedback_sub': 'إرسال ملاحظة أو اقتراح للمطور',
      'privacy_policy': 'سياسة الخصوصية',
      'privacy_policy_subtitle': 'التطبيق محلي وآمن 100% ولا يجمع أي بيانات',
      'open_source_licenses': 'تراخيص المصادر المفتوحة',
      'licenses_subtitle': 'عرض حزم وتراخيص البرمجيات المستخدمة',
      'copyright': '© 2026 MD Music. جميع الحقوق محفوظة.',

      // Privacy Policy Details
      'offline_guarantee_title': 'تطبيق موسيقى أوفلاين 100%',
      'offline_guarantee_subtitle': 'خصوصيتك محمية بالكامل ولا يتم رفع أو مشاركة أي بيانات خارج هاتفك.',
      'policy_item1_title': 'تشغيل محلي بالكامل',
      'policy_item1_desc': 'التطبيق يعمل دون الحاجة لأي اتصال بالإنترنت ولا يتصل بأي خوادم خارجية.',
      'policy_item2_title': 'لا يتم جمع بيانات شخصية',
      'policy_item2_desc': 'لا نجمع أسماء المستخدمين، الحسابات، البريد الإلكتروني، أو أي معلومات تعريفية.',
      'policy_item3_title': 'صلاحية قراءة الوسائط',
      'policy_item3_desc': 'تُستخدم الصلاحيات حصراً لقراءة ملفات الصوت المحفوظة على جهازك لتشغيلها.',
      'policy_item4_title': 'تخزين آمن ومحلي',
      'policy_item4_desc': 'تعديلاتك (كالألبومات والمفضلة) تُحفظ محلياً على جهازك فقط وتُحذف بحذف التطبيق.',

      // Reset
      'reset_all_settings': 'إعادة ضبط الإعدادات الافتراضية',
      'reset_settings_title': 'استعادة الإعدادات الافتراضية؟',
      'reset_settings_desc': 'هل أنت متأكد من استعادة إعدادات المظهر واللغة الافتراضية؟\n(لن يتم حذف أي أغانٍ أو قوائم تشغيل).',
      'reset_settings_done': 'تمت استعادة الإعدادات الافتراضية بنجاح',

      // Empty State & Permissions
      'no_songs_found': 'لم يتم العثور على أغانٍ',
      'permission_needed': 'يرجى منح إذن الوصول إلى الموسيقى لقراءة المقاطع الصوتية المخزنة على هاتفك.',
      'permission_snack_error': 'يرجى منح إذن الوصول إلى الموسيقى من إعدادات الهاتف لعرض أغانيك.',

      // Bulk Selection Mode
      'selected_count': '{count} محددة',
      'bulk_add_to_album': 'إضافة إلى ألبوم',
      'bulk_delete': 'حذف جماعي',
      'bulk_delete_confirm_title': 'حذف {count} أغاني نهائياً؟',
      'bulk_delete_confirm_desc': 'هل أنت متأكد من رغبتك في حذف {count} أغنية بشكل دائم من هذا الهاتف؟ لا يمكن التراجع عن هذا الإجراء.',
      'bulk_delete_success': 'تم حذف {count} أغنية بنجاح',
      'bulk_add_success': 'تمت إضافة {count} أغنية إلى "{album}"',
      'bulk_create_and_add': 'إنشاء ألبوم وإضافة الأغاني',
      'choose_album': 'اختر الألبوم',
    },

    // =========================================================
    // ENGLISH
    // =========================================================
    'en': {
      // Common & Navigation
      'settings': 'Settings',
      'close': 'Close',
      'cancel': 'Cancel',
      'ok': 'OK',
      'reset': 'Reset',
      'save': 'Save',
      'remove': 'Remove',
      'add': 'Add',
      'undo': 'Undo',
      'all': 'All',
      'songs': 'Songs',
      'albums': 'Albums',
      'artists': 'Artists',
      'playlists': 'Playlists',
      'favorites': 'Favorites',
      'search': 'Search',
      'search_hint': 'Search songs, artists, albums...',
      'all_songs': 'All Songs',
      'songs_list': 'Song List',
      'play_all': 'Play All',
      'shuffle_all': 'Shuffle',
      'now_playing': 'Now Playing',
      'no_songs': 'No songs found',
      'no_favorites': 'No favorites yet',
      'edit': 'Edit',
      'delete': 'Delete',
      'success': 'Success',
      'error': 'Error',
      'unknown': 'Unknown',
      'unknown_artist': 'Unknown Artist',
      'unknown_album': 'Unknown Album',
      'mb': 'MB',
      'details': 'Song Details',
      'queue': 'Playing Queue',
      'play': 'Play',
      'shuffle': 'Shuffle',
      'back': 'Back',

      // Song Actions & Details
      'play_now': 'Play Now',
      'add_to_favorites': 'Add to Favorites',
      'remove_from_favorites': 'Remove from Favorites',
      'favorite_badge': 'Favorite',
      'trim_and_edit': 'Edit Song & Artist',
      'edit_song_info': 'Edit Song & Artist',
      'set_as_ringtone': 'Set as Phone Ringtone',
      'setting_ringtone': 'Setting song as ringtone...',
      'ringtone_success': 'Song successfully set as ringtone 🔔',
      'ringtone_permission': 'Please allow write system settings permission to set ringtone',
      'ringtone_error': 'Could not set ringtone',
      'retry': 'Retry',
      'add_to_custom_album': 'Add to Custom Album',
      'song_details': 'File Information & Details',
      'delete_permanently': 'Delete Permanently from Device',
      'delete_song_title': 'Delete Song',
      'delete_song_confirm': 'Are you sure you want to permanently delete "{title}"?',
      'delete_song_success': 'Song deleted successfully 🗑️',
      'delete_song_error': 'Could not delete song',
      'detail_title': 'Title',
      'detail_artist': 'Artist',
      'detail_album': 'Album',
      'detail_duration': 'Duration',
      'detail_size': 'Size',

      // Custom Albums
      'custom_albums': 'Custom Albums',
      'create_new_album': 'Create New Album',
      'album_name_hint': 'Album name...',
      'create_and_add': 'Create & Add',
      'create_album_and_add_song': 'Create new album and add this song',
      'no_custom_albums_yet': 'No custom albums yet.\nTap above to create your first album!',
      'no_albums_yet': 'No albums yet',
      'create_album_prompt': 'Create custom albums with custom covers and your favorite songs.',
      'added_to_album': 'Added "{title}" to "{album}"',
      'removed_from_album': 'Removed "{title}" from "{album}"',
      'album_created_and_song_added': 'Created album "{album}" and added "{title}"',
      'added_badge': 'Added',
      'add_badge': 'Add',
      'songs_count': '{count} songs',
      'album_options': 'Album Options',
      'change_album_cover': 'Change Album Cover',
      'change_cover_subtitle': 'Choose new picture from gallery',
      'rename_album': 'Rename Album',
      'rename_album_subtitle': 'Edit current album name',
      'add_music_to_album': 'Add Songs to Album',
      'add_music_subtitle': 'Select and add tracks',
      'reorder_songs': 'Reorder Songs',
      'reorder_songs_subtitle': 'Drag and drop to rearrange tracks',
      'delete_album': 'Delete Album',
      'delete_album_confirm': 'Are you sure you want to delete album "{album}"? No songs will be deleted from your device.',
      'album_empty': 'This album is currently empty',
      'album_empty_desc': 'Select songs you want to add to this album with one tap.',
      'add_songs_now': 'Add Songs Now',
      'album_cover_updated': 'Album cover updated successfully ✨',
      'album_cover_error': 'Could not change album cover',
      'edit_album_name': 'Edit Album Name',
      'save_order': 'Save New Order',
      'order_saved': 'Song order saved successfully 🎶',
      'reorder_instructions': 'Long press and drag to reorder tracks ↕️',
      'no_songs_in_album_to_reorder': 'No songs in album to reorder',
      'add_songs_to_album': 'Add songs to "{album}"',
      'selected_songs_count': 'Selected {selected} of {total} songs',
      'select_all': 'Select All',
      'deselect_all': 'Deselect All',
      'save_changes': 'Save Changes',
      'songs_saved_in_album': 'Songs saved in "{album}" ({count} songs)',
      'create_first_album_now': 'Create your first album now',
      'type_album_name': 'Type album name...',
      'shuffle_all_play': 'Shuffle All',
      'play_album': 'Play',
      'remove_from_this_album': 'Remove from this album',
      'song_removed_from_album_msg': 'Removed "{title}" from this album',

      // Speed & Pitch
      'speed_pitch': 'Speed & Pitch',
      'speed_normal': 'Normal',
      'speed_fast': 'Fast',
      'speed_slow': 'Slow',
      'link_pitch_speed': 'Link pitch to playback speed',
      'pitch_changes_with_speed': 'Pitch changes with speed',
      'pitch_fixed': 'Fixed pitch',
      'reset_speed': 'Reset',

      // Song Edit & Trim
      'basic_info': 'Basic Information',
      'song_title_label': 'Song / Track Title',
      'song_title_hint': 'Enter song title',
      'artist_name_label': 'Artist / Singer Name',
      'artist_name_hint': 'Enter artist name',
      'select_artist_title': 'Select or Add Artist',
      'search_artist_placeholder': 'Search artist / singer...',
      'create_artist_btn': 'Create & Save Artist',
      'create_artist_prefix': 'Add new artist named:',
      'registered_artists': 'Existing Artists',
      'no_artist_found': 'No artist found, you can create and save it now',
      'artist_created_success': 'Artist created and saved successfully ✨',
      'waveform_instructions': 'Drag waveform handles to trim the audio clip precisely',
      'trim_section_title': 'Trim & Audio Selection',
      'trim_start': 'Start',
      'trim_end': 'End',
      'clip_duration': 'Clip Duration',
      'preview_trim': 'Preview Trimmed Audio',
      'stop_preview': 'Stop Preview',
      'saving_trim': 'Saving and trimming...',
      'save_edits': 'Save Edits',
      'revert_to_original': 'Revert to Original',
      'revert_dialog_title': 'Restore Original Track',
      'revert_dialog_desc': 'Are you sure you want to discard all edits and restore the full original track without any trimming?',
      'revert_confirm_btn': 'Yes, Restore Original',
      'revert_success': 'Original song restored successfully 🔄',
      'revert_error': 'Could not restore original track',
      'save_edits_success': 'Edits saved successfully ✨',
      'save_edits_error': 'Error saving edits',
      'change_cover_gallery': 'Change cover image from gallery',
      'pick_image_error': 'Could not pick image',

      // Playlists Screen
      'new_playlist': 'New Playlist',
      'playlist_name': 'Playlist name...',
      'recent_songs': 'Recently Played',
      'recent_songs_sub': '{count} songs played',
      'phone_library': 'Full Device Library',
      'phone_library_sub': '{count} local files',
      'create_custom_playlist': 'Create Custom Playlist',
      'playlist_created_success': 'Playlist "{name}" created successfully',
      'no_songs_in_playlist': 'No songs in {name}',
      'saved_songs_count': '{count} saved songs',
      'favorites_title': 'Favorite Songs',

      // Favorites Screen
      'no_favorites_title': 'No favorites yet',
      'no_favorites_hint': 'Tap the heart icon next to any song to find it saved here for quick access.',

      // Songs Screen
      'sort_date_added': 'Recently Added',
      'sort_name': 'Alphabetical',
      'sort_artist': 'Artist Name',
      'sort_duration': 'Duration',
      'no_local_songs': 'No local songs found on device',
      'scan_device': 'Scan Device',

      // Onboarding Screen
      'skip': 'Skip',
      'onboarding_subtitle': 'Your phone\'s local music player',
      'offline_feature_title': '100% Offline Playback',
      'offline_feature_desc': 'Listen to your saved music without needing an internet connection.',
      'auto_discovery_title': 'Automatic File Discovery',
      'auto_discovery_desc': 'Instantly detects and organizes new audio files on your device.',
      'design_feature_title': 'Premium Design & MBD Identity',
      'design_feature_desc': 'Sleek dark interface with neon accents, smooth animations and top performance.',
      'next': 'Next',
      'partnership_badge': 'Development & Identity Partnership',
      'contract_partnership': 'Partnership',
      'mbd_project_label': 'An MBD Project',
      'connect_developer': 'Connect with Developer',
      'enter_app_start_listening': 'Enter App & Start Listening',

      // Appearance
      'appearance': 'Appearance',
      'language': 'Language',
      'language_desc': 'Change application interface language',
      'language_system': 'System Default',
      'theme_mode': 'Theme Mode',
      'theme_system': 'System Default',
      'theme_light': 'Light Mode',
      'theme_dark': 'Dark Mode',
      'accent_color': 'Accent Color',
      'accent_color_desc': 'Choose the primary accent and button color',
      'select_accent_color': 'Choose Accent Color',
      'live_preview': 'Live Preview',
      'apply_color': 'Apply This Color',
      'sample_song_title': 'Sample Song Preview',
      'sample_song_artist': 'Artist Name • Album',
      'color_applied': 'Accent color applied successfully',
      'amoled_black': 'Pure Black (AMOLED)',
      'amoled_black_desc': '100% pure black backgrounds for OLED screens & battery saving',
      'amoled_dark_only': 'Available in dark mode only',

      // Custom Background System
      'custom_bg': 'App Background',
      'custom_bg_color': 'Custom Background Color',
      'custom_bg_color_desc': 'Pick any custom color for the entire app background',
      'custom_bg_image': 'Gallery Background Image',
      'custom_bg_image_desc': 'Set an image from gallery with blur, opacity & zoom controls',
      'bg_image_active': 'Custom image active',
      'bg_image_none': 'Using theme color',
      'edit_bg_image': 'Edit Background Image & Effects',
      'remove_custom_bg': 'Remove Custom Background',
      'remove_custom_bg_confirm': 'Restore default theme background?',
      'custom_bg_removed': 'Default background restored successfully',
      'bg_editor_title': 'Preview & Adjust Background',
      'bg_blur_slider': 'Blur Level',
      'bg_blur_none': 'No Blur',
      'bg_blur_max': 'Heavy Blur',
      'bg_opacity_slider': 'Opacity / Transparency',
      'bg_opacity_hint': 'Lower opacity reveals underlying color for legibility',
      'save_background': 'Save & Apply Background',
      'saving_background': 'Saving & applying background...',
      'background_applied_success': 'Background applied successfully ✨',
      'toggle_ui_preview': 'Toggle App UI Preview',
      'zoom_pan_hint': 'Pinch and drag to zoom and frame the exact visible part',
      'custom_color_picker_title': 'Pick Custom Background Color',
      'restore_default_color': 'Restore Default',
      'bg_color_applied': 'Background color applied successfully ✨',

      // Now Playing Themes
      'player_theme': 'Now Playing Theme',
      'player_theme_desc': 'Change the look & effects of the playback screen',
      'select_player_theme': 'Select Player Screen Theme',
      'player_theme_default': 'Default (Album Art)',
      'player_theme_default_desc': 'Clean classic design centered on album cover with swipe gestures',
      'player_theme_vinyl': 'Vinyl Disc 💿',
      'player_theme_vinyl_desc': 'Vintage vinyl record spinning smoothly during playback',
      'player_theme_waves': 'Audio Waves 🌊',
      'player_theme_waves_desc': 'Circular artwork surrounded by reactive rhythmic audio waves',

      // Landscape Display Colors
      'landscape_mode': 'Landscape Mode',
      'more_options': 'More Options',
      'landscape_display_colors': 'Display Mode Colors',
      'landscape_display_colors_subtitle': 'Customize cinematic landscape player colors',
      'landscape_color_app': 'App Colors',
      'landscape_color_app_desc': 'Use current app accent & theme palette',
      'landscape_color_artwork': 'Artwork Colors',
      'landscape_color_artwork_desc': 'Extract dynamic colors inspired by album cover',

      // About
      'about': 'About',
      'about_app_desc': 'App & Developer Info',
      'developer_title': 'App Developer',
      'developer_name': 'Mohammed Bahayou',
      'developer_name_en': 'Mohammed Bahayou',
      'social_media': 'Connect with Developer',
      'offline_music_tagline': 'Premium Offline Local Music Player',
      'version': 'Version',
      'version_copied': 'Version number copied to clipboard',
      'rate_app': 'Rate App',
      'rate_app_sub': 'Support the app with your feedback on the store',
      'share_app': 'Share App',
      'share_app_sub': 'Share MD Music player with friends',
      'contact_feedback': 'Feedback & Contact',
      'contact_feedback_sub': 'Send an inquiry or suggestion to the developer',
      'privacy_policy': 'Privacy Policy',
      'privacy_policy_subtitle': '100% offline and private. No personal data collected',
      'open_source_licenses': 'Open Source Licenses',
      'licenses_subtitle': 'View software packages and open source licenses',
      'copyright': '© 2026 MD Music. All rights reserved.',

      // Privacy Policy Details
      'offline_guarantee_title': '100% Offline Music Player',
      'offline_guarantee_subtitle': 'Your privacy is fully protected. No data is ever transmitted or uploaded outside your phone.',
      'policy_item1_title': 'Completely Offline Playback',
      'policy_item1_desc': 'The app operates entirely without internet access and connects to no external servers.',
      'policy_item2_title': 'No Personal Data Collected',
      'policy_item2_desc': 'We do not collect names, user accounts, email addresses, or any identifiable information.',
      'policy_item3_title': 'Media Storage Permissions',
      'policy_item3_desc': 'Permissions are exclusively used to read local audio files saved on your device for playback.',
      'policy_item4_title': 'Secure & Local Storage',
      'policy_item4_desc': 'Your preferences (custom albums, favorites) are stored locally on your device only.',

      // Reset
      'reset_all_settings': 'Reset All Settings',
      'reset_settings_title': 'Reset settings to defaults?',
      'reset_settings_desc': 'Are you sure you want to restore default appearance and language settings?\n(Music files and playlists will NOT be deleted).',
      'reset_settings_done': 'Default settings restored successfully',

      // Empty State & Permissions
      'no_songs_found': 'No Songs Found',
      'permission_needed': 'Please grant music access permissions to display audio files stored on your device.',
      'permission_snack_error': 'Please allow audio permission in system settings to view your songs.',

      // Bulk Selection Mode
      'selected_count': '{count} selected',
      'bulk_add_to_album': 'Add to Album',
      'bulk_delete': 'Bulk Delete',
      'bulk_delete_confirm_title': 'Delete {count} songs permanently?',
      'bulk_delete_confirm_desc': 'Are you sure you want to permanently delete {count} songs from this device? This action cannot be undone.',
      'bulk_delete_success': 'Successfully deleted {count} songs',
      'bulk_add_success': 'Added {count} songs to "{album}"',
      'bulk_create_and_add': 'Create Album & Add Songs',
      'choose_album': 'Select Album',
    },

    // =========================================================
    // FRENCH (Français)
    // =========================================================
    'fr': {
      // Common & Navigation
      'settings': 'Paramètres',
      'close': 'Fermer',
      'cancel': 'Annuler',
      'ok': 'OK',
      'reset': 'Réinitialiser',
      'save': 'Enregistrer',
      'remove': 'Retirer',
      'add': 'Ajouter',
      'undo': 'Annuler',
      'all': 'Tout',
      'songs': 'Morceaux',
      'albums': 'Albums',
      'artists': 'Artistes',
      'playlists': 'Playlists',
      'favorites': 'Favoris',
      'search': 'Rechercher',
      'search_hint': 'Rechercher un morceau, un artiste, un album...',
      'all_songs': 'Tous les morceaux',
      'songs_list': 'Liste des morceaux',
      'play_all': 'Tout lire',
      'shuffle_all': 'Aléatoire',
      'now_playing': 'Lecture en cours',
      'no_songs': 'Aucun morceau trouvé',
      'no_favorites': 'Aucun favori pour le moment',
      'edit': 'Modifier',
      'delete': 'Supprimer',
      'success': 'Succès',
      'error': 'Erreur',
      'unknown': 'Inconnu',
      'unknown_artist': 'Artiste inconnu',
      'unknown_album': 'Album inconnu',
      'mb': 'Mo',
      'details': 'Détails du morceau',
      'queue': 'File d\'attente',
      'play': 'Lire',
      'shuffle': 'Aléatoire',
      'back': 'Retour',

      // Song Actions & Details
      'play_now': 'Lire maintenant',
      'add_to_favorites': 'Ajouter aux favoris',
      'remove_from_favorites': 'Retirer des favoris',
      'favorite_badge': 'Favori',
      'trim_and_edit': 'Modifier le titre & l\'artiste',
      'edit_song_info': 'Modifier le titre & l\'artiste',
      'set_as_ringtone': 'Définir comme sonnerie',
      'setting_ringtone': 'Définition de la sonnerie en cours...',
      'ringtone_success': 'Sonnerie définie avec succès 🔔',
      'ringtone_permission': 'Veuillez autoriser la modification des paramètres système pour définir la sonnerie',
      'ringtone_error': 'Impossible de définir la sonnerie',
      'retry': 'Réessayer',
      'add_to_custom_album': 'Ajouter à un album personnalisé',
      'song_details': 'Informations & Détails du fichier',
      'delete_permanently': 'Supprimer définitivement de l\'appareil',
      'delete_song_title': 'Supprimer le morceau',
      'delete_song_confirm': 'Voulez-vous vraiment supprimer définitivement "{title}" ?',
      'delete_song_success': 'Morceau supprimé avec succès 🗑️',
      'delete_song_error': 'Impossible de supprimer le morceau',
      'detail_title': 'Titre',
      'detail_artist': 'Artiste',
      'detail_album': 'Album',
      'detail_duration': 'Durée',
      'detail_size': 'Taille',

      // Custom Albums
      'custom_albums': 'Albums personnalisés',
      'create_new_album': 'Créer un nouvel album',
      'album_name_hint': 'Nom de l\'album...',
      'create_and_add': 'Créer & Ajouter',
      'create_album_and_add_song': 'Créer un nouvel album et ajouter ce morceau',
      'no_custom_albums_yet': 'Aucun album personnalisé pour le moment.\nAppuyez ci-dessus pour créer votre premier album !',
      'no_albums_yet': 'Aucun album pour le moment',
      'create_album_prompt': 'Créez vos propres albums avec des pochettes personnalisées et vos morceaux favoris.',
      'added_to_album': '"{title}" ajouté à "{album}"',
      'removed_from_album': '"{title}" retiré de "{album}"',
      'album_created_and_song_added': 'Album "{album}" créé et "{title}" ajouté',
      'added_badge': 'Ajouté',
      'add_badge': 'Ajouter',
      'songs_count': '{count} morceaux',
      'album_options': 'Options de l\'album',
      'change_album_cover': 'Changer la pochette de l\'album',
      'change_cover_subtitle': 'Choisir une nouvelle photo depuis la galerie',
      'rename_album': 'Renommer l\'album',
      'rename_album_subtitle': 'Modifier le nom de l\'album actuel',
      'add_music_to_album': 'Ajouter des morceaux à l\'album',
      'add_music_subtitle': 'Sélectionner et ajouter des pistes',
      'reorder_songs': 'Changer l\'ordre des morceaux',
      'reorder_songs_subtitle': 'Glisser-déposer pour réorganiser la liste',
      'delete_album': 'Supprimer l\'album',
      'delete_album_confirm': 'Voulez-vous vraiment supprimer l\'album "{album}" ? Aucun fichier ne sera supprimé de votre appareil.',
      'album_empty': 'Cet album est actuellement vide',
      'album_empty_desc': 'Sélectionnez les morceaux que vous souhaitez ajouter à cet album en un clic.',
      'add_songs_now': 'Ajouter des morceaux maintenant',
      'album_cover_updated': 'Pochette de l\'album mise à jour avec succès ✨',
      'album_cover_error': 'Impossible de modifier la pochette',
      'edit_album_name': 'Modifier le nom de l\'album',
      'save_order': 'Enregistrer le nouvel ordre',
      'order_saved': 'Ordre des morceaux enregistré avec succès 🎶',
      'reorder_instructions': 'Appui long et glisser pour réorganiser ↕️',
      'no_songs_in_album_to_reorder': 'Aucun morceau dans l\'album à réorganiser',
      'add_songs_to_album': 'Ajouter des morceaux à "{album}"',
      'selected_songs_count': '{selected} sur {total} morceaux sélectionnés',
      'select_all': 'Tout sélectionner',
      'deselect_all': 'Tout désélectionner',
      'save_changes': 'Enregistrer les modifications',
      'songs_saved_in_album': 'Morceaux enregistrés dans "{album}" ({count} morceaux)',
      'create_first_album_now': 'Créer votre premier album maintenant',
      'type_album_name': 'Entrez le nom de l\'album...',
      'shuffle_all_play': 'Lecture aléatoire',
      'play_album': 'Lire',
      'remove_from_this_album': 'Retirer de cet album',
      'song_removed_from_album_msg': '"{title}" retiré de cet album',

      // Speed & Pitch
      'speed_pitch': 'Vitesse & Tonalité',
      'speed_normal': 'Normal',
      'speed_fast': 'Accéléré',
      'speed_slow': 'Ralenti',
      'link_pitch_speed': 'Lier la tonalité à la vitesse',
      'pitch_changes_with_speed': 'La tonalité varie avec la vitesse',
      'pitch_fixed': 'Tonalité fixe',
      'reset_speed': 'Réinitialiser',

      // Song Edit & Trim
      'basic_info': 'Informations de base',
      'song_title_label': 'Titre du morceau',
      'song_title_hint': 'Entrez le titre du morceau',
      'artist_name_label': 'Nom de l\'artiste',
      'artist_name_hint': 'Entrez le nom de l\'artiste',
      'select_artist_title': 'Sélectionner ou ajouter un artiste',
      'search_artist_placeholder': 'Rechercher un artiste / chanteur...',
      'create_artist_btn': 'Créer et enregistrer l\'artiste',
      'create_artist_prefix': 'Ajouter un nouvel artiste :',
      'registered_artists': 'Artistes existants',
      'no_artist_found': 'Aucun artiste trouvé, vous pouvez le créer et l\'enregistrer maintenant',
      'artist_created_success': 'Artiste créé et enregistré avec succès ✨',
      'waveform_instructions': 'Faites glisser les curseurs d\'ondes pour couper le clip avec précision',
      'trim_section_title': 'Couper & Sélection audio',
      'trim_start': 'Début',
      'trim_end': 'Fin',
      'clip_duration': 'Durée du clip',
      'preview_trim': 'Écouter l\'extrait coupé',
      'stop_preview': 'Arrêter l\'aperçu',
      'saving_trim': 'Enregistrement et découpage...',
      'save_edits': 'Enregistrer les modifications',
      'revert_to_original': 'Rétablir l\'original',
      'revert_dialog_title': 'Restaurer la version originale',
      'revert_dialog_desc': 'Voulez-vous annuler toutes les modifications et rétablir le morceau original complet sans coupure ?',
      'revert_confirm_btn': 'Oui, restaurer l\'original',
      'revert_success': 'Morceau original restauré avec succès 🔄',
      'revert_error': 'Impossible de restaurer l\'original',
      'save_edits_success': 'Modifications enregistrées avec succès ✨',
      'save_edits_error': 'Erreur lors de l\'enregistrement',
      'change_cover_gallery': 'Changer la pochette depuis la galerie',
      'pick_image_error': 'Impossible de sélectionner l\'image',

      // Playlists Screen
      'new_playlist': 'Nouvelle playlist',
      'playlist_name': 'Nom de la playlist...',
      'recent_songs': 'Récemment écoutés',
      'recent_songs_sub': '{count} morceaux écoutés',
      'phone_library': 'Bibliothèque complète',
      'phone_library_sub': '{count} fichiers locaux',
      'create_custom_playlist': 'Créer une playlist personnalisée',
      'playlist_created_success': 'Playlist "{name}" créée avec succès',
      'no_songs_in_playlist': 'Aucun morceau dans {name}',
      'saved_songs_count': '{count} morceaux sauvegardés',
      'favorites_title': 'Morceaux favoris',

      // Favorites Screen
      'no_favorites_title': 'Aucun favori pour le moment',
      'no_favorites_hint': 'Appuyez sur le cœur à côté d\'un morceau pour le retrouver ici en accès rapide.',

      // Songs Screen
      'sort_date_added': 'Récemment ajoutés',
      'sort_name': 'Ordre alphabétique',
      'sort_artist': 'Par artiste',
      'sort_duration': 'Par durée',
      'no_local_songs': 'Aucun morceau local sur l\'appareil',
      'scan_device': 'Analyser l\'appareil',

      // Onboarding Screen
      'skip': 'Passer',
      'onboarding_subtitle': 'Le lecteur de musique local de votre téléphone',
      'offline_feature_title': 'Lecture 100% hors-ligne',
      'offline_feature_desc': 'Écoutez votre musique sans aucune connexion Internet.',
      'auto_discovery_title': 'Détection automatique',
      'auto_discovery_desc': 'Détecte instantanément les nouveaux fichiers audio sur votre appareil.',
      'design_feature_title': 'Design élégant & Identité MBD',
      'design_feature_desc': 'Interface sombre et moderne aux accents néon, fluide et ultra performante.',
      'next': 'Suivant',
      'partnership_badge': 'Partenariat & Identité',
      'contract_partnership': 'Collaboration',
      'mbd_project_label': 'Un projet MBD',
      'connect_developer': 'Contacter le développeur',
      'enter_app_start_listening': 'Entrer et commencer l\'écoute',

      // Appearance
      'appearance': 'Apparence',
      'language': 'Langue',
      'language_desc': 'Changer la langue de l\'interface de l\'application',
      'language_system': 'Par défaut du système',
      'theme_mode': 'Mode du thème',
      'theme_system': 'Par défaut du système',
      'theme_light': 'Mode clair',
      'theme_dark': 'Mode sombre',
      'accent_color': 'Couleur d\'accentuation',
      'accent_color_desc': 'Choisissez la couleur principale des boutons et éléments actifs',
      'select_accent_color': 'Choisir la couleur d\'accentuation',
      'live_preview': 'Aperçu en direct',
      'apply_color': 'Appliquer cette couleur',
      'sample_song_title': 'Exemple de morceau',
      'sample_song_artist': 'Nom de l\'artiste • Album',
      'color_applied': 'Couleur appliquée avec succès',
      'amoled_black': 'Noir pur (AMOLED)',
      'amoled_black_desc': 'Fonds 100% noirs pour écrans OLED et économie de batterie',
      'amoled_dark_only': 'Disponible uniquement en mode sombre',

      // Custom Background System
      'custom_bg': 'Arrière-plan de l\'application',
      'custom_bg_color': 'Couleur d\'arrière-plan personnalisée',
      'custom_bg_color_desc': 'Choisissez une couleur pour l\'arrière-plan',
      'custom_bg_image': 'Image d\'arrière-plan (Galerie)',
      'custom_bg_image_desc': 'Définir une image avec réglages de flou, transparence et zoom',
      'bg_image_active': 'Image personnalisée active',
      'bg_image_none': 'Couleur du thème',
      'edit_bg_image': 'Modifier l\'image et les effets',
      'remove_custom_bg': 'Supprimer l\'arrière-plan personnalisé',
      'remove_custom_bg_confirm': 'Restaurer l\'arrière-plan par défaut du thème ?',
      'custom_bg_removed': 'Arrière-plan par défaut restauré',
      'bg_editor_title': 'Aperçu et réglage de l\'arrière-plan',
      'bg_blur_slider': 'Niveau de flou',
      'bg_blur_none': 'Sans flou',
      'bg_blur_max': 'Flou intense',
      'bg_opacity_slider': 'Opacité / Transparence',
      'bg_opacity_hint': 'Révéler la couleur sous-jacente pour plus de lisibilité',
      'save_background': 'Enregistrer et appliquer',
      'saving_background': 'Enregistrement en cours...',
      'background_applied_success': 'Arrière-plan appliqué avec succès ✨',
      'toggle_ui_preview': 'Aperçu de l\'interface',
      'zoom_pan_hint': 'Pincez et glissez pour zoomer et cadrer l\'image',
      'custom_color_picker_title': 'Choisir une couleur d\'arrière-plan',
      'restore_default_color': 'Restaurer par défaut',
      'bg_color_applied': 'Couleur d\'arrière-plan appliquée avec succès ✨',

      // Now Playing Themes
      'player_theme': 'Thème du lecteur',
      'player_theme_desc': 'Changer le style et les effets de l\'écran de lecture',
      'select_player_theme': 'Choisir le thème du lecteur',
      'player_theme_default': 'Par défaut (Pochette)',
      'player_theme_default_desc': 'Design classique centré sur la pochette avec gestes de balayage',
      'player_theme_vinyl': 'Disque Vinyle 💿',
      'player_theme_vinyl_desc': 'Disque vinyle classique tournant fluidement pendant la lecture',
      'player_theme_waves': 'Ondes sonores 🌊',
      'player_theme_waves_desc': 'Pochette circulaire entourée d\'ondes audio réactives à la musique',

      // Landscape Display Colors
      'landscape_mode': 'Mode Paysage',
      'more_options': 'Plus d\'options',
      'landscape_display_colors': 'Couleurs du mode affichage',
      'landscape_display_colors_subtitle': 'Personnaliser les couleurs du lecteur cinéma',
      'landscape_color_app': 'Couleurs de l\'application',
      'landscape_color_app_desc': 'Utiliser la couleur du thème de l\'application',
      'landscape_color_artwork': 'Couleurs de la pochette',
      'landscape_color_artwork_desc': 'Extraire des couleurs dynamiques de la pochette',

      // About
      'about': 'À propos',
      'about_app_desc': 'Infos sur l\'application et le développeur',
      'developer_title': 'Développeur de l\'application',
      'developer_name': 'Mohammed Bahayou',
      'developer_name_en': 'Mohammed Bahayou',
      'social_media': 'Réseaux sociaux du développeur',
      'offline_music_tagline': 'Lecteur de musique local hors-ligne haut de gamme',
      'version': 'Version',
      'version_copied': 'Numéro de version copié dans le presse-papiers',
      'rate_app': 'Noter l\'application',
      'rate_app_sub': 'Soutenez l\'application avec vos avis sur le store',
      'share_app': 'Partager l\'application',
      'share_app_sub': 'Partagez le lecteur MD Music avec vos amis',
      'contact_feedback': 'Commentaires & Contact',
      'contact_feedback_sub': 'Envoyer un message ou une suggestion au développeur',
      'privacy_policy': 'Politique de confidentialité',
      'privacy_policy_subtitle': '100% hors-ligne et privé. Aucune donnée personnelle collectée',
      'open_source_licenses': 'Licences open source',
      'licenses_subtitle': 'Afficher les packages logiciels et licences libres',
      'copyright': '© 2026 MD Music. Tous droits réservés.',

      // Privacy Policy Details
      'offline_guarantee_title': 'Lecteur de musique 100% hors-ligne',
      'offline_guarantee_subtitle': 'Votre vie privée est totalement protégée. Aucune donnée n\'est transmise ni téléversée hors de votre téléphone.',
      'policy_item1_title': 'Lecture entièrement hors-ligne',
      'policy_item1_desc': 'L\'application fonctionne sans aucune connexion Internet et ne se connecte à aucun serveur externe.',
      'policy_item2_title': 'Aucune donnée personnelle collectée',
      'policy_item2_desc': 'Nous ne collectons ni noms, ni comptes, ni adresses e-mail, ni informations identifiables.',
      'policy_item3_title': 'Autorisation d\'accès aux médias',
      'policy_item3_desc': 'Les autorisations sont strictement utilisées pour lire vos fichiers audio locaux stockés sur l\'appareil.',
      'policy_item4_title': 'Stockage sécurisé et local',
      'policy_item4_desc': 'Vos préférences (albums personnalisés, favoris) sont enregistrées localement sur votre téléphone uniquement.',

      // Reset
      'reset_all_settings': 'Réinitialiser tous les paramètres',
      'reset_settings_title': 'Restaurer les paramètres par défaut ?',
      'reset_settings_desc': 'Voulez-vous vraiment restaurer les paramètres d\'apparence et de langue par défaut ?\n(Aucun fichier audio ni playlist ne sera supprimé).',
      'reset_settings_done': 'Paramètres par défaut restaurés avec succès',

      // Empty State & Permissions
      'no_songs_found': 'Aucun morceau trouvé',
      'permission_needed': 'Veuillez accorder l\'autorisation d\'accès aux fichiers audio pour afficher vos morceaux.',
      'permission_snack_error': 'Veuillez autoriser l\'accès audio dans les paramètres pour afficher vos morceaux.',

      // Bulk Selection Mode
      'selected_count': '{count} sélectionnés',
      'bulk_add_to_album': 'Ajouter à l\'album',
      'bulk_delete': 'Suppression groupée',
      'bulk_delete_confirm_title': 'Supprimer définitivement {count} morceaux ?',
      'bulk_delete_confirm_desc': 'Voulez-vous vraiment supprimer définitivement {count} morceaux de cet appareil ? Cette action est irréversible.',
      'bulk_delete_success': '{count} morceaux supprimés avec succès',
      'bulk_add_success': '{count} morceaux ajoutés à "{album}"',
      'bulk_create_and_add': 'Créer un album et ajouter',
      'choose_album': 'Choisir un album',
    },
  };
}
