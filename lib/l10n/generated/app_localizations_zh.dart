// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'work_photos';

  @override
  String get navAlbums => '相册';

  @override
  String get navCategories => '分类';

  @override
  String get navImport => '导入';

  @override
  String get navMe => '我的';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get save => '保存';

  @override
  String get retry => '重试';

  @override
  String loadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSubtitle => '选择界面显示语言（跟随系统 / 中文 / English）';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get searchTitle => '搜索';

  @override
  String get searchHint => '搜索标题、备注、来源相册或分类名';

  @override
  String get searchClearKeyword => '清空关键词';

  @override
  String get searchCategoryLabel => '分类';

  @override
  String get searchAllCategories => '全部分类';

  @override
  String get searchFromDate => '起始日期';

  @override
  String get searchToDate => '截止日期';

  @override
  String get searchInitialTitle => '搜索照片';

  @override
  String get searchInitialMessage => '输入关键词，或选择分类 / 日期范围开始检索';

  @override
  String get searchNoResultsTitle => '没有找到匹配的照片';

  @override
  String get searchNoResultsMessage => '试试更换关键词，或减少筛选条件';

  @override
  String searchResultCount(int count) {
    return '找到 $count 张照片';
  }

  @override
  String get searchUntitled => '未命名照片';

  @override
  String get searchUsed => '已用';

  @override
  String get searchUnused => '未用';

  @override
  String searchFailed(Object error) {
    return '搜索失败：$error';
  }

  @override
  String get categoryTitle => '分类管理';

  @override
  String get categoryEmpty => '暂无分类，点击右下角 + 新建。';

  @override
  String get categorySearchHint => '搜索分类名称';

  @override
  String get categoryNoMatch => '没有匹配的分类。';

  @override
  String categorySelectedCount(Object count) {
    return '已选 $count 项';
  }

  @override
  String get categoryRootCategory => '根分类';

  @override
  String get categoryCreateTooltip => '新建分类';

  @override
  String get categoryBatchColor => '改色';

  @override
  String get categoryBatchMove => '移动';

  @override
  String get categoryBatchDelete => '删除';

  @override
  String categoryBatchColorTitle(Object count) {
    return '修改 $count 个分类的颜色';
  }

  @override
  String categoryBatchMoveTitle(Object count) {
    return '移动 $count 个分类到';
  }

  @override
  String get categoryBatchDeleteTitle => '删除分类';

  @override
  String categoryBatchDeleteMessage(Object count) {
    return '确定删除所选 $count 个分类？分类下的照片关联会被移除（照片本身保留）；它们的子分类会提升为根分类。';
  }

  @override
  String get categoryDeleteTitle => '删除分类';

  @override
  String categoryDeleteMessage(Object name) {
    return '确定删除“$name”？该分类下的照片关联会被移除（照片本身保留）。';
  }
}
