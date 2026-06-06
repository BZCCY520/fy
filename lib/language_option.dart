class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.localeId,
    required this.ttsLocale,
  });

  final String code;
  final String name;
  final String nativeName;
  final String localeId;
  final String ttsLocale;

  String get label => '$nativeName · $name';
}

const appLanguages = <LanguageOption>[
  LanguageOption(
    code: 'zh',
    name: 'Chinese',
    nativeName: '中文',
    localeId: 'zh_CN',
    ttsLocale: 'zh-CN',
  ),
  LanguageOption(
    code: 'en',
    name: 'English',
    nativeName: 'English',
    localeId: 'en_US',
    ttsLocale: 'en-US',
  ),
  LanguageOption(
    code: 'ja',
    name: 'Japanese',
    nativeName: '日本語',
    localeId: 'ja_JP',
    ttsLocale: 'ja-JP',
  ),
  LanguageOption(
    code: 'ko',
    name: 'Korean',
    nativeName: '한국어',
    localeId: 'ko_KR',
    ttsLocale: 'ko-KR',
  ),
  LanguageOption(
    code: 'fr',
    name: 'French',
    nativeName: 'Français',
    localeId: 'fr_FR',
    ttsLocale: 'fr-FR',
  ),
  LanguageOption(
    code: 'de',
    name: 'German',
    nativeName: 'Deutsch',
    localeId: 'de_DE',
    ttsLocale: 'de-DE',
  ),
  LanguageOption(
    code: 'es',
    name: 'Spanish',
    nativeName: 'Español',
    localeId: 'es_ES',
    ttsLocale: 'es-ES',
  ),
  LanguageOption(
    code: 'it',
    name: 'Italian',
    nativeName: 'Italiano',
    localeId: 'it_IT',
    ttsLocale: 'it-IT',
  ),
  LanguageOption(
    code: 'pt',
    name: 'Portuguese',
    nativeName: 'Português',
    localeId: 'pt_BR',
    ttsLocale: 'pt-BR',
  ),
  LanguageOption(
    code: 'ru',
    name: 'Russian',
    nativeName: 'Русский',
    localeId: 'ru_RU',
    ttsLocale: 'ru-RU',
  ),
  LanguageOption(
    code: 'ar',
    name: 'Arabic',
    nativeName: 'العربية',
    localeId: 'ar_SA',
    ttsLocale: 'ar-SA',
  ),
];
