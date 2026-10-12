// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PhotosTable extends Photos with TableInfo<$PhotosTable, PhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _mediaRefValueMeta =
      const VerificationMeta('mediaRefValue');
  @override
  late final GeneratedColumn<String> mediaRefValue = GeneratedColumn<String>(
      'media_ref_value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mediaRefTypeMeta =
      const VerificationMeta('mediaRefType');
  @override
  late final GeneratedColumn<String> mediaRefType = GeneratedColumn<String>(
      'media_ref_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _usedStatusMeta =
      const VerificationMeta('usedStatus');
  @override
  late final GeneratedColumn<int> usedStatus = GeneratedColumn<int>(
      'used_status', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceAlbumMeta =
      const VerificationMeta('sourceAlbum');
  @override
  late final GeneratedColumn<String> sourceAlbum = GeneratedColumn<String>(
      'source_album', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncStateMeta =
      const VerificationMeta('syncState');
  @override
  late final GeneratedColumn<int> syncState = GeneratedColumn<int>(
      'sync_state', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        mediaRefValue,
        mediaRefType,
        title,
        usedStatus,
        note,
        sourceAlbum,
        syncState,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photos';
  @override
  VerificationContext validateIntegrity(Insertable<PhotoRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('media_ref_value')) {
      context.handle(
          _mediaRefValueMeta,
          mediaRefValue.isAcceptableOrUnknown(
              data['media_ref_value']!, _mediaRefValueMeta));
    } else if (isInserting) {
      context.missing(_mediaRefValueMeta);
    }
    if (data.containsKey('media_ref_type')) {
      context.handle(
          _mediaRefTypeMeta,
          mediaRefType.isAcceptableOrUnknown(
              data['media_ref_type']!, _mediaRefTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaRefTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('used_status')) {
      context.handle(
          _usedStatusMeta,
          usedStatus.isAcceptableOrUnknown(
              data['used_status']!, _usedStatusMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('source_album')) {
      context.handle(
          _sourceAlbumMeta,
          sourceAlbum.isAcceptableOrUnknown(
              data['source_album']!, _sourceAlbumMeta));
    }
    if (data.containsKey('sync_state')) {
      context.handle(_syncStateMeta,
          syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      mediaRefValue: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}media_ref_value'])!,
      mediaRefType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_ref_type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      usedStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}used_status'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      sourceAlbum: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_album']),
      syncState: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_state'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PhotosTable createAlias(String alias) {
    return $PhotosTable(attachedDatabase, alias);
  }
}

class PhotoRow extends DataClass implements Insertable<PhotoRow> {
  final int id;
  final String mediaRefValue;
  final String mediaRefType;
  final String? title;
  final int usedStatus;

  /// 用户备注（纯文本，可空）。第四轮打磨新增。
  final String? note;
  final String? sourceAlbum;
  final int syncState;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PhotoRow(
      {required this.id,
      required this.mediaRefValue,
      required this.mediaRefType,
      this.title,
      required this.usedStatus,
      this.note,
      this.sourceAlbum,
      required this.syncState,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['media_ref_value'] = Variable<String>(mediaRefValue);
    map['media_ref_type'] = Variable<String>(mediaRefType);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['used_status'] = Variable<int>(usedStatus);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || sourceAlbum != null) {
      map['source_album'] = Variable<String>(sourceAlbum);
    }
    map['sync_state'] = Variable<int>(syncState);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PhotosCompanion toCompanion(bool nullToAbsent) {
    return PhotosCompanion(
      id: Value(id),
      mediaRefValue: Value(mediaRefValue),
      mediaRefType: Value(mediaRefType),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      usedStatus: Value(usedStatus),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      sourceAlbum: sourceAlbum == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceAlbum),
      syncState: Value(syncState),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PhotoRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoRow(
      id: serializer.fromJson<int>(json['id']),
      mediaRefValue: serializer.fromJson<String>(json['mediaRefValue']),
      mediaRefType: serializer.fromJson<String>(json['mediaRefType']),
      title: serializer.fromJson<String?>(json['title']),
      usedStatus: serializer.fromJson<int>(json['usedStatus']),
      note: serializer.fromJson<String?>(json['note']),
      sourceAlbum: serializer.fromJson<String?>(json['sourceAlbum']),
      syncState: serializer.fromJson<int>(json['syncState']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mediaRefValue': serializer.toJson<String>(mediaRefValue),
      'mediaRefType': serializer.toJson<String>(mediaRefType),
      'title': serializer.toJson<String?>(title),
      'usedStatus': serializer.toJson<int>(usedStatus),
      'note': serializer.toJson<String?>(note),
      'sourceAlbum': serializer.toJson<String?>(sourceAlbum),
      'syncState': serializer.toJson<int>(syncState),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PhotoRow copyWith(
          {int? id,
          String? mediaRefValue,
          String? mediaRefType,
          Value<String?> title = const Value.absent(),
          int? usedStatus,
          Value<String?> note = const Value.absent(),
          Value<String?> sourceAlbum = const Value.absent(),
          int? syncState,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      PhotoRow(
        id: id ?? this.id,
        mediaRefValue: mediaRefValue ?? this.mediaRefValue,
        mediaRefType: mediaRefType ?? this.mediaRefType,
        title: title.present ? title.value : this.title,
        usedStatus: usedStatus ?? this.usedStatus,
        note: note.present ? note.value : this.note,
        sourceAlbum: sourceAlbum.present ? sourceAlbum.value : this.sourceAlbum,
        syncState: syncState ?? this.syncState,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PhotoRow copyWithCompanion(PhotosCompanion data) {
    return PhotoRow(
      id: data.id.present ? data.id.value : this.id,
      mediaRefValue: data.mediaRefValue.present
          ? data.mediaRefValue.value
          : this.mediaRefValue,
      mediaRefType: data.mediaRefType.present
          ? data.mediaRefType.value
          : this.mediaRefType,
      title: data.title.present ? data.title.value : this.title,
      usedStatus:
          data.usedStatus.present ? data.usedStatus.value : this.usedStatus,
      note: data.note.present ? data.note.value : this.note,
      sourceAlbum:
          data.sourceAlbum.present ? data.sourceAlbum.value : this.sourceAlbum,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoRow(')
          ..write('id: $id, ')
          ..write('mediaRefValue: $mediaRefValue, ')
          ..write('mediaRefType: $mediaRefType, ')
          ..write('title: $title, ')
          ..write('usedStatus: $usedStatus, ')
          ..write('note: $note, ')
          ..write('sourceAlbum: $sourceAlbum, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mediaRefValue, mediaRefType, title,
      usedStatus, note, sourceAlbum, syncState, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoRow &&
          other.id == this.id &&
          other.mediaRefValue == this.mediaRefValue &&
          other.mediaRefType == this.mediaRefType &&
          other.title == this.title &&
          other.usedStatus == this.usedStatus &&
          other.note == this.note &&
          other.sourceAlbum == this.sourceAlbum &&
          other.syncState == this.syncState &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PhotosCompanion extends UpdateCompanion<PhotoRow> {
  final Value<int> id;
  final Value<String> mediaRefValue;
  final Value<String> mediaRefType;
  final Value<String?> title;
  final Value<int> usedStatus;
  final Value<String?> note;
  final Value<String?> sourceAlbum;
  final Value<int> syncState;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const PhotosCompanion({
    this.id = const Value.absent(),
    this.mediaRefValue = const Value.absent(),
    this.mediaRefType = const Value.absent(),
    this.title = const Value.absent(),
    this.usedStatus = const Value.absent(),
    this.note = const Value.absent(),
    this.sourceAlbum = const Value.absent(),
    this.syncState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PhotosCompanion.insert({
    this.id = const Value.absent(),
    required String mediaRefValue,
    required String mediaRefType,
    this.title = const Value.absent(),
    this.usedStatus = const Value.absent(),
    this.note = const Value.absent(),
    this.sourceAlbum = const Value.absent(),
    this.syncState = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : mediaRefValue = Value(mediaRefValue),
        mediaRefType = Value(mediaRefType),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<PhotoRow> custom({
    Expression<int>? id,
    Expression<String>? mediaRefValue,
    Expression<String>? mediaRefType,
    Expression<String>? title,
    Expression<int>? usedStatus,
    Expression<String>? note,
    Expression<String>? sourceAlbum,
    Expression<int>? syncState,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaRefValue != null) 'media_ref_value': mediaRefValue,
      if (mediaRefType != null) 'media_ref_type': mediaRefType,
      if (title != null) 'title': title,
      if (usedStatus != null) 'used_status': usedStatus,
      if (note != null) 'note': note,
      if (sourceAlbum != null) 'source_album': sourceAlbum,
      if (syncState != null) 'sync_state': syncState,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PhotosCompanion copyWith(
      {Value<int>? id,
      Value<String>? mediaRefValue,
      Value<String>? mediaRefType,
      Value<String?>? title,
      Value<int>? usedStatus,
      Value<String?>? note,
      Value<String?>? sourceAlbum,
      Value<int>? syncState,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return PhotosCompanion(
      id: id ?? this.id,
      mediaRefValue: mediaRefValue ?? this.mediaRefValue,
      mediaRefType: mediaRefType ?? this.mediaRefType,
      title: title ?? this.title,
      usedStatus: usedStatus ?? this.usedStatus,
      note: note ?? this.note,
      sourceAlbum: sourceAlbum ?? this.sourceAlbum,
      syncState: syncState ?? this.syncState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mediaRefValue.present) {
      map['media_ref_value'] = Variable<String>(mediaRefValue.value);
    }
    if (mediaRefType.present) {
      map['media_ref_type'] = Variable<String>(mediaRefType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (usedStatus.present) {
      map['used_status'] = Variable<int>(usedStatus.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (sourceAlbum.present) {
      map['source_album'] = Variable<String>(sourceAlbum.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<int>(syncState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosCompanion(')
          ..write('id: $id, ')
          ..write('mediaRefValue: $mediaRefValue, ')
          ..write('mediaRefType: $mediaRefType, ')
          ..write('title: $title, ')
          ..write('usedStatus: $usedStatus, ')
          ..write('note: $note, ')
          ..write('sourceAlbum: $sourceAlbum, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorHexMeta =
      const VerificationMeta('colorHex');
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
      'color_hex', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconNameMeta =
      const VerificationMeta('iconName');
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
      'icon_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createEntityFolderMeta =
      const VerificationMeta('createEntityFolder');
  @override
  late final GeneratedColumn<bool> createEntityFolder = GeneratedColumn<bool>(
      'create_entity_folder', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("create_entity_folder" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        colorHex,
        iconName,
        createEntityFolder,
        parentId,
        sortOrder,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<CategoryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(_colorHexMeta,
          colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta));
    } else if (isInserting) {
      context.missing(_colorHexMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(_iconNameMeta,
          iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta));
    } else if (isInserting) {
      context.missing(_iconNameMeta);
    }
    if (data.containsKey('create_entity_folder')) {
      context.handle(
          _createEntityFolderMeta,
          createEntityFolder.isAcceptableOrUnknown(
              data['create_entity_folder']!, _createEntityFolderMeta));
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      colorHex: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color_hex'])!,
      iconName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_name'])!,
      createEntityFolder: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}create_entity_folder'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}parent_id']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final int id;
  final String name;
  final String colorHex;
  final String iconName;
  final bool createEntityFolder;
  final int? parentId;
  final int sortOrder;
  final DateTime createdAt;
  const CategoryRow(
      {required this.id,
      required this.name,
      required this.colorHex,
      required this.iconName,
      required this.createEntityFolder,
      this.parentId,
      required this.sortOrder,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_hex'] = Variable<String>(colorHex);
    map['icon_name'] = Variable<String>(iconName);
    map['create_entity_folder'] = Variable<bool>(createEntityFolder);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      colorHex: Value(colorHex),
      iconName: Value(iconName),
      createEntityFolder: Value(createEntityFolder),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory CategoryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      iconName: serializer.fromJson<String>(json['iconName']),
      createEntityFolder: serializer.fromJson<bool>(json['createEntityFolder']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorHex': serializer.toJson<String>(colorHex),
      'iconName': serializer.toJson<String>(iconName),
      'createEntityFolder': serializer.toJson<bool>(createEntityFolder),
      'parentId': serializer.toJson<int?>(parentId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CategoryRow copyWith(
          {int? id,
          String? name,
          String? colorHex,
          String? iconName,
          bool? createEntityFolder,
          Value<int?> parentId = const Value.absent(),
          int? sortOrder,
          DateTime? createdAt}) =>
      CategoryRow(
        id: id ?? this.id,
        name: name ?? this.name,
        colorHex: colorHex ?? this.colorHex,
        iconName: iconName ?? this.iconName,
        createEntityFolder: createEntityFolder ?? this.createEntityFolder,
        parentId: parentId.present ? parentId.value : this.parentId,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
      );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      createEntityFolder: data.createEntityFolder.present
          ? data.createEntityFolder.value
          : this.createEntityFolder,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('iconName: $iconName, ')
          ..write('createEntityFolder: $createEntityFolder, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorHex, iconName,
      createEntityFolder, parentId, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorHex == this.colorHex &&
          other.iconName == this.iconName &&
          other.createEntityFolder == this.createEntityFolder &&
          other.parentId == this.parentId &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> colorHex;
  final Value<String> iconName;
  final Value<bool> createEntityFolder;
  final Value<int?> parentId;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.iconName = const Value.absent(),
    this.createEntityFolder = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String colorHex,
    required String iconName,
    this.createEntityFolder = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
  })  : name = Value(name),
        colorHex = Value(colorHex),
        iconName = Value(iconName),
        createdAt = Value(createdAt);
  static Insertable<CategoryRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? colorHex,
    Expression<String>? iconName,
    Expression<bool>? createEntityFolder,
    Expression<int>? parentId,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorHex != null) 'color_hex': colorHex,
      if (iconName != null) 'icon_name': iconName,
      if (createEntityFolder != null)
        'create_entity_folder': createEntityFolder,
      if (parentId != null) 'parent_id': parentId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CategoriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? colorHex,
      Value<String>? iconName,
      Value<bool>? createEntityFolder,
      Value<int?>? parentId,
      Value<int>? sortOrder,
      Value<DateTime>? createdAt}) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      createEntityFolder: createEntityFolder ?? this.createEntityFolder,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (createEntityFolder.present) {
      map['create_entity_folder'] = Variable<bool>(createEntityFolder.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('iconName: $iconName, ')
          ..write('createEntityFolder: $createEntityFolder, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PhotoCategoryTable extends PhotoCategory
    with TableInfo<$PhotoCategoryTable, PhotoCategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoCategoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _photoIdMeta =
      const VerificationMeta('photoId');
  @override
  late final GeneratedColumn<int> photoId = GeneratedColumn<int>(
      'photo_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _assignedAtMeta =
      const VerificationMeta('assignedAt');
  @override
  late final GeneratedColumn<DateTime> assignedAt = GeneratedColumn<DateTime>(
      'assigned_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [photoId, categoryId, assignedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_category';
  @override
  VerificationContext validateIntegrity(Insertable<PhotoCategoryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('photo_id')) {
      context.handle(_photoIdMeta,
          photoId.isAcceptableOrUnknown(data['photo_id']!, _photoIdMeta));
    } else if (isInserting) {
      context.missing(_photoIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('assigned_at')) {
      context.handle(
          _assignedAtMeta,
          assignedAt.isAcceptableOrUnknown(
              data['assigned_at']!, _assignedAtMeta));
    } else if (isInserting) {
      context.missing(_assignedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {photoId, categoryId};
  @override
  PhotoCategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoCategoryRow(
      photoId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}photo_id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id'])!,
      assignedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}assigned_at'])!,
    );
  }

  @override
  $PhotoCategoryTable createAlias(String alias) {
    return $PhotoCategoryTable(attachedDatabase, alias);
  }
}

class PhotoCategoryRow extends DataClass
    implements Insertable<PhotoCategoryRow> {
  final int photoId;
  final int categoryId;
  final DateTime assignedAt;
  const PhotoCategoryRow(
      {required this.photoId,
      required this.categoryId,
      required this.assignedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['photo_id'] = Variable<int>(photoId);
    map['category_id'] = Variable<int>(categoryId);
    map['assigned_at'] = Variable<DateTime>(assignedAt);
    return map;
  }

  PhotoCategoryCompanion toCompanion(bool nullToAbsent) {
    return PhotoCategoryCompanion(
      photoId: Value(photoId),
      categoryId: Value(categoryId),
      assignedAt: Value(assignedAt),
    );
  }

  factory PhotoCategoryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoCategoryRow(
      photoId: serializer.fromJson<int>(json['photoId']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      assignedAt: serializer.fromJson<DateTime>(json['assignedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'photoId': serializer.toJson<int>(photoId),
      'categoryId': serializer.toJson<int>(categoryId),
      'assignedAt': serializer.toJson<DateTime>(assignedAt),
    };
  }

  PhotoCategoryRow copyWith(
          {int? photoId, int? categoryId, DateTime? assignedAt}) =>
      PhotoCategoryRow(
        photoId: photoId ?? this.photoId,
        categoryId: categoryId ?? this.categoryId,
        assignedAt: assignedAt ?? this.assignedAt,
      );
  PhotoCategoryRow copyWithCompanion(PhotoCategoryCompanion data) {
    return PhotoCategoryRow(
      photoId: data.photoId.present ? data.photoId.value : this.photoId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      assignedAt:
          data.assignedAt.present ? data.assignedAt.value : this.assignedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoCategoryRow(')
          ..write('photoId: $photoId, ')
          ..write('categoryId: $categoryId, ')
          ..write('assignedAt: $assignedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(photoId, categoryId, assignedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoCategoryRow &&
          other.photoId == this.photoId &&
          other.categoryId == this.categoryId &&
          other.assignedAt == this.assignedAt);
}

class PhotoCategoryCompanion extends UpdateCompanion<PhotoCategoryRow> {
  final Value<int> photoId;
  final Value<int> categoryId;
  final Value<DateTime> assignedAt;
  final Value<int> rowid;
  const PhotoCategoryCompanion({
    this.photoId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.assignedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoCategoryCompanion.insert({
    required int photoId,
    required int categoryId,
    required DateTime assignedAt,
    this.rowid = const Value.absent(),
  })  : photoId = Value(photoId),
        categoryId = Value(categoryId),
        assignedAt = Value(assignedAt);
  static Insertable<PhotoCategoryRow> custom({
    Expression<int>? photoId,
    Expression<int>? categoryId,
    Expression<DateTime>? assignedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (photoId != null) 'photo_id': photoId,
      if (categoryId != null) 'category_id': categoryId,
      if (assignedAt != null) 'assigned_at': assignedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoCategoryCompanion copyWith(
      {Value<int>? photoId,
      Value<int>? categoryId,
      Value<DateTime>? assignedAt,
      Value<int>? rowid}) {
    return PhotoCategoryCompanion(
      photoId: photoId ?? this.photoId,
      categoryId: categoryId ?? this.categoryId,
      assignedAt: assignedAt ?? this.assignedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (photoId.present) {
      map['photo_id'] = Variable<int>(photoId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (assignedAt.present) {
      map['assigned_at'] = Variable<DateTime>(assignedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoCategoryCompanion(')
          ..write('photoId: $photoId, ')
          ..write('categoryId: $categoryId, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $PhotoCategoryTable photoCategory = $PhotoCategoryTable(this);
  late final Index idxPhotosCreatedAt = Index('idx_photos_created_at',
      'CREATE INDEX idx_photos_created_at ON photos (created_at)');
  late final Index idxPcCategory = Index('idx_pc_category',
      'CREATE INDEX idx_pc_category ON photo_category (category_id)');
  late final Index idxPcPhoto = Index(
      'idx_pc_photo', 'CREATE INDEX idx_pc_photo ON photo_category (photo_id)');
  late final PhotoDao photoDao = PhotoDao(this as AppDatabase);
  late final CategoryDao categoryDao = CategoryDao(this as AppDatabase);
  late final PhotoCategoryDao photoCategoryDao =
      PhotoCategoryDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        photos,
        categories,
        photoCategory,
        idxPhotosCreatedAt,
        idxPcCategory,
        idxPcPhoto
      ];
}

typedef $$PhotosTableCreateCompanionBuilder = PhotosCompanion Function({
  Value<int> id,
  required String mediaRefValue,
  required String mediaRefType,
  Value<String?> title,
  Value<int> usedStatus,
  Value<String?> note,
  Value<String?> sourceAlbum,
  Value<int> syncState,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$PhotosTableUpdateCompanionBuilder = PhotosCompanion Function({
  Value<int> id,
  Value<String> mediaRefValue,
  Value<String> mediaRefType,
  Value<String?> title,
  Value<int> usedStatus,
  Value<String?> note,
  Value<String?> sourceAlbum,
  Value<int> syncState,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$PhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaRefValue => $composableBuilder(
      column: $table.mediaRefValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaRefType => $composableBuilder(
      column: $table.mediaRefType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get usedStatus => $composableBuilder(
      column: $table.usedStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceAlbum => $composableBuilder(
      column: $table.sourceAlbum, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaRefValue => $composableBuilder(
      column: $table.mediaRefValue,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaRefType => $composableBuilder(
      column: $table.mediaRefType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get usedStatus => $composableBuilder(
      column: $table.usedStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceAlbum => $composableBuilder(
      column: $table.sourceAlbum, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mediaRefValue => $composableBuilder(
      column: $table.mediaRefValue, builder: (column) => column);

  GeneratedColumn<String> get mediaRefType => $composableBuilder(
      column: $table.mediaRefType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get usedStatus => $composableBuilder(
      column: $table.usedStatus, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get sourceAlbum => $composableBuilder(
      column: $table.sourceAlbum, builder: (column) => column);

  GeneratedColumn<int> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PhotosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PhotosTable,
    PhotoRow,
    $$PhotosTableFilterComposer,
    $$PhotosTableOrderingComposer,
    $$PhotosTableAnnotationComposer,
    $$PhotosTableCreateCompanionBuilder,
    $$PhotosTableUpdateCompanionBuilder,
    (PhotoRow, BaseReferences<_$AppDatabase, $PhotosTable, PhotoRow>),
    PhotoRow,
    PrefetchHooks Function()> {
  $$PhotosTableTableManager(_$AppDatabase db, $PhotosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> mediaRefValue = const Value.absent(),
            Value<String> mediaRefType = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<int> usedStatus = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> sourceAlbum = const Value.absent(),
            Value<int> syncState = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              PhotosCompanion(
            id: id,
            mediaRefValue: mediaRefValue,
            mediaRefType: mediaRefType,
            title: title,
            usedStatus: usedStatus,
            note: note,
            sourceAlbum: sourceAlbum,
            syncState: syncState,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String mediaRefValue,
            required String mediaRefType,
            Value<String?> title = const Value.absent(),
            Value<int> usedStatus = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> sourceAlbum = const Value.absent(),
            Value<int> syncState = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
          }) =>
              PhotosCompanion.insert(
            id: id,
            mediaRefValue: mediaRefValue,
            mediaRefType: mediaRefType,
            title: title,
            usedStatus: usedStatus,
            note: note,
            sourceAlbum: sourceAlbum,
            syncState: syncState,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PhotosTable, PhotoRow>(table),
                    BaseReferences<_$AppDatabase, $PhotosTable, PhotoRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PhotosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PhotosTable,
    PhotoRow,
    $$PhotosTableFilterComposer,
    $$PhotosTableOrderingComposer,
    $$PhotosTableAnnotationComposer,
    $$PhotosTableCreateCompanionBuilder,
    $$PhotosTableUpdateCompanionBuilder,
    (PhotoRow, BaseReferences<_$AppDatabase, $PhotosTable, PhotoRow>),
    PhotoRow,
    PrefetchHooks Function()>;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  required String name,
  required String colorHex,
  required String iconName,
  Value<bool> createEntityFolder,
  Value<int?> parentId,
  Value<int> sortOrder,
  required DateTime createdAt,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> colorHex,
  Value<String> iconName,
  Value<bool> createEntityFolder,
  Value<int?> parentId,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colorHex => $composableBuilder(
      column: $table.colorHex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get createEntityFolder => $composableBuilder(
      column: $table.createEntityFolder,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colorHex => $composableBuilder(
      column: $table.colorHex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get createEntityFolder => $composableBuilder(
      column: $table.createEntityFolder,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<bool> get createEntityFolder => $composableBuilder(
      column: $table.createEntityFolder, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoriesTable,
    CategoryRow,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (CategoryRow, BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>),
    CategoryRow,
    PrefetchHooks Function()> {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> colorHex = const Value.absent(),
            Value<String> iconName = const Value.absent(),
            Value<bool> createEntityFolder = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              CategoriesCompanion(
            id: id,
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            createEntityFolder: createEntityFolder,
            parentId: parentId,
            sortOrder: sortOrder,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String colorHex,
            required String iconName,
            Value<bool> createEntityFolder = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            required DateTime createdAt,
          }) =>
              CategoriesCompanion.insert(
            id: id,
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            createEntityFolder: createEntityFolder,
            parentId: parentId,
            sortOrder: sortOrder,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CategoriesTable, CategoryRow>(table),
                    BaseReferences<_$AppDatabase, $CategoriesTable,
                        CategoryRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoriesTable,
    CategoryRow,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (CategoryRow, BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>),
    CategoryRow,
    PrefetchHooks Function()>;
typedef $$PhotoCategoryTableCreateCompanionBuilder = PhotoCategoryCompanion
    Function({
  required int photoId,
  required int categoryId,
  required DateTime assignedAt,
  Value<int> rowid,
});
typedef $$PhotoCategoryTableUpdateCompanionBuilder = PhotoCategoryCompanion
    Function({
  Value<int> photoId,
  Value<int> categoryId,
  Value<DateTime> assignedAt,
  Value<int> rowid,
});

class $$PhotoCategoryTableFilterComposer
    extends Composer<_$AppDatabase, $PhotoCategoryTable> {
  $$PhotoCategoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get photoId => $composableBuilder(
      column: $table.photoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get assignedAt => $composableBuilder(
      column: $table.assignedAt, builder: (column) => ColumnFilters(column));
}

class $$PhotoCategoryTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotoCategoryTable> {
  $$PhotoCategoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get photoId => $composableBuilder(
      column: $table.photoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get assignedAt => $composableBuilder(
      column: $table.assignedAt, builder: (column) => ColumnOrderings(column));
}

class $$PhotoCategoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotoCategoryTable> {
  $$PhotoCategoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get photoId =>
      $composableBuilder(column: $table.photoId, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<DateTime> get assignedAt => $composableBuilder(
      column: $table.assignedAt, builder: (column) => column);
}

class $$PhotoCategoryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PhotoCategoryTable,
    PhotoCategoryRow,
    $$PhotoCategoryTableFilterComposer,
    $$PhotoCategoryTableOrderingComposer,
    $$PhotoCategoryTableAnnotationComposer,
    $$PhotoCategoryTableCreateCompanionBuilder,
    $$PhotoCategoryTableUpdateCompanionBuilder,
    (
      PhotoCategoryRow,
      BaseReferences<_$AppDatabase, $PhotoCategoryTable, PhotoCategoryRow>
    ),
    PhotoCategoryRow,
    PrefetchHooks Function()> {
  $$PhotoCategoryTableTableManager(_$AppDatabase db, $PhotoCategoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoCategoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoCategoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoCategoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> photoId = const Value.absent(),
            Value<int> categoryId = const Value.absent(),
            Value<DateTime> assignedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PhotoCategoryCompanion(
            photoId: photoId,
            categoryId: categoryId,
            assignedAt: assignedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int photoId,
            required int categoryId,
            required DateTime assignedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PhotoCategoryCompanion.insert(
            photoId: photoId,
            categoryId: categoryId,
            assignedAt: assignedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PhotoCategoryTable, PhotoCategoryRow>(table),
                    BaseReferences<_$AppDatabase, $PhotoCategoryTable,
                        PhotoCategoryRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PhotoCategoryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PhotoCategoryTable,
    PhotoCategoryRow,
    $$PhotoCategoryTableFilterComposer,
    $$PhotoCategoryTableOrderingComposer,
    $$PhotoCategoryTableAnnotationComposer,
    $$PhotoCategoryTableCreateCompanionBuilder,
    $$PhotoCategoryTableUpdateCompanionBuilder,
    (
      PhotoCategoryRow,
      BaseReferences<_$AppDatabase, $PhotoCategoryTable, PhotoCategoryRow>
    ),
    PhotoCategoryRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db, _db.photos);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$PhotoCategoryTableTableManager get photoCategory =>
      $$PhotoCategoryTableTableManager(_db, _db.photoCategory);
}
