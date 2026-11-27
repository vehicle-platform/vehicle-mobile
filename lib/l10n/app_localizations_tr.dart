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

  @override
  String alertsAnnounce(String text) {
    return 'Uyarı. $text';
  }

  @override
  String get alertsSettingsTitle => 'Sürüş uyarıları';

  @override
  String get alertsSettingsHint =>
      'Türler ilk uyarıdan sonra burada görünür. Kritik uyarı her zaman bannerını gösterir; sessize almak yalnızca sesi kapatır. Uyarı tamamen susturulabilir (gelen kutusunda kalır).';

  @override
  String get alertsSettingsEmpty => 'Henüz uyarı türü yok.';

  @override
  String get alertsMuteVoice => 'Ses';

  @override
  String get alertsMuteShow => 'Göster';

  @override
  String get alertsClassCritical => 'Kritik';

  @override
  String get alertsClassWarning => 'Uyarı';

  @override
  String get assistantGreeting =>
      'Merhaba, ben Sürüş Asistanı. Ne öğrenmek istersin?';

  @override
  String get assistantExample1 => 'Son sürüşüm nasıldı?';

  @override
  String get assistantExample2 => 'Son sürüşün özeti';

  @override
  String get assistantExample3 => 'Kayıtlı arızalar var mı?';

  @override
  String get assistantHint => 'Bir soru yaz';

  @override
  String get assistantHintListening => 'Dinliyorum...';

  @override
  String get assistantSend => 'Gönder';

  @override
  String get assistantClear => 'Konuşmayı temizle';

  @override
  String assistantRideChip(String id) {
    return 'Sürüş $id';
  }

  @override
  String get assistantStepReading => 'Veriler okunuyor ...';

  @override
  String assistantStepReadingRide(String id) {
    return '$id sürüşü okunuyor ...';
  }

  @override
  String get assistantSourceLlm => 'Asistan';

  @override
  String get assistantSourceTemplate => 'Veriden doğrulandı';

  @override
  String get assistantSourceUnsupported => 'Yanıtlanamadı';

  @override
  String get assistantSourceError => 'Hata';

  @override
  String get assistantModelTemplate => 'Şablon yanıt (model yok)';

  @override
  String get assistantModelNone => 'Yanıtlanmadı (model yok)';

  @override
  String assistantModelChipLabel(String text) {
    return 'Asistan modeli: $text';
  }

  @override
  String get assistantComputedBy => 'hesaplayan: ';

  @override
  String get assistantArguments => 'Parametreler';

  @override
  String get assistantResult => 'Sonuç';

  @override
  String get assistantResultEmpty => '(boş)';

  @override
  String assistantItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öğe',
      one: '1 öğe',
    );
    return '$_temp0';
  }

  @override
  String assistantMoreItems(int count) {
    return '+$count daha';
  }

  @override
  String get assistantTruncated => 'kısaltıldı';

  @override
  String get assistantFailSettings => 'Sunucu ayarları okunamadı.';

  @override
  String get assistantFailNoHost =>
      'Cihaz anahtarı olan bir sunucu ayarlanmamış. Ayarlar > Sunucular bölümünden ekle.';

  @override
  String assistantFailUnauthorized(String host) {
    return 'Cihaz anahtarı \"$host\" tarafından reddedildi. Anahtarı Ayarlar > Sunucular bölümünde kontrol et.';
  }

  @override
  String assistantFailInvalid(String message) {
    return 'Sunucu mesajı reddetti: $message';
  }

  @override
  String get assistantFailRateLimited =>
      'İstek sınırına takıldın. Birazdan tekrar dene.';

  @override
  String assistantFailRateLimitedIn(int seconds) {
    return 'İstek sınırına takıldın. $seconds sn sonra tekrar dene.';
  }

  @override
  String assistantFailDisabled(String host) {
    return 'Asistan \"$host\" üzerinde kapalı.';
  }

  @override
  String assistantFailUnreachable(String host) {
    return 'Sunucuya ulaşılamıyor: \"$host\".';
  }

  @override
  String assistantFailFailed(String message) {
    return 'İstek başarısız: $message';
  }

  @override
  String get assistantFailUnknown => 'bilinmeyen hata';

  @override
  String get assistantTheHost => 'sunucu';

  @override
  String get assistantVoiceInitTimeout =>
      'Ses tanıma kullanılamıyor. Soruyu yazabilirsin.';

  @override
  String get assistantVoiceNoSpeech => 'Seni duyamadım. Tekrar dener misin?';

  @override
  String get assistantVoiceUnavailable =>
      'Ses tanıma şu an kullanılamıyor. Soruyu yazabilirsin.';

  @override
  String get assistantVoicePermission =>
      'Mikrofon izni verilmedi ya da ses tanıma bu cihazda yok. İzni ayarlardan açabilir ya da soruyu yazabilirsin.';

  @override
  String get assistantVoiceLanguage =>
      'Bu dilde ses tanıma bu cihazda yok. Soruyu yazabilirsin.';

  @override
  String get assistantVoiceNetwork =>
      'Ses tanıma için internet bağlantısı gerekiyor.';

  @override
  String get assistantRouteIntercom => 'İntercom bağlı';

  @override
  String get assistantRoutePhone => 'Telefon mikrofonu';

  @override
  String get assistantMicStop => 'Dinlemeyi bitir';

  @override
  String get assistantMicSpeaking => 'Okumayı durdur ve konuş';

  @override
  String get assistantMicStart => 'Sesle sor';

  @override
  String get assistantClose => 'Kapat';

  @override
  String get assistantHoldToTalk => 'Basılı tut ve konuş';

  @override
  String get assistantReleaseToSend => 'Bırak ve gönder';

  @override
  String get assistantPreparing => 'Mikrofon hazırlanıyor ...';

  @override
  String get assistantChatsTitle => 'Sohbetler';

  @override
  String get assistantNewChat => 'Yeni sohbet';

  @override
  String get assistantSearchChats => 'Sohbetlerde ara';

  @override
  String get assistantNoChats => 'Henüz kayıtlı sohbet yok.';

  @override
  String get assistantNoSearchHits => 'Eşleşen mesaj bulunamadı.';

  @override
  String get assistantRenameChat => 'Sohbeti yeniden adlandır';

  @override
  String get assistantRenameHint => 'Sohbet başlığı';

  @override
  String get assistantDeleteChat => 'Sohbeti sil';

  @override
  String get assistantDeleteChatTitle => 'Sohbet silinsin mi?';

  @override
  String assistantDeleteChatBody(String title) {
    return '\"$title\" ve mesajları sunucudan silinir.';
  }

  @override
  String get assistantTemporaryChat => 'Geçici sohbet';

  @override
  String get assistantTemporaryOn =>
      'Geçici sohbet açık — mesajlar kaydedilmez.';

  @override
  String get assistantTemporaryOff => 'Sohbeti kaydet';

  @override
  String get assistantLoadChatFailed => 'Sohbet yüklenemedi.';

  @override
  String get assistantRenameFailed => 'Sohbet yeniden adlandırılamadı.';

  @override
  String get assistantDeleteFailed => 'Sohbet silinemedi.';

  @override
  String get assistantSearchFailed => 'Arama başarısız oldu. Tekrar dene.';

  @override
  String get assistantChatsLoadFailed => 'Sohbetlerin yüklenemedi.';

  @override
  String get assistantChatsRetry => 'Tekrar dene';

  @override
  String get formatToday => 'Bugün';

  @override
  String get formatYesterday => 'Dün';

  @override
  String get garageNotificationsTitle => 'Bildirimler';

  @override
  String get garageNotificationTitle => 'Bildirim';

  @override
  String get garageBellTooltip => 'Bildirimler';

  @override
  String garageBellTooltipUnread(int count) {
    return 'Bildirimler ($count okunmamış)';
  }

  @override
  String get garageSeverityCritical => 'Kritik';

  @override
  String get garageSeverityWarning => 'Uyarı';

  @override
  String get garageSeverityInfo => 'Bilgi';

  @override
  String get garageDayNoDate => 'Tarih yok';

  @override
  String get garageEmptyTitle => 'Henüz bildirim yok';

  @override
  String get garageEmptyHint => 'Sürüş özetleri ve uyarılar burada görünür.';

  @override
  String get garageUnread => 'Okunmadı';

  @override
  String get garageOpenRide => 'Sürüşü aç';

  @override
  String garageAskAssistant(String assistant) {
    return '$assistant\'na sor';
  }

  @override
  String garageAskQuestion(String title) {
    return '\"$title\" bildirimi hakkında ne söyleyebilirsin?';
  }

  @override
  String get garageFaultsTitle => 'Arızalar';

  @override
  String get garageFaultsLoading => 'Arızalar yükleniyor...';

  @override
  String get garageFaultsNoServer =>
      'vehicle-server ayarlanmamış. Ayarlar\'dan cihaz anahtarıyla bir sunucu ekle.';

  @override
  String get garageFaultsRetry => 'Tekrar dene';

  @override
  String get garageFaultsEmpty => 'Sunucu hiç arıza listelemiyor.';

  @override
  String get garageAnnounceAdviseStop =>
      'Güvenli bir yerde dur ve motoru kontrol ettir.';

  @override
  String garageAnnounceFault(String title) {
    return 'Yüksek öncelikli uyarı: $title. Güvenli bir yerde dur ve motoru kontrol ettir.';
  }

  @override
  String get logbookRideHistoryTitle => 'Sürüş geçmişi';

  @override
  String get logbookRideSummaryTitle => 'Sürüş özeti';

  @override
  String get logbookBringupTitle => 'Devreye alma kontrolü';

  @override
  String get logbookRefresh => 'Yenile';

  @override
  String get logbookRetry => 'Tekrar dene';

  @override
  String get logbookOpenSettings => 'Ayarları aç';

  @override
  String get logbookAskAssistant => 'Asistana sor';

  @override
  String get logbookLoadingRides => 'Sürüşler yükleniyor...';

  @override
  String get logbookLoadingSummary => 'Sürüş özeti yükleniyor...';

  @override
  String get logbookLoadingBringup => 'Devreye alma kontrolü yükleniyor...';

  @override
  String get logbookNoServer =>
      'Vehicle-server ayarlanmamış. Sunucu adresini ve API anahtarını Ayarlar\'dan gir.';

  @override
  String get logbookCleartextWarning =>
      'Uyarı: http:// API anahtarını ve sürüş verisini şifresiz gönderir. Yalnızca güvenilir yerel ağda kullan; dışarıdan erişilen sunucular için https:// kullan.';

  @override
  String get logbookAllRides => 'Tüm sürüşler';

  @override
  String logbookRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get logbookNoRidesInRange => 'Bu aralıkta sürüş yok.';

  @override
  String logbookSkippedHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Özeti kayıtlı olmayan $count oturum atlandı.',
      one: 'Özeti kayıtlı olmayan 1 oturum atlandı.',
    );
    return '$_temp0';
  }

  @override
  String get logbookDateRange => 'Tarih aralığı';

  @override
  String get logbookChangeRange => 'Aralığı değiştir';

  @override
  String get logbookClear => 'Temizle';

  @override
  String get logbookColumns => 'Sütunlar';

  @override
  String get logbookUpToTwo => 'en fazla iki';

  @override
  String logbookRideCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sürüş',
      one: '1 sürüş',
    );
    return '$_temp0';
  }

  @override
  String logbookSkippedCount(int count) {
    return '$count atlandı';
  }

  @override
  String get logbookUnknownTime => 'bilinmeyen zaman';

  @override
  String get logbookSignals => 'Sinyaller';

  @override
  String get logbookPerGear => 'Vites başına sinyaller';

  @override
  String get logbookBinned => 'Aralıklı sinyaller';

  @override
  String get logbookCoverage => 'Kapsam';

  @override
  String get logbookHealthWindows => 'Sağlık pencereleri';

  @override
  String get logbookNoSummary => 'Bu oturum için kayıtlı sürüş özeti yok.';

  @override
  String logbookDefsMismatch(String names) {
    return 'Başka defs aralık sınırlarıyla çözüldü: $names.';
  }

  @override
  String logbookRideDefinition(String value) {
    return 'sürüş $value';
  }

  @override
  String logbookDefsVersion(String value) {
    return 'defs $value';
  }

  @override
  String get logbookNoSignals => 'Bu sürüş özetinde kayıtlı sinyal yok.';

  @override
  String logbookGear(int n) {
    return 'Vites $n';
  }

  @override
  String get logbookNoGears => 'Kayıtlı vites yok.';

  @override
  String logbookAxisUnsupported(int n) {
    return '$n eksenli özetler henüz telefonda gösterilmiyor.';
  }

  @override
  String logbookTotalOutside(String total, String outside) {
    return 'toplam $total · dışında $outside';
  }

  @override
  String logbookNotAvailable(int n) {
    return 'Mevcut değil ($n)';
  }

  @override
  String logbookPendingInputs(String list) {
    return 'bekleyen: $list';
  }

  @override
  String logbookMissingInputs(String list) {
    return 'eksik: $list';
  }

  @override
  String logbookColumnsAxis(String input, String unit) {
    return 'sütunlar: $input [$unit]';
  }

  @override
  String logbookRowsAxis(String input, String unit) {
    return 'satırlar: $input [$unit]';
  }

  @override
  String get logbookSession => 'Oturum';

  @override
  String get logbookBringupUnsupported =>
      'bu sunucuda devreye alma kontrolü yok (bring-up rotalı vehicle-server gerekir, server#50)';

  @override
  String get logbookBringupUnauthorized =>
      'Yetkisiz: Ayarlar\'daki API anahtarını kontrol et.';

  @override
  String get logbookBringupNotFound => 'sunucuda bu oturum yok (önce yükle)';

  @override
  String get logbookBringupInvalid => 'geçersiz istek';

  @override
  String get logbookBringupUnavailable => 'sunucu kullanılamıyor';

  @override
  String get logbookBringupFailed => 'istek başarısız';

  @override
  String get logbookSettingsReadFailed => 'Sunucu ayarları okunamadı.';

  @override
  String get logbookNoBringupAnswer => 'Sunucu devreye alma yanıtı döndürmedi.';

  @override
  String get logbookNoChecks => 'Sunucu bu kapı için kontrol döndürmedi.';

  @override
  String get logbookChecks => 'Kontroller';

  @override
  String logbookManualPending(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elle kontrol bekliyor: $list',
      one: '1 elle kontrol bekliyor: $list',
    );
    return '$_temp0';
  }

  @override
  String logbookWarningsList(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uyarı: $list',
      one: '1 uyarı: $list',
    );
    return '$_temp0';
  }

  @override
  String get logbookBringupLegend =>
      'manual = bisiklet başında sen değerlendirirsin; unknown = oturumda bunun için veri yok.';

  @override
  String get logbookMeasured => 'Ölçülen';

  @override
  String get logbookExpected => 'Beklenen';

  @override
  String get logbookSource => 'Kaynak';

  @override
  String get logbookNote => 'Not';

  @override
  String get logbookWindowsLoading => 'Pencere örnekleri yükleniyor...';

  @override
  String get logbookWindowsMissingReport =>
      'Bu raporda pencere örneği yok (eski sunucu olabilir, veya sunucuda `vehicle-server derive <id>` çalıştır).';

  @override
  String get logbookWindowsUnavailable => 'Kullanılamıyor.';

  @override
  String get logbookWindowsNone => 'Kayıtlı pencere örneği yok.';

  @override
  String logbookWindowsCounts(int instances, int qualifying) {
    return '$instances örnek, $qualifying uygun';
  }

  @override
  String get logbookColStart => 'Başlangıç';

  @override
  String get logbookColEnd => 'Bitiş';

  @override
  String get logbookColDuration => 'Süre';

  @override
  String get logbookColCloseReason => 'Kapanış nedeni';

  @override
  String get logbookColQualifies => 'Uygun';

  @override
  String get logbookColFirst => 'İlk';

  @override
  String get logbookYes => 'evet';

  @override
  String get logbookNo => 'hayır';

  @override
  String get logbookFirstMark => 'ilk';

  @override
  String get rideMarkButton => 'Olay işaretle';

  @override
  String get rideMarkPickerTitle => 'Ne oldu?';

  @override
  String get rideMarkPickerHint => 'Birkaç saniye içinde otomatik kapanır';

  @override
  String get rideMarkKindMisfire => 'Tekleme';

  @override
  String get rideMarkKindNoise => 'Ses';

  @override
  String get rideMarkKindVibration => 'Titreşim';

  @override
  String get rideMarkKindWarningLight => 'Uyarı lambası';

  @override
  String get rideMarkKindRoughRoad => 'Bozuk yol';

  @override
  String get rideMarkKindTraffic => 'Trafik';

  @override
  String get rideMarkKindOther => 'Diğer';

  @override
  String rideMarkSaved(String kind) {
    return 'İşaretlendi: $kind';
  }

  @override
  String rideMarkQueuedOffline(int count, String kind) {
    return 'Çevrimdışı kaydedildi ($count sırada): $kind';
  }

  @override
  String get logbookMarksSection => 'Sürüş işaretleri';

  @override
  String get logbookMarksEmpty => 'Bu sürüş sırasında kaydedilmiş işaret yok.';

  @override
  String get logbookMarksLoadFailed => 'Sürüş işaretleri yüklenemedi.';

  @override
  String get logbookMarkDeleteTooltip => 'İşareti sil';

  @override
  String logbookMarkDeleteFailed(String detail) {
    return 'İşaret silinemedi: $detail';
  }

  @override
  String get rideMarkRejected => 'Sunucu bir işareti reddetti ve silindi.';

  @override
  String get quantityRideDistance => 'Mesafe';

  @override
  String get quantityRideTime => 'Sürüş süresi';

  @override
  String get quantityRideStopCount => 'Duruş';

  @override
  String get quantityRideIdleTime => 'Rölanti süresi';

  @override
  String get quantityRideWarmupTime => 'Isınma süresi';

  @override
  String get quantityRideEndCoolantTemp => 'Bitişte soğutma suyu';

  @override
  String get quantityRideStartCoolantTemp => 'Başlangıçta soğutma suyu';

  @override
  String get quantityRideFuelConsumption => 'Yakıt tüketimi';

  @override
  String get quantityRideFuelUsed => 'Harcanan yakıt';

  @override
  String get quantityRideRestVoltage => 'Boştaki akü';

  @override
  String get quantityRideShiftCount => 'Vites değişimi';

  @override
  String get quantityRideAggressiveness => 'Sürüş şiddeti';

  @override
  String get logbookCompare => 'Karşılaştır';

  @override
  String get logbookCompareTitle => 'Sürüşleri karşılaştır';

  @override
  String get logbookCompareHint =>
      'Her sürüşte göstermek için en fazla iki değer daha seç.';

  @override
  String get logbookRiderQuantities => 'Sürüş değerleri';

  @override
  String get logbookAllSignals => 'Tüm sinyaller';

  @override
  String get logbookCompareDone => 'Tamam';

  @override
  String get rideLiveOpenRecord => 'Kayıt ekranını aç';

  @override
  String get rideSynthTitle => 'SENTETİK VERİ';

  @override
  String get rideSynthText =>
      'Düğüm sahte değerler üretiyor. Burada gösterilenlerin hiçbiri motosikletten gelmiyor.';

  @override
  String get rideRecordCta => 'OTURUM KAYDET';

  @override
  String get rideStatusLabel => 'Durum';

  @override
  String get rideConnected => 'Bağlı';

  @override
  String get rideDisconnected => 'Bağlı değil';

  @override
  String get rideNotConnected => 'Bağlı değil';

  @override
  String get rideWaitingFirstPacket => 'İlk paket bekleniyor';

  @override
  String rideLastPacketAgoSub(String age) {
    return 'Son paket $age önce';
  }

  @override
  String get rideScanningTitle => 'Taranıyor...';

  @override
  String get rideLookingForBike => 'Motosiklet aranıyor';

  @override
  String get rideTapConnect => 'Motosikleti aramak için Bağlan\'a dokun';

  @override
  String get rideDisconnect => 'Bağlantıyı kes';

  @override
  String get rideConnect => 'Bağlan';

  @override
  String get rideScanning => 'Taranıyor';

  @override
  String rideBleDevice(String device) {
    return 'BLE $device';
  }

  @override
  String get rideBleConnected => 'BLE bağlı';

  @override
  String get rideBleDisconnected => 'BLE bağlı değil';

  @override
  String get rideEcuPresent => 'ECU var';

  @override
  String get rideEcuNotFound => 'ECU bulunamadı';

  @override
  String get rideEcuUnknown => 'ECU --';

  @override
  String get rideCanUnknown => 'CAN --';

  @override
  String get ridePollerOff => 'Sorgulayıcı kapalı';

  @override
  String get rideForeignLatched => 'Yabancı test cihazı kilitlendi';

  @override
  String get rideBusOffLatched => 'Bus-off kilitlendi';

  @override
  String get rideLatchesClear => 'Kilitler temiz';

  @override
  String get rideSyntheticData => 'Sentetik veri';

  @override
  String get rideImuActive => 'IMU etkin';

  @override
  String get rideImuInactive => 'IMU etkin değil';

  @override
  String get rideImuUnknown => 'IMU --';

  @override
  String get rideCanNa => 'CAN yok';

  @override
  String get rideCanRunning => 'CAN çalışıyor';

  @override
  String get rideCanErrorWarning => 'CAN hata uyarısı';

  @override
  String get rideCanBusOff => 'CAN bus-off';

  @override
  String get rideCanStopped => 'CAN durdu';

  @override
  String get rideCanNotInstalled => 'CAN kurulu değil';

  @override
  String get rideGpsNone => 'GPS --';

  @override
  String get rideGpsNotOffered => 'GPS sunulmuyor';

  @override
  String get rideGpsPairing => 'GPS eşleşiyor...';

  @override
  String get rideGpsPairPhone => 'GPS: telefonu motosikletle eşle';

  @override
  String get rideGpsWaiting => 'GPS veri bekliyor';

  @override
  String rideGpsFix(String fix, int sats) {
    return 'GPS $fix · $sats uydu';
  }

  @override
  String get rideSigLive => 'canlı';

  @override
  String get rideSigPolled => 'sorgulanan';

  @override
  String get rideSigCandidates => 'adaylar';

  @override
  String get rideFilterAll => 'Tümü';

  @override
  String get rideFilterPolled => 'Sorgulanan';

  @override
  String get rideFilterCandidates => 'Adaylar';

  @override
  String rideGroupLive(int live, int total) {
    return '$live / $total canlı';
  }

  @override
  String ridePollEvery(int ms) {
    return 'Her $ms ms\'de sorgulanır';
  }

  @override
  String rideAgeDetail(String age, String detail) {
    return 'Yaş $age · $detail';
  }

  @override
  String get rideNotPolled => 'Sorgulanmıyor';

  @override
  String get rideReportedByNode => 'Düğüm bildiriyor';

  @override
  String get rideDiagLink => 'Bağlantı';

  @override
  String get rideDiagBle => 'BLE';

  @override
  String get rideDiagDevice => 'Cihaz';

  @override
  String get rideDiagAttMtu => 'ATT MTU';

  @override
  String get rideDiagRequestedMtu => 'İstenen MTU';

  @override
  String get rideDiagPacketVersion => 'Paket sürümü';

  @override
  String get rideDiagLastPacket => 'Son paket';

  @override
  String rideDiagAgoSuffix(String age) {
    return '$age önce';
  }

  @override
  String get rideDiagDeviceTime => 'Cihaz saati';

  @override
  String get rideDiagPackets => 'Paketler';

  @override
  String get rideDiagReceived => 'Alınan';

  @override
  String get rideDiagLostGaps => 'Kayıp (sıra boşlukları)';

  @override
  String get rideDiagLoss => 'Kayıp oranı';

  @override
  String get rideDiagRejectedVersion => 'Reddedilen (sürüm)';

  @override
  String get rideDiagRejectedSize => 'Reddedilen (boyut)';

  @override
  String get rideDiagCanBus => 'Araç CAN veri yolu';

  @override
  String get rideDiagBusState => 'Yol durumu';

  @override
  String get rideDiagTxErrors => 'TX hataları';

  @override
  String get rideDiagRxErrors => 'RX hataları';

  @override
  String get rideDiagBusOffEvents => 'Bus-off olayları';

  @override
  String get rideDiagUnansweredDids => 'Yanıtsız DID\'ler';

  @override
  String get rideDiagPollerEnabled => 'Sorgulayıcı etkin';

  @override
  String get rideDiagForeignLatched => 'Yabancı test cihazı kilitli';

  @override
  String get rideDiagBusOffLatched => 'Bus-off kilitli';

  @override
  String get rideDiagSynthetic => 'Sentetik veri';

  @override
  String get rideYes => 'evet';

  @override
  String get rideNo => 'hayır';

  @override
  String rideDiagCanNeeds(String version) {
    return 'CAN sağlığı için sürüm $version veya daha yeni bir paket gerekir.';
  }

  @override
  String get rideDiagTester => 'Test cihazı (tanı sorgulayıcı)';

  @override
  String get rideDiagStepGapMax => 'Adım aralığı, en çok';

  @override
  String get rideDiagStepGapOver => 'Adım aralığı, sınır aşımı';

  @override
  String get rideDiagRoundTrip => 'Gidiş-dönüş, dönen DID';

  @override
  String get rideDiagDid => 'DID';

  @override
  String get rideDiagMin => 'En az';

  @override
  String get rideDiagMax => 'En çok';

  @override
  String get rideDiagMean => 'Ortalama';

  @override
  String get rideDiagSamples => 'Örnekler';

  @override
  String get rideDiagNrc78 => 'NRC 0x78 (beklemede)';

  @override
  String rideDiagTesterNeeds(String version) {
    return 'Test cihazı istatistikleri için sürüm $version paketi gerekir.';
  }

  @override
  String get rideRecTabRecord => 'Kayıt';

  @override
  String get rideRecTabSessions => 'Oturumlar';

  @override
  String get rideRecServerRides => 'Sunucu sürüşleri';

  @override
  String rideRecRunning(String duration) {
    return 'KAYIT $duration';
  }

  @override
  String get rideRecKeepOn =>
      'Kayıt sırasında bu ekranı açık ve uygulamayı ön planda tut. Uygulama arka plana alınır veya kapatılırsa Android BLE bağlantısını kesebilir -- henüz ön plan servisi yok.';

  @override
  String get rideRecStop => 'KAYDI DURDUR';

  @override
  String get rideRecStart => 'KAYDI BAŞLAT';

  @override
  String get rideRecMetadata => 'Oturum üst verisi';

  @override
  String get rideRecRiderName => 'Sürücü adı';

  @override
  String get rideRecRiderWeight => 'Sürücü ağırlığı (kg)';

  @override
  String get rideRecExtraLoad => 'Ek yük (kg)';

  @override
  String get rideRecAmbientTemp => 'Ortam sıcaklığı (°C)';

  @override
  String get rideRecWeather => 'Hava';

  @override
  String get rideRecTireFront => 'Ön lastik basıncı (bar)';

  @override
  String get rideRecTireRear => 'Arka lastik basıncı (bar)';

  @override
  String get rideRecFuel => 'Yakıt seviyesi (örn. dolu, 1/2, rezerv)';

  @override
  String get rideRecVehicleConfig => 'Araç yapılandırması (dişli/egzoz/filtre)';

  @override
  String get rideRecCondition => 'Durum etiketi (sağlam veya arıza türü)';

  @override
  String get rideRecRouteType => 'Güzergah türü';

  @override
  String get rideRecNote => 'Not';

  @override
  String get rideWeatherDry => 'kuru';

  @override
  String get rideWeatherWet => 'ıslak';

  @override
  String get rideWeatherUnknown => 'bilinmiyor';

  @override
  String get rideRouteUrban => 'şehir içi';

  @override
  String get rideRouteRural => 'kırsal';

  @override
  String get rideRouteHighway => 'otoyol';

  @override
  String get rideRouteClosedCourse => 'kapalı pist';

  @override
  String get rideRouteStationary => 'duran';

  @override
  String get rideRecGpsNotSubscribed =>
      'GPS: abone olunmadı -- telefonu motosikletle eşle (bağlı bağlantı gerekir); sonraki bağlantıda yeniden denenir';

  @override
  String get rideRecGpsPairing => 'GPS: eşleşiyor / abone oluyor...';

  @override
  String get rideRecGpsWaiting => 'GPS: abone olundu, veri bekleniyor';

  @override
  String get rideRecGpsNotOffered => 'GPS: yazılım tarafından sunulmuyor';

  @override
  String get rideRecGpsNone => 'GPS: -';

  @override
  String get rideRecGpsNotOk => ' (uygun değil)';

  @override
  String rideRecGpsLine(
      String fix, String notOk, int sats, String kmh, int lost) {
    return 'GPS: $fix$notOk   Uydu: $sats   $kmh km/sa   Kayıp/atlanan: $lost';
  }

  @override
  String rideRecSession(String id) {
    return 'Oturum: $id';
  }

  @override
  String get rideRecElapsed => 'GEÇEN SÜRE';

  @override
  String get rideRecStatPackets => 'Paketler';

  @override
  String get rideRecStatLost => 'Kayıp';

  @override
  String get rideRecStatLoss => 'Kayıp oranı';

  @override
  String get rideRecStatDecodeErrors => 'Çözme hataları';

  @override
  String get rideRecStatDisconnects => 'Kopmalar';

  @override
  String get rideRecStatImuSamples => 'IMU örnekleri';

  @override
  String get rideRecStatImuMissing => 'IMU eksik';

  @override
  String get rideRecStatMtu => 'MTU';

  @override
  String get rideRecFirmwareOld =>
      'Şimdiye kadar yalnızca sürüm 2 telemetri paketleri alındı -- bağlı cihazın yazılımı eski olabilir. CAN sağlığı, yaşlar ve IMU verisi için güncelle.';

  @override
  String get rideRecNoPacketsYet => 'Henüz paket yok';

  @override
  String rideRecLastPacketMs(int ms) {
    return 'Son paket: $ms ms önce';
  }

  @override
  String get rideUpNotUploaded => 'yüklenmedi';

  @override
  String get rideUpNotUploadedNoServer => 'yüklenmedi (sunucu ayarlı değil)';

  @override
  String get rideUpUploading => 'yükleniyor...';

  @override
  String get rideUpUploaded => 'yüklendi';

  @override
  String rideUpUploadedAt(String time) {
    return 'yüklendi ($time)';
  }

  @override
  String rideUpFailed(String reason) {
    return 'başarısız: $reason';
  }

  @override
  String get rideUpUnknownError => 'bilinmeyen hata';

  @override
  String get rideUpTipNoServer =>
      'Yüklemeyi açmak için Ayarlar\'da bir sunucu adresi gir';

  @override
  String get rideUpTipRetry => 'Yüklemeyi yeniden dene';

  @override
  String get rideUpTipUpload => 'vehicle-server\'a yükle';

  @override
  String get rideRecNoSessions => 'Henüz kayıtlı oturum yok.';

  @override
  String get rideRecUnknownTime => 'bilinmeyen zaman';

  @override
  String rideRecSessionLine(String duration, String packets, String loss) {
    return 'süre: $duration  paket: $packets  kayıp: $loss';
  }

  @override
  String rideRecUploadLine(String status) {
    return 'yükleme: $status';
  }

  @override
  String get rideRecRideSummary => 'Sürüş özeti';

  @override
  String get rideRecBringup => 'Devreye alma kontrolü';

  @override
  String get rideRecShare => 'Paylaş';

  @override
  String get rideRecDelete => 'Sil';

  @override
  String get rideRecCancel => 'Vazgeç';

  @override
  String get rideRecDeleteTitle => 'Oturum silinsin mi?';

  @override
  String rideRecDeleteBody(String id) {
    return 'Bu işlem \"$id\" oturumunu ve kayıtlı dosyalarını kalıcı olarak siler.';
  }

  @override
  String rideRecSaved(int packets, String loss) {
    return 'Oturum kaydedildi: $packets paket, %$loss kayıp';
  }

  @override
  String rideRecUploadFailedSnack(String reason) {
    return 'Yükleme başarısız: $reason';
  }

  @override
  String get rideRecUploadComplete => 'Yükleme tamamlandı.';

  @override
  String get rideVsigNoData => 'Araç sinyalleri: veri yok';

  @override
  String rideVsigLine(String parts, String lost) {
    return 'Araç sinyalleri: $parts$lost';
  }

  @override
  String rideVsigFresh(int n) {
    return '$n taze';
  }

  @override
  String rideVsigStale(int n) {
    return '$n eski';
  }

  @override
  String rideVsigNrc(int n) {
    return '$n NRC';
  }

  @override
  String rideVsigSkipped(int n) {
    return '$n atlandı';
  }

  @override
  String rideVsigNever(int n) {
    return '$n hiç gelmedi';
  }

  @override
  String rideVsigUnknown(int n) {
    return '$n bilinmeyen';
  }

  @override
  String rideVsigLostBlocks(int n) {
    return '   Kayıp bloklar: $n';
  }

  @override
  String get settingsCancel => 'İptal';

  @override
  String get settingsSave => 'Kaydet';

  @override
  String get settingsSaving => 'Kaydediliyor...';

  @override
  String get settingsDelete => 'Sil';

  @override
  String get settingsAdd => 'Ekle';

  @override
  String get settingsRetry => 'Tekrar dene';

  @override
  String get settingsDismiss => 'Vazgeç';

  @override
  String get settingsUnknownError => 'bilinmeyen hata';

  @override
  String get settingsSignalLive => 'CANLI';

  @override
  String get settingsSignalStale => 'ESKİ';

  @override
  String get settingsSignalNoData => 'VERİ YOK';

  @override
  String get settingsSignalNotPolled => 'SORGULANMIYOR';

  @override
  String get settingsSignalSkipped => 'ATLANDI';

  @override
  String get settingsAccount => 'Hesap';

  @override
  String settingsSignedInAs(String username) {
    return 'Giriş yapan: $username';
  }

  @override
  String get settingsNoVehicles => 'Bu hesaba bağlı araç yok.';

  @override
  String get settingsDeviceTokenConnected => 'Cihaz token\'ı ile bağlı';

  @override
  String get settingsNotSignedIn => 'Giriş yapılmadı';

  @override
  String get settingsAddVehicle => 'Araç ekle';

  @override
  String get settingsSignOut => 'Çıkış yap';

  @override
  String get settingsSignIn => 'Giriş yap';

  @override
  String get settingsVehicleId => 'Araç kimliği';

  @override
  String get settingsClaimCode => 'Talep kodu';

  @override
  String get settingsClaimInvalid => 'Araç kimliği veya kod geçersiz.';

  @override
  String get settingsRateLimited =>
      'Çok fazla deneme. Biraz sonra tekrar dene.';

  @override
  String settingsRateLimitedWait(int seconds) {
    return 'Çok fazla deneme. $seconds sn sonra tekrar dene.';
  }

  @override
  String get settingsUnreachable => 'Sunucuya ulaşılamadı.';

  @override
  String get settingsSessionEnded => 'Oturum sona erdi.';

  @override
  String settingsClaimFailed(String detail) {
    return 'Araç eklenemedi: $detail';
  }

  @override
  String get settingsHosts => 'Sunucular (vehicle-server)';

  @override
  String get settingsAddHost => 'Sunucu ekle';

  @override
  String get settingsEditHost => 'Sunucuyu düzenle';

  @override
  String get settingsDeleteHost => 'Sunucuyu sil';

  @override
  String get settingsHostsLoadFailed => 'Kayıtlı sunucular okunamadı.';

  @override
  String get settingsNoHosts =>
      'Henüz sunucu yok: kayıt ve oturum paylaşımı sunucusuz da tam çalışır. Yükleme, sürüşler, arızalar ve asistan için bir sunucu ekle.';

  @override
  String get settingsHostsHint =>
      'Cevap veren ilk sunucu kullanılır; yerel olanı başa koy. Sıralamak için sürükle.';

  @override
  String get settingsCheckHosts => 'Sunucuları yeniden dene';

  @override
  String get settingsChecking => 'Deneniyor...';

  @override
  String get settingsDeleteHostTitle => 'Sunucu silinsin mi?';

  @override
  String settingsDeleteHostBody(String name) {
    return '\"$name\" ve cihaz token\'ı bu cihazdan silinir.';
  }

  @override
  String get settingsHostActive => 'etkin';

  @override
  String get settingsTokenSet => 'token var';

  @override
  String get settingsNoToken => 'token yok';

  @override
  String get settingsCleartextShort =>
      'http:// token\'ı ve sürüş verisini şifrelemeden gönderir. Yalnızca güvenilir bir yerel ağda kullan.';

  @override
  String get settingsCleartextLong =>
      'Uyarı: http:// token\'ı ve sürüş verisini şifrelemeden gönderir. Yalnızca güvenilir bir yerel ağda kullan; dışarıdan erişilen her sunucu için https:// kullan.';

  @override
  String get settingsHostName => 'Ad';

  @override
  String get settingsHostNameHint => 'Motor (yerel Raspi)';

  @override
  String get settingsHostUrl => 'Sunucu adresi';

  @override
  String get settingsHostToken => 'Cihaz token\'ı';

  @override
  String get settingsEnterName => 'Bir ad gir';

  @override
  String get settingsEnterUrl => 'Sunucu adresini gir';

  @override
  String get settingsUpload => 'Yükleme';

  @override
  String get settingsWifiOnly => 'Yalnızca Wi-Fi ile yükle';

  @override
  String get settingsWifiOnlyHint =>
      'Oturum arşivleri birkaç MB olabilir; varsayılan olarak mobil veri kullanılmaz.';

  @override
  String get settingsReadAnswers => 'Cevapları sesli oku';

  @override
  String settingsReadAnswersHint(String assistant) {
    return '$assistant cevabın metnini sesli okur. Telefonda varsayılan açık, web ve bilgisayarda kapalı.';
  }

  @override
  String get settingsModelTitle => 'Asistan modeli';

  @override
  String settingsModelSubtitle(String assistant) {
    return '$assistant cevabı hangi modelle yazıyor';
  }

  @override
  String get settingsModelLoading => 'Yükleniyor...';

  @override
  String get settingsModelUnreadable => 'Okunamadı, tekrar denemek için dokun';

  @override
  String get settingsModelLocal => 'Yerel model (varsayılan)';

  @override
  String get settingsModelConsentRequired =>
      'Bulut sağlayıcı için onay gerekli. Onayı verip tekrar dene.';

  @override
  String get settingsModelCloudDisabled =>
      'Bu sunucuda bulut sağlayıcılar kapalı. Yerel model kullanılabilir.';

  @override
  String get settingsModelProviderError =>
      'Sağlayıcı hata verdi. Anahtarı ve bağlantıyı kontrol et.';

  @override
  String get settingsModelInvalid => 'Sunucu girişi kabul etmedi.';

  @override
  String settingsModelInvalidDetail(String detail) {
    return 'Sunucu girişi kabul etmedi: $detail';
  }

  @override
  String get settingsModelNotSupported =>
      'Bu sunucu sürümü model seçimini desteklemiyor.';

  @override
  String settingsModelFailed(String detail) {
    return 'İşlem başarısız: $detail';
  }

  @override
  String settingsModelIntro(String assistant) {
    return '$assistant varsayılan olarak sunucudaki yerel modeli kullanır. İstersen kendi API anahtarınla başka bir sağlayıcı seçebilirsin.';
  }

  @override
  String get settingsModelProvider => 'Sağlayıcı';

  @override
  String get settingsModelConnection => 'Bağlantı';

  @override
  String get settingsModelBaseUrl => 'Adres (base URL)';

  @override
  String get settingsModelKeyHelpCustom =>
      'Uç nokta adresini ve API anahtarını gir, sonra Kaydet\'e dokun.';

  @override
  String settingsModelKeyHelp(String provider) {
    return '$provider API anahtarını aşağıya yapıştır, sonra Kaydet\'e dokun. Anahtar bir kez gönderilir ve bir daha gösterilmez.';
  }

  @override
  String settingsModelSavedKey(String hint) {
    return 'Kayıtlı anahtar ••••$hint';
  }

  @override
  String get settingsModelDeleteKey => 'Anahtarı sil';

  @override
  String get settingsModelNewKey => 'Yeni anahtar (isteğe bağlı)';

  @override
  String get settingsModelApiKey => 'API anahtarı';

  @override
  String get settingsModelSendPosition => 'Konum verisi de gönderilsin';

  @override
  String get settingsModelSendPositionHint =>
      'Kapalıyken konum bilgisi sağlayıcıya gitmez.';

  @override
  String get settingsModelInsecureTitle => 'Güvenli bağlantı gerekli';

  @override
  String get settingsModelInsecureText =>
      'Anahtar yalnızca güvenli bağlantıyla (HTTPS) ya da Pi üzerinde komutla girilebilir:\nvehicle-server user set-llm <kullanıcı> --provider <id>';

  @override
  String get settingsModelTest => 'Bağlantıyı test et';

  @override
  String get settingsModelTesting => 'Deneniyor...';

  @override
  String settingsModelTestOk(int ms) {
    return 'Bağlantı çalışıyor ($ms ms).';
  }

  @override
  String settingsModelTestFailed(String detail) {
    return 'Bağlantı kurulamadı: $detail';
  }

  @override
  String get settingsModelKeyDeleted => 'Anahtar silindi.';

  @override
  String get settingsModelSaved => 'Kaydedildi.';

  @override
  String get settingsModelDeleteKeyTitle => 'Anahtar silinsin mi?';

  @override
  String get settingsModelDeleteKeyBody =>
      'Kayıtlı anahtar sunucudan silinir. Asistan bu sağlayıcıyla çalışmaz.';

  @override
  String get settingsModelLabel => 'Model';

  @override
  String get settingsModelListFailed =>
      'Liste alınamadı, model adını elle yaz.';

  @override
  String get settingsModelListLater =>
      'Anahtarı kaydedince model listesi gelir; şimdilik adı elle yazabilirsin.';

  @override
  String get settingsModelUnavailable => 'Bu sağlayıcı şu an kullanılamıyor.';

  @override
  String get settingsModelCloud => 'Bulut sağlayıcı';

  @override
  String settingsModelConsentTitle(String provider) {
    return '$provider ile devam edilsin mi?';
  }

  @override
  String settingsModelConsentText(String provider) {
    return 'Sorun ve sunucunun hesapladığı sürüş verileri $provider sağlayıcısına gönderilir. Maliyet kendi $provider hesabından faturalanır.';
  }

  @override
  String get settingsModelAccept => 'Kabul ediyorum';

  @override
  String get settingsAuthBadCredentials => 'Kullanıcı adı veya parola hatalı.';

  @override
  String get settingsAuthUsernameTaken => 'Bu kullanıcı adı alınmış.';

  @override
  String settingsAuthInvalid(String detail) {
    return 'Bilgiler kabul edilmedi: $detail';
  }

  @override
  String get settingsAuthInvalidFallback => 'geçersiz giriş';

  @override
  String get settingsAuthNotSupported =>
      'Bu sunucu hesap girişini desteklemiyor. Gelişmiş bölümünden cihaz token\'ı ile bağlan.';

  @override
  String settingsAuthRequestFailed(String detail) {
    return 'İstek başarısız: $detail';
  }

  @override
  String get settingsLoginSignIn => 'Giriş yap';

  @override
  String get settingsLoginRegister => 'Hesap oluştur';

  @override
  String get settingsLoginSubRegister =>
      'Araç kimliği ve sahiplik kodu ile hesabını oluştur.';

  @override
  String get settingsLoginSubSignIn =>
      'Sürüşlerini ve bildirimlerini görmek için hesabınla gir.';

  @override
  String get settingsLoginSavedHost => 'Kayıtlı sunucu';

  @override
  String get settingsLoginServer => 'Sunucu adresi';

  @override
  String get settingsLoginUsername => 'Kullanıcı adı';

  @override
  String get settingsLoginPassword => 'Parola';

  @override
  String get settingsLoginHaveAccount => 'Zaten hesabım var';

  @override
  String get settingsLoginAdvanced => 'Gelişmiş: cihaz token\'ı ile bağlan';

  @override
  String get settingsLoginConnect => 'Bağlan';

  @override
  String get settingsLoginSkip => 'Şimdilik atla';

  @override
  String get settingsLoginEnterUrl => 'Sunucu adresini gir.';

  @override
  String get settingsLoginInsecureUrl =>
      'Güvenli olmayan adres: https:// veya yerel ağdaki bir sunucu kullan.';

  @override
  String get settingsLoginNeedCredentials => 'Kullanıcı adı ve parola gerekli.';

  @override
  String get settingsLoginNeedVehicle => 'Araç kimliği ve talep kodu gerekli.';

  @override
  String get settingsLoginNeedToken => 'Cihaz token\'ını gir.';

  @override
  String get settingsLoginSessionEnded =>
      'Oturum sona erdi. Lütfen yeniden giriş yap.';

  @override
  String get settingsMemoryTitle => 'Asistan hafızası';

  @override
  String get settingsMemorySubtitle =>
      'Kayıtlı bilgiler ve sohbet dışa aktarımı';

  @override
  String get settingsMemoryEmpty =>
      'Henüz kayıtlı bilgi yok. Asistana motorun hakkında hatırlamasını istediğin bir şeyi yazabilirsin.';

  @override
  String get settingsMemoryEditTitle => 'Bilgiyi düzenle';

  @override
  String get settingsMemoryValueLabel => 'Değer';

  @override
  String get settingsMemoryDeleteAll => 'Tüm bilgileri sil';

  @override
  String get settingsMemoryDeleteAllTitle =>
      'Tüm kayıtlı bilgiler silinsin mi?';

  @override
  String get settingsMemoryDeleteAllBody =>
      'Asistanın hafızasındaki tüm kayıtlı bilgiler sunucudan silinir.';

  @override
  String get settingsMemoryDeletedAll => 'Tüm kayıtlı bilgiler silindi.';

  @override
  String get settingsMemoryExport => 'Sohbetlerimi dışa aktar';

  @override
  String get settingsMemoryExportSubtitle =>
      'Tüm sohbetleri ve hafıza bilgilerini JSON olarak indir veya paylaş.';

  @override
  String get settingsMemoryExportDone => 'Sohbet dışa aktarımı hazır.';

  @override
  String settingsMemoryExportFailed(String detail) {
    return 'Sohbetler dışa aktarılamadı: $detail';
  }

  @override
  String get settingsMemoryLoadFailed => 'Asistan hafızası yüklenemedi.';
}
