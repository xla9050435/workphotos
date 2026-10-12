import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'work_photos'**
  String get appTitle;

  /// No description provided for @navAlbums.
  ///
  /// In zh, this message translates to:
  /// **'相册'**
  String get navAlbums;

  /// No description provided for @navCategories.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get navCategories;

  /// No description provided for @navImport.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get navImport;

  /// No description provided for @navMe.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navMe;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{error}'**
  String loadFailed(String error);

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择界面显示语言（跟随系统 / 中文 / English）'**
  String get settingsLanguageSubtitle;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @searchTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索标题、备注、来源相册或分类名'**
  String get searchHint;

  /// No description provided for @searchClearKeyword.
  ///
  /// In zh, this message translates to:
  /// **'清空关键词'**
  String get searchClearKeyword;

  /// No description provided for @searchCategoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get searchCategoryLabel;

  /// No description provided for @searchAllCategories.
  ///
  /// In zh, this message translates to:
  /// **'全部分类'**
  String get searchAllCategories;

  /// No description provided for @searchFromDate.
  ///
  /// In zh, this message translates to:
  /// **'起始日期'**
  String get searchFromDate;

  /// No description provided for @searchToDate.
  ///
  /// In zh, this message translates to:
  /// **'截止日期'**
  String get searchToDate;

  /// No description provided for @searchInitialTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索照片'**
  String get searchInitialTitle;

  /// No description provided for @searchInitialMessage.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词，或选择分类 / 日期范围开始检索'**
  String get searchInitialMessage;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的照片'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNoResultsMessage.
  ///
  /// In zh, this message translates to:
  /// **'试试更换关键词，或减少筛选条件'**
  String get searchNoResultsMessage;

  /// No description provided for @searchResultCount.
  ///
  /// In zh, this message translates to:
  /// **'找到 {count} 张照片'**
  String searchResultCount(int count);

  /// No description provided for @searchUntitled.
  ///
  /// In zh, this message translates to:
  /// **'未命名照片'**
  String get searchUntitled;

  /// No description provided for @searchUsed.
  ///
  /// In zh, this message translates to:
  /// **'已用'**
  String get searchUsed;

  /// No description provided for @searchUnused.
  ///
  /// In zh, this message translates to:
  /// **'未用'**
  String get searchUnused;

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败：{error}'**
  String searchFailed(Object error);

  /// No description provided for @categoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'分类管理'**
  String get categoryTitle;

  /// No description provided for @categoryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无分类，点击右下角 + 新建。'**
  String get categoryEmpty;

  /// No description provided for @categorySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索分类名称'**
  String get categorySearchHint;

  /// No description provided for @categoryNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的分类。'**
  String get categoryNoMatch;

  /// No description provided for @categorySelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 项'**
  String categorySelectedCount(Object count);

  /// No description provided for @categoryRootCategory.
  ///
  /// In zh, this message translates to:
  /// **'根分类'**
  String get categoryRootCategory;

  /// No description provided for @categoryCreateTooltip.
  ///
  /// In zh, this message translates to:
  /// **'新建分类'**
  String get categoryCreateTooltip;

  /// No description provided for @categoryBatchColor.
  ///
  /// In zh, this message translates to:
  /// **'改色'**
  String get categoryBatchColor;

  /// No description provided for @categoryBatchMove.
  ///
  /// In zh, this message translates to:
  /// **'移动'**
  String get categoryBatchMove;

  /// No description provided for @categoryBatchDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get categoryBatchDelete;

  /// No description provided for @categoryBatchColorTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改 {count} 个分类的颜色'**
  String categoryBatchColorTitle(Object count);

  /// No description provided for @categoryBatchMoveTitle.
  ///
  /// In zh, this message translates to:
  /// **'移动 {count} 个分类到'**
  String categoryBatchMoveTitle(Object count);

  /// No description provided for @categoryBatchDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除分类'**
  String get categoryBatchDeleteTitle;

  /// No description provided for @categoryBatchDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除所选 {count} 个分类？分类下的照片关联会被移除（照片本身保留）；它们的子分类会提升为根分类。'**
  String categoryBatchDeleteMessage(Object count);

  /// No description provided for @categoryDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除分类'**
  String get categoryDeleteTitle;

  /// No description provided for @categoryDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{name}”？该分类下的照片关联会被移除（照片本身保留）。'**
  String categoryDeleteMessage(Object name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
