// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'work_photos';

  @override
  String get navAlbums => 'Albums';

  @override
  String get navCategories => 'Categories';

  @override
  String get navImport => 'Import';

  @override
  String get navMe => 'Me';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get retry => 'Retry';

  @override
  String loadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle =>
      'Choose display language (System / 中文 / English)';

  @override
  String get languageSystem => 'System';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search titles, notes, source albums or categories';

  @override
  String get searchClearKeyword => 'Clear keyword';

  @override
  String get searchCategoryLabel => 'Category';

  @override
  String get searchAllCategories => 'All categories';

  @override
  String get searchFromDate => 'From date';

  @override
  String get searchToDate => 'To date';

  @override
  String get searchInitialTitle => 'Search photos';

  @override
  String get searchInitialMessage =>
      'Type a keyword, or pick a category / date range to start';

  @override
  String get searchNoResultsTitle => 'No matching photos';

  @override
  String get searchNoResultsMessage =>
      'Try different keywords or fewer filters';

  @override
  String searchResultCount(int count) {
    return '$count photos found';
  }

  @override
  String get searchUntitled => 'Untitled photo';

  @override
  String get searchUsed => 'Used';

  @override
  String get searchUnused => 'Unused';

  @override
  String searchFailed(Object error) {
    return 'Search failed: $error';
  }

  @override
  String get categoryTitle => 'Categories';

  @override
  String get categoryEmpty => 'No categories yet. Tap + to create one.';

  @override
  String get categorySearchHint => 'Search categories';

  @override
  String get categoryNoMatch => 'No matching categories.';

  @override
  String categorySelectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get categoryRootCategory => 'Root category';

  @override
  String get categoryCreateTooltip => 'New category';

  @override
  String get categoryBatchColor => 'Color';

  @override
  String get categoryBatchMove => 'Move';

  @override
  String get categoryBatchDelete => 'Delete';

  @override
  String categoryBatchColorTitle(Object count) {
    return 'Change color of $count categories';
  }

  @override
  String categoryBatchMoveTitle(Object count) {
    return 'Move $count categories to';
  }

  @override
  String get categoryBatchDeleteTitle => 'Delete categories';

  @override
  String categoryBatchDeleteMessage(Object count) {
    return 'Delete the $count selected categories? Photo links will be removed (photos themselves are kept); their subcategories become root categories.';
  }

  @override
  String get categoryDeleteTitle => 'Delete category';

  @override
  String categoryDeleteMessage(Object name) {
    return 'Delete \"$name\"? Photo links to it will be removed (photos themselves are kept).';
  }
}
