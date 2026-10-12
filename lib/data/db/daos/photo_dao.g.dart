// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_dao.dart';

// ignore_for_file: type=lint
mixin _$PhotoDaoMixin on DatabaseAccessor<AppDatabase> {
  $PhotosTable get photos => attachedDatabase.photos;
  $PhotoCategoryTable get photoCategory => attachedDatabase.photoCategory;
  PhotoDaoManager get managers => PhotoDaoManager(this);
}

class PhotoDaoManager {
  final _$PhotoDaoMixin _db;
  PhotoDaoManager(this._db);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db.attachedDatabase, _db.photos);
  $$PhotoCategoryTableTableManager get photoCategory =>
      $$PhotoCategoryTableTableManager(_db.attachedDatabase, _db.photoCategory);
}
