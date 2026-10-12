// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_category_dao.dart';

// ignore_for_file: type=lint
mixin _$PhotoCategoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhotoCategoryTable get photoCategory => attachedDatabase.photoCategory;
  PhotoCategoryDaoManager get managers => PhotoCategoryDaoManager(this);
}

class PhotoCategoryDaoManager {
  final _$PhotoCategoryDaoMixin _db;
  PhotoCategoryDaoManager(this._db);
  $$PhotoCategoryTableTableManager get photoCategory =>
      $$PhotoCategoryTableTableManager(_db.attachedDatabase, _db.photoCategory);
}
