// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Araç';

  @override
  String get assistantName => 'Sürüş Asistanı';

  @override
  String get navRide => 'Sürüş';

  @override
  String get navGarage => 'Garaj';

  @override
  String get navLogbook => 'Günlük';

  @override
  String get navAssistant => 'Asistan';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get rideSubLive => 'Canlı';

  @override
  String get rideSubSignals => 'Sinyaller';

  @override
  String get rideSubRecord => 'Kayıt';

  @override
  String get rideSubDiagnostics => 'Tanılama';

  @override
  String get garageInbox => 'Gelen kutusu';

  @override
  String get garageFaults => 'Arızalar';

  @override
  String get garageMarkAllRead => 'Tümünü okundu say';

  @override
  String get garageRefresh => 'Yenile';

  @override
  String get garageSelectItem => 'Ayrıntıları görmek için bir öğe seç';

  @override
  String get logbookSelectRide => 'Ayrıntıları görmek için bir sürüş seç';

  @override
  String get commandBarTitle => 'Komut çubuğu';

  @override
  String get commandBarHint => 'Bir ekrana git veya soru sor';

  @override
  String get commandBarShortcut => 'Ctrl+K';

  @override
  String get commandBarNoMatch => 'Eşleşen komut yok';

  @override
  String commandGoTo(String destination) {
    return '$destination ekranına git';
  }

  @override
  String commandAsk(String assistant, String query) {
    return '$assistant\'na sor: $query';
  }

  @override
  String get commandOpenPanel => 'Asistan panelini aç';

  @override
  String get commandClosePanel => 'Asistan panelini kapat';

  @override
  String get panelToggleOpen => 'Asistan panelini göster';

  @override
  String get panelToggleClose => 'Asistan panelini gizle';

  @override
  String get settingsLanguage => 'Dil';

  @override
  String get settingsLanguageHint => 'Asistanın cevap dili de budur.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTurkish => 'Türkçe';
}
