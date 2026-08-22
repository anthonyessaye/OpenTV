// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SourcesTable extends Sources with TableInfo<$SourcesTable, Source> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SourceKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SourceKind>($SourcesTable.$converterkind);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _credentialRefMeta = const VerificationMeta(
    'credentialRef',
  );
  @override
  late final GeneratedColumn<String> credentialRef = GeneratedColumn<String>(
    'credential_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _epgUrlMeta = const VerificationMeta('epgUrl');
  @override
  late final GeneratedColumn<String> epgUrl = GeneratedColumn<String>(
    'epg_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    url,
    username,
    credentialRef,
    epgUrl,
    enabled,
    sortOrder,
    lastSyncedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<Source> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('credential_ref')) {
      context.handle(
        _credentialRefMeta,
        credentialRef.isAcceptableOrUnknown(
          data['credential_ref']!,
          _credentialRefMeta,
        ),
      );
    }
    if (data.containsKey('epg_url')) {
      context.handle(
        _epgUrlMeta,
        epgUrl.isAcceptableOrUnknown(data['epg_url']!, _epgUrlMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Source map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Source(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: $SourcesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      credentialRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_ref'],
      ),
      epgUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_url'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SourcesTable createAlias(String alias) {
    return $SourcesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SourceKind, String, String> $converterkind =
      const EnumNameConverter<SourceKind>(SourceKind.values);
}

class Source extends DataClass implements Insertable<Source> {
  final int id;
  final String name;
  final SourceKind kind;

  /// Portal origin for [SourceKind.xtream], playlist URL for
  /// [SourceKind.m3u].
  final String url;
  final String? username;

  /// Keystore handle for the secret. Never the secret itself.
  final String? credentialRef;

  /// XMLTV guide URL. For M3U sources this comes from the playlist header's
  /// `url-tvg`; for Xtream it is the portal's own `xmltv.php`.
  final String? epgUrl;
  final bool enabled;
  final int sortOrder;
  final DateTime? lastSyncedAt;
  final DateTime createdAt;
  const Source({
    required this.id,
    required this.name,
    required this.kind,
    required this.url,
    this.username,
    this.credentialRef,
    this.epgUrl,
    required this.enabled,
    required this.sortOrder,
    this.lastSyncedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['kind'] = Variable<String>($SourcesTable.$converterkind.toSql(kind));
    }
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || credentialRef != null) {
      map['credential_ref'] = Variable<String>(credentialRef);
    }
    if (!nullToAbsent || epgUrl != null) {
      map['epg_url'] = Variable<String>(epgUrl);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      url: Value(url),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      credentialRef: credentialRef == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialRef),
      epgUrl: epgUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(epgUrl),
      enabled: Value(enabled),
      sortOrder: Value(sortOrder),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      createdAt: Value(createdAt),
    );
  }

  factory Source.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Source(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: $SourcesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      url: serializer.fromJson<String>(json['url']),
      username: serializer.fromJson<String?>(json['username']),
      credentialRef: serializer.fromJson<String?>(json['credentialRef']),
      epgUrl: serializer.fromJson<String?>(json['epgUrl']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(
        $SourcesTable.$converterkind.toJson(kind),
      ),
      'url': serializer.toJson<String>(url),
      'username': serializer.toJson<String?>(username),
      'credentialRef': serializer.toJson<String?>(credentialRef),
      'epgUrl': serializer.toJson<String?>(epgUrl),
      'enabled': serializer.toJson<bool>(enabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Source copyWith({
    int? id,
    String? name,
    SourceKind? kind,
    String? url,
    Value<String?> username = const Value.absent(),
    Value<String?> credentialRef = const Value.absent(),
    Value<String?> epgUrl = const Value.absent(),
    bool? enabled,
    int? sortOrder,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    DateTime? createdAt,
  }) => Source(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    url: url ?? this.url,
    username: username.present ? username.value : this.username,
    credentialRef: credentialRef.present
        ? credentialRef.value
        : this.credentialRef,
    epgUrl: epgUrl.present ? epgUrl.value : this.epgUrl,
    enabled: enabled ?? this.enabled,
    sortOrder: sortOrder ?? this.sortOrder,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Source copyWithCompanion(SourcesCompanion data) {
    return Source(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      url: data.url.present ? data.url.value : this.url,
      username: data.username.present ? data.username.value : this.username,
      credentialRef: data.credentialRef.present
          ? data.credentialRef.value
          : this.credentialRef,
      epgUrl: data.epgUrl.present ? data.epgUrl.value : this.epgUrl,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Source(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('url: $url, ')
          ..write('username: $username, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('epgUrl: $epgUrl, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    url,
    username,
    credentialRef,
    epgUrl,
    enabled,
    sortOrder,
    lastSyncedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Source &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.url == this.url &&
          other.username == this.username &&
          other.credentialRef == this.credentialRef &&
          other.epgUrl == this.epgUrl &&
          other.enabled == this.enabled &&
          other.sortOrder == this.sortOrder &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.createdAt == this.createdAt);
}

class SourcesCompanion extends UpdateCompanion<Source> {
  final Value<int> id;
  final Value<String> name;
  final Value<SourceKind> kind;
  final Value<String> url;
  final Value<String?> username;
  final Value<String?> credentialRef;
  final Value<String?> epgUrl;
  final Value<bool> enabled;
  final Value<int> sortOrder;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime> createdAt;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.url = const Value.absent(),
    this.username = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.epgUrl = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SourcesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required SourceKind kind,
    required String url,
    this.username = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.epgUrl = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       kind = Value(kind),
       url = Value(url),
       createdAt = Value(createdAt);
  static Insertable<Source> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? url,
    Expression<String>? username,
    Expression<String>? credentialRef,
    Expression<String>? epgUrl,
    Expression<bool>? enabled,
    Expression<int>? sortOrder,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (url != null) 'url': url,
      if (username != null) 'username': username,
      if (credentialRef != null) 'credential_ref': credentialRef,
      if (epgUrl != null) 'epg_url': epgUrl,
      if (enabled != null) 'enabled': enabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SourcesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<SourceKind>? kind,
    Value<String>? url,
    Value<String?>? username,
    Value<String?>? credentialRef,
    Value<String?>? epgUrl,
    Value<bool>? enabled,
    Value<int>? sortOrder,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime>? createdAt,
  }) {
    return SourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      url: url ?? this.url,
      username: username ?? this.username,
      credentialRef: credentialRef ?? this.credentialRef,
      epgUrl: epgUrl ?? this.epgUrl,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (kind.present) {
      map['kind'] = Variable<String>(
        $SourcesTable.$converterkind.toSql(kind.value),
      );
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (credentialRef.present) {
      map['credential_ref'] = Variable<String>(credentialRef.value);
    }
    if (epgUrl.present) {
      map['epg_url'] = Variable<String>(epgUrl.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('url: $url, ')
          ..write('username: $username, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('epgUrl: $epgUrl, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ItemKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ItemKind>($CategoriesTable.$converterkind);
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    remoteId,
    name,
    kind,
    sortOrder,
    hidden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, kind, remoteId};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: $CategoriesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemKind, String, String> $converterkind =
      const EnumNameConverter<ItemKind>(ItemKind.values);
}

class Category extends DataClass implements Insertable<Category> {
  final int sourceId;

  /// The provider's own id. Not unique across sources, hence the pairing.
  final String remoteId;
  final String name;
  final ItemKind kind;
  final int sortOrder;

  /// Hidden categories stay in the database so a later sync does not have to
  /// refetch them, but are filtered out of the interface.
  final bool hidden;
  const Category({
    required this.sourceId,
    required this.remoteId,
    required this.name,
    required this.kind,
    required this.sortOrder,
    required this.hidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<int>(sourceId);
    map['remote_id'] = Variable<String>(remoteId);
    map['name'] = Variable<String>(name);
    {
      map['kind'] = Variable<String>(
        $CategoriesTable.$converterkind.toSql(kind),
      );
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['hidden'] = Variable<bool>(hidden);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      sourceId: Value(sourceId),
      remoteId: Value(remoteId),
      name: Value(name),
      kind: Value(kind),
      sortOrder: Value(sortOrder),
      hidden: Value(hidden),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      sourceId: serializer.fromJson<int>(json['sourceId']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      name: serializer.fromJson<String>(json['name']),
      kind: $CategoriesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      hidden: serializer.fromJson<bool>(json['hidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<int>(sourceId),
      'remoteId': serializer.toJson<String>(remoteId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(
        $CategoriesTable.$converterkind.toJson(kind),
      ),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'hidden': serializer.toJson<bool>(hidden),
    };
  }

  Category copyWith({
    int? sourceId,
    String? remoteId,
    String? name,
    ItemKind? kind,
    int? sortOrder,
    bool? hidden,
  }) => Category(
    sourceId: sourceId ?? this.sourceId,
    remoteId: remoteId ?? this.remoteId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    sortOrder: sortOrder ?? this.sortOrder,
    hidden: hidden ?? this.hidden,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('hidden: $hidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sourceId, remoteId, name, kind, sortOrder, hidden);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.sourceId == this.sourceId &&
          other.remoteId == this.remoteId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.sortOrder == this.sortOrder &&
          other.hidden == this.hidden);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> sourceId;
  final Value<String> remoteId;
  final Value<String> name;
  final Value<ItemKind> kind;
  final Value<int> sortOrder;
  final Value<bool> hidden;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.sourceId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required int sourceId,
    required String remoteId,
    required String name,
    required ItemKind kind,
    this.sortOrder = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       remoteId = Value(remoteId),
       name = Value(name),
       kind = Value(kind);
  static Insertable<Category> custom({
    Expression<int>? sourceId,
    Expression<String>? remoteId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<int>? sortOrder,
    Expression<bool>? hidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (remoteId != null) 'remote_id': remoteId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (hidden != null) 'hidden': hidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? sourceId,
    Value<String>? remoteId,
    Value<String>? name,
    Value<ItemKind>? kind,
    Value<int>? sortOrder,
    Value<bool>? hidden,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      sourceId: sourceId ?? this.sourceId,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      sortOrder: sortOrder ?? this.sortOrder,
      hidden: hidden ?? this.hidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CategoriesTable.$converterkind.toSql(kind.value),
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('hidden: $hidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChannelsTable extends Channels with TableInfo<$ChannelsTable, Channel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchNameMeta = const VerificationMeta(
    'searchName',
  );
  @override
  late final GeneratedColumn<String> searchName = GeneratedColumn<String>(
    'search_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconUrlMeta = const VerificationMeta(
    'iconUrl',
  );
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
    'icon_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryRemoteIdMeta = const VerificationMeta(
    'categoryRemoteId',
  );
  @override
  late final GeneratedColumn<String> categoryRemoteId = GeneratedColumn<String>(
    'category_remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _epgChannelIdMeta = const VerificationMeta(
    'epgChannelId',
  );
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
    'epg_channel_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasArchiveMeta = const VerificationMeta(
    'hasArchive',
  );
  @override
  late final GeneratedColumn<bool> hasArchive = GeneratedColumn<bool>(
    'has_archive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_archive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archiveDaysMeta = const VerificationMeta(
    'archiveDays',
  );
  @override
  late final GeneratedColumn<int> archiveDays = GeneratedColumn<int>(
    'archive_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _streamOptionsMeta = const VerificationMeta(
    'streamOptions',
  );
  @override
  late final GeneratedColumn<String> streamOptions = GeneratedColumn<String>(
    'stream_options',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directUrlMeta = const VerificationMeta(
    'directUrl',
  );
  @override
  late final GeneratedColumn<String> directUrl = GeneratedColumn<String>(
    'direct_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    remoteId,
    name,
    searchName,
    iconUrl,
    categoryRemoteId,
    epgChannelId,
    number,
    hasArchive,
    archiveDays,
    addedAt,
    hidden,
    streamOptions,
    directUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<Channel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('search_name')) {
      context.handle(
        _searchNameMeta,
        searchName.isAcceptableOrUnknown(data['search_name']!, _searchNameMeta),
      );
    } else if (isInserting) {
      context.missing(_searchNameMeta);
    }
    if (data.containsKey('icon_url')) {
      context.handle(
        _iconUrlMeta,
        iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta),
      );
    }
    if (data.containsKey('category_remote_id')) {
      context.handle(
        _categoryRemoteIdMeta,
        categoryRemoteId.isAcceptableOrUnknown(
          data['category_remote_id']!,
          _categoryRemoteIdMeta,
        ),
      );
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
        _epgChannelIdMeta,
        epgChannelId.isAcceptableOrUnknown(
          data['epg_channel_id']!,
          _epgChannelIdMeta,
        ),
      );
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    }
    if (data.containsKey('has_archive')) {
      context.handle(
        _hasArchiveMeta,
        hasArchive.isAcceptableOrUnknown(data['has_archive']!, _hasArchiveMeta),
      );
    }
    if (data.containsKey('archive_days')) {
      context.handle(
        _archiveDaysMeta,
        archiveDays.isAcceptableOrUnknown(
          data['archive_days']!,
          _archiveDaysMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('stream_options')) {
      context.handle(
        _streamOptionsMeta,
        streamOptions.isAcceptableOrUnknown(
          data['stream_options']!,
          _streamOptionsMeta,
        ),
      );
    }
    if (data.containsKey('direct_url')) {
      context.handle(
        _directUrlMeta,
        directUrl.isAcceptableOrUnknown(data['direct_url']!, _directUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, remoteId};
  @override
  Channel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Channel(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      searchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_name'],
      )!,
      iconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_url'],
      ),
      categoryRemoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_remote_id'],
      ),
      epgChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_channel_id'],
      ),
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      ),
      hasArchive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_archive'],
      )!,
      archiveDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archive_days'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      ),
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      streamOptions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_options'],
      ),
      directUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direct_url'],
      ),
    );
  }

  @override
  $ChannelsTable createAlias(String alias) {
    return $ChannelsTable(attachedDatabase, alias);
  }
}

class Channel extends DataClass implements Insertable<Channel> {
  final int sourceId;
  final String remoteId;
  final String name;

  /// Lower-cased, punctuation-stripped [name]. Indexed, so search is a range
  /// scan rather than the full table scan the Android app was doing.
  final String searchName;
  final String? iconUrl;
  final String? categoryRemoteId;

  /// Joins to `EpgChannels.channelId`. A channel without one shows no guide.
  final String? epgChannelId;
  final int? number;
  final bool hasArchive;
  final int? archiveDays;
  final DateTime? addedAt;
  final bool hidden;

  /// Stream URL directives the playlist attached, as JSON. Carries the user
  /// agent and referrer some providers require in order to serve at all.
  final String? streamOptions;

  /// Present for M3U sources, which give an absolute URL per entry. Null for
  /// Xtream, where the URL is derived from credentials at playback time and
  /// so must not be persisted.
  final String? directUrl;
  const Channel({
    required this.sourceId,
    required this.remoteId,
    required this.name,
    required this.searchName,
    this.iconUrl,
    this.categoryRemoteId,
    this.epgChannelId,
    this.number,
    required this.hasArchive,
    this.archiveDays,
    this.addedAt,
    required this.hidden,
    this.streamOptions,
    this.directUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<int>(sourceId);
    map['remote_id'] = Variable<String>(remoteId);
    map['name'] = Variable<String>(name);
    map['search_name'] = Variable<String>(searchName);
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    if (!nullToAbsent || categoryRemoteId != null) {
      map['category_remote_id'] = Variable<String>(categoryRemoteId);
    }
    if (!nullToAbsent || epgChannelId != null) {
      map['epg_channel_id'] = Variable<String>(epgChannelId);
    }
    if (!nullToAbsent || number != null) {
      map['number'] = Variable<int>(number);
    }
    map['has_archive'] = Variable<bool>(hasArchive);
    if (!nullToAbsent || archiveDays != null) {
      map['archive_days'] = Variable<int>(archiveDays);
    }
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<DateTime>(addedAt);
    }
    map['hidden'] = Variable<bool>(hidden);
    if (!nullToAbsent || streamOptions != null) {
      map['stream_options'] = Variable<String>(streamOptions);
    }
    if (!nullToAbsent || directUrl != null) {
      map['direct_url'] = Variable<String>(directUrl);
    }
    return map;
  }

  ChannelsCompanion toCompanion(bool nullToAbsent) {
    return ChannelsCompanion(
      sourceId: Value(sourceId),
      remoteId: Value(remoteId),
      name: Value(name),
      searchName: Value(searchName),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
      categoryRemoteId: categoryRemoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryRemoteId),
      epgChannelId: epgChannelId == null && nullToAbsent
          ? const Value.absent()
          : Value(epgChannelId),
      number: number == null && nullToAbsent
          ? const Value.absent()
          : Value(number),
      hasArchive: Value(hasArchive),
      archiveDays: archiveDays == null && nullToAbsent
          ? const Value.absent()
          : Value(archiveDays),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
      hidden: Value(hidden),
      streamOptions: streamOptions == null && nullToAbsent
          ? const Value.absent()
          : Value(streamOptions),
      directUrl: directUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(directUrl),
    );
  }

  factory Channel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Channel(
      sourceId: serializer.fromJson<int>(json['sourceId']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      name: serializer.fromJson<String>(json['name']),
      searchName: serializer.fromJson<String>(json['searchName']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
      categoryRemoteId: serializer.fromJson<String?>(json['categoryRemoteId']),
      epgChannelId: serializer.fromJson<String?>(json['epgChannelId']),
      number: serializer.fromJson<int?>(json['number']),
      hasArchive: serializer.fromJson<bool>(json['hasArchive']),
      archiveDays: serializer.fromJson<int?>(json['archiveDays']),
      addedAt: serializer.fromJson<DateTime?>(json['addedAt']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      streamOptions: serializer.fromJson<String?>(json['streamOptions']),
      directUrl: serializer.fromJson<String?>(json['directUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<int>(sourceId),
      'remoteId': serializer.toJson<String>(remoteId),
      'name': serializer.toJson<String>(name),
      'searchName': serializer.toJson<String>(searchName),
      'iconUrl': serializer.toJson<String?>(iconUrl),
      'categoryRemoteId': serializer.toJson<String?>(categoryRemoteId),
      'epgChannelId': serializer.toJson<String?>(epgChannelId),
      'number': serializer.toJson<int?>(number),
      'hasArchive': serializer.toJson<bool>(hasArchive),
      'archiveDays': serializer.toJson<int?>(archiveDays),
      'addedAt': serializer.toJson<DateTime?>(addedAt),
      'hidden': serializer.toJson<bool>(hidden),
      'streamOptions': serializer.toJson<String?>(streamOptions),
      'directUrl': serializer.toJson<String?>(directUrl),
    };
  }

  Channel copyWith({
    int? sourceId,
    String? remoteId,
    String? name,
    String? searchName,
    Value<String?> iconUrl = const Value.absent(),
    Value<String?> categoryRemoteId = const Value.absent(),
    Value<String?> epgChannelId = const Value.absent(),
    Value<int?> number = const Value.absent(),
    bool? hasArchive,
    Value<int?> archiveDays = const Value.absent(),
    Value<DateTime?> addedAt = const Value.absent(),
    bool? hidden,
    Value<String?> streamOptions = const Value.absent(),
    Value<String?> directUrl = const Value.absent(),
  }) => Channel(
    sourceId: sourceId ?? this.sourceId,
    remoteId: remoteId ?? this.remoteId,
    name: name ?? this.name,
    searchName: searchName ?? this.searchName,
    iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
    categoryRemoteId: categoryRemoteId.present
        ? categoryRemoteId.value
        : this.categoryRemoteId,
    epgChannelId: epgChannelId.present ? epgChannelId.value : this.epgChannelId,
    number: number.present ? number.value : this.number,
    hasArchive: hasArchive ?? this.hasArchive,
    archiveDays: archiveDays.present ? archiveDays.value : this.archiveDays,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
    hidden: hidden ?? this.hidden,
    streamOptions: streamOptions.present
        ? streamOptions.value
        : this.streamOptions,
    directUrl: directUrl.present ? directUrl.value : this.directUrl,
  );
  Channel copyWithCompanion(ChannelsCompanion data) {
    return Channel(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      name: data.name.present ? data.name.value : this.name,
      searchName: data.searchName.present
          ? data.searchName.value
          : this.searchName,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      categoryRemoteId: data.categoryRemoteId.present
          ? data.categoryRemoteId.value
          : this.categoryRemoteId,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      number: data.number.present ? data.number.value : this.number,
      hasArchive: data.hasArchive.present
          ? data.hasArchive.value
          : this.hasArchive,
      archiveDays: data.archiveDays.present
          ? data.archiveDays.value
          : this.archiveDays,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      streamOptions: data.streamOptions.present
          ? data.streamOptions.value
          : this.streamOptions,
      directUrl: data.directUrl.present ? data.directUrl.value : this.directUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Channel(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('searchName: $searchName, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('categoryRemoteId: $categoryRemoteId, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('number: $number, ')
          ..write('hasArchive: $hasArchive, ')
          ..write('archiveDays: $archiveDays, ')
          ..write('addedAt: $addedAt, ')
          ..write('hidden: $hidden, ')
          ..write('streamOptions: $streamOptions, ')
          ..write('directUrl: $directUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    remoteId,
    name,
    searchName,
    iconUrl,
    categoryRemoteId,
    epgChannelId,
    number,
    hasArchive,
    archiveDays,
    addedAt,
    hidden,
    streamOptions,
    directUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Channel &&
          other.sourceId == this.sourceId &&
          other.remoteId == this.remoteId &&
          other.name == this.name &&
          other.searchName == this.searchName &&
          other.iconUrl == this.iconUrl &&
          other.categoryRemoteId == this.categoryRemoteId &&
          other.epgChannelId == this.epgChannelId &&
          other.number == this.number &&
          other.hasArchive == this.hasArchive &&
          other.archiveDays == this.archiveDays &&
          other.addedAt == this.addedAt &&
          other.hidden == this.hidden &&
          other.streamOptions == this.streamOptions &&
          other.directUrl == this.directUrl);
}

class ChannelsCompanion extends UpdateCompanion<Channel> {
  final Value<int> sourceId;
  final Value<String> remoteId;
  final Value<String> name;
  final Value<String> searchName;
  final Value<String?> iconUrl;
  final Value<String?> categoryRemoteId;
  final Value<String?> epgChannelId;
  final Value<int?> number;
  final Value<bool> hasArchive;
  final Value<int?> archiveDays;
  final Value<DateTime?> addedAt;
  final Value<bool> hidden;
  final Value<String?> streamOptions;
  final Value<String?> directUrl;
  final Value<int> rowid;
  const ChannelsCompanion({
    this.sourceId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.name = const Value.absent(),
    this.searchName = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.categoryRemoteId = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.number = const Value.absent(),
    this.hasArchive = const Value.absent(),
    this.archiveDays = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.hidden = const Value.absent(),
    this.streamOptions = const Value.absent(),
    this.directUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChannelsCompanion.insert({
    required int sourceId,
    required String remoteId,
    required String name,
    required String searchName,
    this.iconUrl = const Value.absent(),
    this.categoryRemoteId = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.number = const Value.absent(),
    this.hasArchive = const Value.absent(),
    this.archiveDays = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.hidden = const Value.absent(),
    this.streamOptions = const Value.absent(),
    this.directUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       remoteId = Value(remoteId),
       name = Value(name),
       searchName = Value(searchName);
  static Insertable<Channel> custom({
    Expression<int>? sourceId,
    Expression<String>? remoteId,
    Expression<String>? name,
    Expression<String>? searchName,
    Expression<String>? iconUrl,
    Expression<String>? categoryRemoteId,
    Expression<String>? epgChannelId,
    Expression<int>? number,
    Expression<bool>? hasArchive,
    Expression<int>? archiveDays,
    Expression<DateTime>? addedAt,
    Expression<bool>? hidden,
    Expression<String>? streamOptions,
    Expression<String>? directUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (remoteId != null) 'remote_id': remoteId,
      if (name != null) 'name': name,
      if (searchName != null) 'search_name': searchName,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (categoryRemoteId != null) 'category_remote_id': categoryRemoteId,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (number != null) 'number': number,
      if (hasArchive != null) 'has_archive': hasArchive,
      if (archiveDays != null) 'archive_days': archiveDays,
      if (addedAt != null) 'added_at': addedAt,
      if (hidden != null) 'hidden': hidden,
      if (streamOptions != null) 'stream_options': streamOptions,
      if (directUrl != null) 'direct_url': directUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChannelsCompanion copyWith({
    Value<int>? sourceId,
    Value<String>? remoteId,
    Value<String>? name,
    Value<String>? searchName,
    Value<String?>? iconUrl,
    Value<String?>? categoryRemoteId,
    Value<String?>? epgChannelId,
    Value<int?>? number,
    Value<bool>? hasArchive,
    Value<int?>? archiveDays,
    Value<DateTime?>? addedAt,
    Value<bool>? hidden,
    Value<String?>? streamOptions,
    Value<String?>? directUrl,
    Value<int>? rowid,
  }) {
    return ChannelsCompanion(
      sourceId: sourceId ?? this.sourceId,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      searchName: searchName ?? this.searchName,
      iconUrl: iconUrl ?? this.iconUrl,
      categoryRemoteId: categoryRemoteId ?? this.categoryRemoteId,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      number: number ?? this.number,
      hasArchive: hasArchive ?? this.hasArchive,
      archiveDays: archiveDays ?? this.archiveDays,
      addedAt: addedAt ?? this.addedAt,
      hidden: hidden ?? this.hidden,
      streamOptions: streamOptions ?? this.streamOptions,
      directUrl: directUrl ?? this.directUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (searchName.present) {
      map['search_name'] = Variable<String>(searchName.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (categoryRemoteId.present) {
      map['category_remote_id'] = Variable<String>(categoryRemoteId.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (hasArchive.present) {
      map['has_archive'] = Variable<bool>(hasArchive.value);
    }
    if (archiveDays.present) {
      map['archive_days'] = Variable<int>(archiveDays.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (streamOptions.present) {
      map['stream_options'] = Variable<String>(streamOptions.value);
    }
    if (directUrl.present) {
      map['direct_url'] = Variable<String>(directUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('searchName: $searchName, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('categoryRemoteId: $categoryRemoteId, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('number: $number, ')
          ..write('hasArchive: $hasArchive, ')
          ..write('archiveDays: $archiveDays, ')
          ..write('addedAt: $addedAt, ')
          ..write('hidden: $hidden, ')
          ..write('streamOptions: $streamOptions, ')
          ..write('directUrl: $directUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MoviesTable extends Movies with TableInfo<$MoviesTable, Movie> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoviesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchNameMeta = const VerificationMeta(
    'searchName',
  );
  @override
  late final GeneratedColumn<String> searchName = GeneratedColumn<String>(
    'search_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconUrlMeta = const VerificationMeta(
    'iconUrl',
  );
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
    'icon_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryRemoteIdMeta = const VerificationMeta(
    'categoryRemoteId',
  );
  @override
  late final GeneratedColumn<String> categoryRemoteId = GeneratedColumn<String>(
    'category_remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _containerExtensionMeta =
      const VerificationMeta('containerExtension');
  @override
  late final GeneratedColumn<String> containerExtension =
      GeneratedColumn<String>(
        'container_extension',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<String> tmdbId = GeneratedColumn<String>(
    'tmdb_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _streamOptionsMeta = const VerificationMeta(
    'streamOptions',
  );
  @override
  late final GeneratedColumn<String> streamOptions = GeneratedColumn<String>(
    'stream_options',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directUrlMeta = const VerificationMeta(
    'directUrl',
  );
  @override
  late final GeneratedColumn<String> directUrl = GeneratedColumn<String>(
    'direct_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    remoteId,
    name,
    searchName,
    iconUrl,
    categoryRemoteId,
    containerExtension,
    rating,
    addedAt,
    tmdbId,
    hidden,
    streamOptions,
    directUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'movies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Movie> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('search_name')) {
      context.handle(
        _searchNameMeta,
        searchName.isAcceptableOrUnknown(data['search_name']!, _searchNameMeta),
      );
    } else if (isInserting) {
      context.missing(_searchNameMeta);
    }
    if (data.containsKey('icon_url')) {
      context.handle(
        _iconUrlMeta,
        iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta),
      );
    }
    if (data.containsKey('category_remote_id')) {
      context.handle(
        _categoryRemoteIdMeta,
        categoryRemoteId.isAcceptableOrUnknown(
          data['category_remote_id']!,
          _categoryRemoteIdMeta,
        ),
      );
    }
    if (data.containsKey('container_extension')) {
      context.handle(
        _containerExtensionMeta,
        containerExtension.isAcceptableOrUnknown(
          data['container_extension']!,
          _containerExtensionMeta,
        ),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('stream_options')) {
      context.handle(
        _streamOptionsMeta,
        streamOptions.isAcceptableOrUnknown(
          data['stream_options']!,
          _streamOptionsMeta,
        ),
      );
    }
    if (data.containsKey('direct_url')) {
      context.handle(
        _directUrlMeta,
        directUrl.isAcceptableOrUnknown(data['direct_url']!, _directUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, remoteId};
  @override
  Movie map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Movie(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      searchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_name'],
      )!,
      iconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_url'],
      ),
      categoryRemoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_remote_id'],
      ),
      containerExtension: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}container_extension'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      ),
      tmdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tmdb_id'],
      ),
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      streamOptions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_options'],
      ),
      directUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direct_url'],
      ),
    );
  }

  @override
  $MoviesTable createAlias(String alias) {
    return $MoviesTable(attachedDatabase, alias);
  }
}

class Movie extends DataClass implements Insertable<Movie> {
  final int sourceId;
  final String remoteId;
  final String name;
  final String searchName;
  final String? iconUrl;
  final String? categoryRemoteId;

  /// Needed to build a playable URL. Null means incomplete catalogue data.
  final String? containerExtension;
  final double? rating;
  final DateTime? addedAt;
  final String? tmdbId;
  final bool hidden;
  final String? streamOptions;
  final String? directUrl;
  const Movie({
    required this.sourceId,
    required this.remoteId,
    required this.name,
    required this.searchName,
    this.iconUrl,
    this.categoryRemoteId,
    this.containerExtension,
    this.rating,
    this.addedAt,
    this.tmdbId,
    required this.hidden,
    this.streamOptions,
    this.directUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<int>(sourceId);
    map['remote_id'] = Variable<String>(remoteId);
    map['name'] = Variable<String>(name);
    map['search_name'] = Variable<String>(searchName);
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    if (!nullToAbsent || categoryRemoteId != null) {
      map['category_remote_id'] = Variable<String>(categoryRemoteId);
    }
    if (!nullToAbsent || containerExtension != null) {
      map['container_extension'] = Variable<String>(containerExtension);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<DateTime>(addedAt);
    }
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<String>(tmdbId);
    }
    map['hidden'] = Variable<bool>(hidden);
    if (!nullToAbsent || streamOptions != null) {
      map['stream_options'] = Variable<String>(streamOptions);
    }
    if (!nullToAbsent || directUrl != null) {
      map['direct_url'] = Variable<String>(directUrl);
    }
    return map;
  }

  MoviesCompanion toCompanion(bool nullToAbsent) {
    return MoviesCompanion(
      sourceId: Value(sourceId),
      remoteId: Value(remoteId),
      name: Value(name),
      searchName: Value(searchName),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
      categoryRemoteId: categoryRemoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryRemoteId),
      containerExtension: containerExtension == null && nullToAbsent
          ? const Value.absent()
          : Value(containerExtension),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
      tmdbId: tmdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbId),
      hidden: Value(hidden),
      streamOptions: streamOptions == null && nullToAbsent
          ? const Value.absent()
          : Value(streamOptions),
      directUrl: directUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(directUrl),
    );
  }

  factory Movie.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Movie(
      sourceId: serializer.fromJson<int>(json['sourceId']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      name: serializer.fromJson<String>(json['name']),
      searchName: serializer.fromJson<String>(json['searchName']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
      categoryRemoteId: serializer.fromJson<String?>(json['categoryRemoteId']),
      containerExtension: serializer.fromJson<String?>(
        json['containerExtension'],
      ),
      rating: serializer.fromJson<double?>(json['rating']),
      addedAt: serializer.fromJson<DateTime?>(json['addedAt']),
      tmdbId: serializer.fromJson<String?>(json['tmdbId']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      streamOptions: serializer.fromJson<String?>(json['streamOptions']),
      directUrl: serializer.fromJson<String?>(json['directUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<int>(sourceId),
      'remoteId': serializer.toJson<String>(remoteId),
      'name': serializer.toJson<String>(name),
      'searchName': serializer.toJson<String>(searchName),
      'iconUrl': serializer.toJson<String?>(iconUrl),
      'categoryRemoteId': serializer.toJson<String?>(categoryRemoteId),
      'containerExtension': serializer.toJson<String?>(containerExtension),
      'rating': serializer.toJson<double?>(rating),
      'addedAt': serializer.toJson<DateTime?>(addedAt),
      'tmdbId': serializer.toJson<String?>(tmdbId),
      'hidden': serializer.toJson<bool>(hidden),
      'streamOptions': serializer.toJson<String?>(streamOptions),
      'directUrl': serializer.toJson<String?>(directUrl),
    };
  }

  Movie copyWith({
    int? sourceId,
    String? remoteId,
    String? name,
    String? searchName,
    Value<String?> iconUrl = const Value.absent(),
    Value<String?> categoryRemoteId = const Value.absent(),
    Value<String?> containerExtension = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<DateTime?> addedAt = const Value.absent(),
    Value<String?> tmdbId = const Value.absent(),
    bool? hidden,
    Value<String?> streamOptions = const Value.absent(),
    Value<String?> directUrl = const Value.absent(),
  }) => Movie(
    sourceId: sourceId ?? this.sourceId,
    remoteId: remoteId ?? this.remoteId,
    name: name ?? this.name,
    searchName: searchName ?? this.searchName,
    iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
    categoryRemoteId: categoryRemoteId.present
        ? categoryRemoteId.value
        : this.categoryRemoteId,
    containerExtension: containerExtension.present
        ? containerExtension.value
        : this.containerExtension,
    rating: rating.present ? rating.value : this.rating,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
    tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
    hidden: hidden ?? this.hidden,
    streamOptions: streamOptions.present
        ? streamOptions.value
        : this.streamOptions,
    directUrl: directUrl.present ? directUrl.value : this.directUrl,
  );
  Movie copyWithCompanion(MoviesCompanion data) {
    return Movie(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      name: data.name.present ? data.name.value : this.name,
      searchName: data.searchName.present
          ? data.searchName.value
          : this.searchName,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      categoryRemoteId: data.categoryRemoteId.present
          ? data.categoryRemoteId.value
          : this.categoryRemoteId,
      containerExtension: data.containerExtension.present
          ? data.containerExtension.value
          : this.containerExtension,
      rating: data.rating.present ? data.rating.value : this.rating,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      streamOptions: data.streamOptions.present
          ? data.streamOptions.value
          : this.streamOptions,
      directUrl: data.directUrl.present ? data.directUrl.value : this.directUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Movie(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('searchName: $searchName, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('categoryRemoteId: $categoryRemoteId, ')
          ..write('containerExtension: $containerExtension, ')
          ..write('rating: $rating, ')
          ..write('addedAt: $addedAt, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('hidden: $hidden, ')
          ..write('streamOptions: $streamOptions, ')
          ..write('directUrl: $directUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    remoteId,
    name,
    searchName,
    iconUrl,
    categoryRemoteId,
    containerExtension,
    rating,
    addedAt,
    tmdbId,
    hidden,
    streamOptions,
    directUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Movie &&
          other.sourceId == this.sourceId &&
          other.remoteId == this.remoteId &&
          other.name == this.name &&
          other.searchName == this.searchName &&
          other.iconUrl == this.iconUrl &&
          other.categoryRemoteId == this.categoryRemoteId &&
          other.containerExtension == this.containerExtension &&
          other.rating == this.rating &&
          other.addedAt == this.addedAt &&
          other.tmdbId == this.tmdbId &&
          other.hidden == this.hidden &&
          other.streamOptions == this.streamOptions &&
          other.directUrl == this.directUrl);
}

class MoviesCompanion extends UpdateCompanion<Movie> {
  final Value<int> sourceId;
  final Value<String> remoteId;
  final Value<String> name;
  final Value<String> searchName;
  final Value<String?> iconUrl;
  final Value<String?> categoryRemoteId;
  final Value<String?> containerExtension;
  final Value<double?> rating;
  final Value<DateTime?> addedAt;
  final Value<String?> tmdbId;
  final Value<bool> hidden;
  final Value<String?> streamOptions;
  final Value<String?> directUrl;
  final Value<int> rowid;
  const MoviesCompanion({
    this.sourceId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.name = const Value.absent(),
    this.searchName = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.categoryRemoteId = const Value.absent(),
    this.containerExtension = const Value.absent(),
    this.rating = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.hidden = const Value.absent(),
    this.streamOptions = const Value.absent(),
    this.directUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MoviesCompanion.insert({
    required int sourceId,
    required String remoteId,
    required String name,
    required String searchName,
    this.iconUrl = const Value.absent(),
    this.categoryRemoteId = const Value.absent(),
    this.containerExtension = const Value.absent(),
    this.rating = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.hidden = const Value.absent(),
    this.streamOptions = const Value.absent(),
    this.directUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       remoteId = Value(remoteId),
       name = Value(name),
       searchName = Value(searchName);
  static Insertable<Movie> custom({
    Expression<int>? sourceId,
    Expression<String>? remoteId,
    Expression<String>? name,
    Expression<String>? searchName,
    Expression<String>? iconUrl,
    Expression<String>? categoryRemoteId,
    Expression<String>? containerExtension,
    Expression<double>? rating,
    Expression<DateTime>? addedAt,
    Expression<String>? tmdbId,
    Expression<bool>? hidden,
    Expression<String>? streamOptions,
    Expression<String>? directUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (remoteId != null) 'remote_id': remoteId,
      if (name != null) 'name': name,
      if (searchName != null) 'search_name': searchName,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (categoryRemoteId != null) 'category_remote_id': categoryRemoteId,
      if (containerExtension != null) 'container_extension': containerExtension,
      if (rating != null) 'rating': rating,
      if (addedAt != null) 'added_at': addedAt,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (hidden != null) 'hidden': hidden,
      if (streamOptions != null) 'stream_options': streamOptions,
      if (directUrl != null) 'direct_url': directUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MoviesCompanion copyWith({
    Value<int>? sourceId,
    Value<String>? remoteId,
    Value<String>? name,
    Value<String>? searchName,
    Value<String?>? iconUrl,
    Value<String?>? categoryRemoteId,
    Value<String?>? containerExtension,
    Value<double?>? rating,
    Value<DateTime?>? addedAt,
    Value<String?>? tmdbId,
    Value<bool>? hidden,
    Value<String?>? streamOptions,
    Value<String?>? directUrl,
    Value<int>? rowid,
  }) {
    return MoviesCompanion(
      sourceId: sourceId ?? this.sourceId,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      searchName: searchName ?? this.searchName,
      iconUrl: iconUrl ?? this.iconUrl,
      categoryRemoteId: categoryRemoteId ?? this.categoryRemoteId,
      containerExtension: containerExtension ?? this.containerExtension,
      rating: rating ?? this.rating,
      addedAt: addedAt ?? this.addedAt,
      tmdbId: tmdbId ?? this.tmdbId,
      hidden: hidden ?? this.hidden,
      streamOptions: streamOptions ?? this.streamOptions,
      directUrl: directUrl ?? this.directUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (searchName.present) {
      map['search_name'] = Variable<String>(searchName.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (categoryRemoteId.present) {
      map['category_remote_id'] = Variable<String>(categoryRemoteId.value);
    }
    if (containerExtension.present) {
      map['container_extension'] = Variable<String>(containerExtension.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<String>(tmdbId.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (streamOptions.present) {
      map['stream_options'] = Variable<String>(streamOptions.value);
    }
    if (directUrl.present) {
      map['direct_url'] = Variable<String>(directUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoviesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('searchName: $searchName, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('categoryRemoteId: $categoryRemoteId, ')
          ..write('containerExtension: $containerExtension, ')
          ..write('rating: $rating, ')
          ..write('addedAt: $addedAt, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('hidden: $hidden, ')
          ..write('streamOptions: $streamOptions, ')
          ..write('directUrl: $directUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesEntriesTable extends SeriesEntries
    with TableInfo<$SeriesEntriesTable, SeriesEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchNameMeta = const VerificationMeta(
    'searchName',
  );
  @override
  late final GeneratedColumn<String> searchName = GeneratedColumn<String>(
    'search_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryRemoteIdMeta = const VerificationMeta(
    'categoryRemoteId',
  );
  @override
  late final GeneratedColumn<String> categoryRemoteId = GeneratedColumn<String>(
    'category_remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _castListMeta = const VerificationMeta(
    'castList',
  );
  @override
  late final GeneratedColumn<String> castList = GeneratedColumn<String>(
    'cast_list',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genresMeta = const VerificationMeta('genres');
  @override
  late final GeneratedColumn<String> genres = GeneratedColumn<String>(
    'genres',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<String> releaseDate = GeneratedColumn<String>(
    'release_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<String> tmdbId = GeneratedColumn<String>(
    'tmdb_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
    'last_modified',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodesSyncedAtMeta = const VerificationMeta(
    'episodesSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> episodesSyncedAt =
      GeneratedColumn<DateTime>(
        'episodes_synced_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    remoteId,
    name,
    searchName,
    coverUrl,
    categoryRemoteId,
    plot,
    castList,
    genres,
    rating,
    releaseDate,
    tmdbId,
    lastModified,
    episodesSyncedAt,
    hidden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('search_name')) {
      context.handle(
        _searchNameMeta,
        searchName.isAcceptableOrUnknown(data['search_name']!, _searchNameMeta),
      );
    } else if (isInserting) {
      context.missing(_searchNameMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('category_remote_id')) {
      context.handle(
        _categoryRemoteIdMeta,
        categoryRemoteId.isAcceptableOrUnknown(
          data['category_remote_id']!,
          _categoryRemoteIdMeta,
        ),
      );
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('cast_list')) {
      context.handle(
        _castListMeta,
        castList.isAcceptableOrUnknown(data['cast_list']!, _castListMeta),
      );
    }
    if (data.containsKey('genres')) {
      context.handle(
        _genresMeta,
        genres.isAcceptableOrUnknown(data['genres']!, _genresMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    }
    if (data.containsKey('episodes_synced_at')) {
      context.handle(
        _episodesSyncedAtMeta,
        episodesSyncedAt.isAcceptableOrUnknown(
          data['episodes_synced_at']!,
          _episodesSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, remoteId};
  @override
  SeriesEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesEntry(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      searchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_name'],
      )!,
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      categoryRemoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_remote_id'],
      ),
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      castList: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cast_list'],
      ),
      genres: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genres'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}release_date'],
      ),
      tmdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tmdb_id'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified'],
      ),
      episodesSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}episodes_synced_at'],
      ),
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
    );
  }

  @override
  $SeriesEntriesTable createAlias(String alias) {
    return $SeriesEntriesTable(attachedDatabase, alias);
  }
}

class SeriesEntry extends DataClass implements Insertable<SeriesEntry> {
  final int sourceId;
  final String remoteId;
  final String name;
  final String searchName;
  final String? coverUrl;
  final String? categoryRemoteId;
  final String? plot;

  /// Comma-separated. Small enough that a join table would cost more than it
  /// saves at the sizes involved.
  final String? castList;
  final String? genres;
  final double? rating;

  /// Kept as text. Providers send YYYY-MM-DD, a bare year and free text
  /// alike, and normalising loses information the interface may want.
  final String? releaseDate;
  final String? tmdbId;
  final DateTime? lastModified;

  /// Null until the episode list has been fetched for this series.
  final DateTime? episodesSyncedAt;
  final bool hidden;
  const SeriesEntry({
    required this.sourceId,
    required this.remoteId,
    required this.name,
    required this.searchName,
    this.coverUrl,
    this.categoryRemoteId,
    this.plot,
    this.castList,
    this.genres,
    this.rating,
    this.releaseDate,
    this.tmdbId,
    this.lastModified,
    this.episodesSyncedAt,
    required this.hidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<int>(sourceId);
    map['remote_id'] = Variable<String>(remoteId);
    map['name'] = Variable<String>(name);
    map['search_name'] = Variable<String>(searchName);
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || categoryRemoteId != null) {
      map['category_remote_id'] = Variable<String>(categoryRemoteId);
    }
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || castList != null) {
      map['cast_list'] = Variable<String>(castList);
    }
    if (!nullToAbsent || genres != null) {
      map['genres'] = Variable<String>(genres);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<String>(releaseDate);
    }
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<String>(tmdbId);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<DateTime>(lastModified);
    }
    if (!nullToAbsent || episodesSyncedAt != null) {
      map['episodes_synced_at'] = Variable<DateTime>(episodesSyncedAt);
    }
    map['hidden'] = Variable<bool>(hidden);
    return map;
  }

  SeriesEntriesCompanion toCompanion(bool nullToAbsent) {
    return SeriesEntriesCompanion(
      sourceId: Value(sourceId),
      remoteId: Value(remoteId),
      name: Value(name),
      searchName: Value(searchName),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      categoryRemoteId: categoryRemoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryRemoteId),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      castList: castList == null && nullToAbsent
          ? const Value.absent()
          : Value(castList),
      genres: genres == null && nullToAbsent
          ? const Value.absent()
          : Value(genres),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      releaseDate: releaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseDate),
      tmdbId: tmdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbId),
      lastModified: lastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModified),
      episodesSyncedAt: episodesSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(episodesSyncedAt),
      hidden: Value(hidden),
    );
  }

  factory SeriesEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesEntry(
      sourceId: serializer.fromJson<int>(json['sourceId']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      name: serializer.fromJson<String>(json['name']),
      searchName: serializer.fromJson<String>(json['searchName']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      categoryRemoteId: serializer.fromJson<String?>(json['categoryRemoteId']),
      plot: serializer.fromJson<String?>(json['plot']),
      castList: serializer.fromJson<String?>(json['castList']),
      genres: serializer.fromJson<String?>(json['genres']),
      rating: serializer.fromJson<double?>(json['rating']),
      releaseDate: serializer.fromJson<String?>(json['releaseDate']),
      tmdbId: serializer.fromJson<String?>(json['tmdbId']),
      lastModified: serializer.fromJson<DateTime?>(json['lastModified']),
      episodesSyncedAt: serializer.fromJson<DateTime?>(
        json['episodesSyncedAt'],
      ),
      hidden: serializer.fromJson<bool>(json['hidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<int>(sourceId),
      'remoteId': serializer.toJson<String>(remoteId),
      'name': serializer.toJson<String>(name),
      'searchName': serializer.toJson<String>(searchName),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'categoryRemoteId': serializer.toJson<String?>(categoryRemoteId),
      'plot': serializer.toJson<String?>(plot),
      'castList': serializer.toJson<String?>(castList),
      'genres': serializer.toJson<String?>(genres),
      'rating': serializer.toJson<double?>(rating),
      'releaseDate': serializer.toJson<String?>(releaseDate),
      'tmdbId': serializer.toJson<String?>(tmdbId),
      'lastModified': serializer.toJson<DateTime?>(lastModified),
      'episodesSyncedAt': serializer.toJson<DateTime?>(episodesSyncedAt),
      'hidden': serializer.toJson<bool>(hidden),
    };
  }

  SeriesEntry copyWith({
    int? sourceId,
    String? remoteId,
    String? name,
    String? searchName,
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> categoryRemoteId = const Value.absent(),
    Value<String?> plot = const Value.absent(),
    Value<String?> castList = const Value.absent(),
    Value<String?> genres = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<String?> releaseDate = const Value.absent(),
    Value<String?> tmdbId = const Value.absent(),
    Value<DateTime?> lastModified = const Value.absent(),
    Value<DateTime?> episodesSyncedAt = const Value.absent(),
    bool? hidden,
  }) => SeriesEntry(
    sourceId: sourceId ?? this.sourceId,
    remoteId: remoteId ?? this.remoteId,
    name: name ?? this.name,
    searchName: searchName ?? this.searchName,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    categoryRemoteId: categoryRemoteId.present
        ? categoryRemoteId.value
        : this.categoryRemoteId,
    plot: plot.present ? plot.value : this.plot,
    castList: castList.present ? castList.value : this.castList,
    genres: genres.present ? genres.value : this.genres,
    rating: rating.present ? rating.value : this.rating,
    releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
    tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
    lastModified: lastModified.present ? lastModified.value : this.lastModified,
    episodesSyncedAt: episodesSyncedAt.present
        ? episodesSyncedAt.value
        : this.episodesSyncedAt,
    hidden: hidden ?? this.hidden,
  );
  SeriesEntry copyWithCompanion(SeriesEntriesCompanion data) {
    return SeriesEntry(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      name: data.name.present ? data.name.value : this.name,
      searchName: data.searchName.present
          ? data.searchName.value
          : this.searchName,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      categoryRemoteId: data.categoryRemoteId.present
          ? data.categoryRemoteId.value
          : this.categoryRemoteId,
      plot: data.plot.present ? data.plot.value : this.plot,
      castList: data.castList.present ? data.castList.value : this.castList,
      genres: data.genres.present ? data.genres.value : this.genres,
      rating: data.rating.present ? data.rating.value : this.rating,
      releaseDate: data.releaseDate.present
          ? data.releaseDate.value
          : this.releaseDate,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      episodesSyncedAt: data.episodesSyncedAt.present
          ? data.episodesSyncedAt.value
          : this.episodesSyncedAt,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesEntry(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('searchName: $searchName, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('categoryRemoteId: $categoryRemoteId, ')
          ..write('plot: $plot, ')
          ..write('castList: $castList, ')
          ..write('genres: $genres, ')
          ..write('rating: $rating, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('lastModified: $lastModified, ')
          ..write('episodesSyncedAt: $episodesSyncedAt, ')
          ..write('hidden: $hidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    remoteId,
    name,
    searchName,
    coverUrl,
    categoryRemoteId,
    plot,
    castList,
    genres,
    rating,
    releaseDate,
    tmdbId,
    lastModified,
    episodesSyncedAt,
    hidden,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesEntry &&
          other.sourceId == this.sourceId &&
          other.remoteId == this.remoteId &&
          other.name == this.name &&
          other.searchName == this.searchName &&
          other.coverUrl == this.coverUrl &&
          other.categoryRemoteId == this.categoryRemoteId &&
          other.plot == this.plot &&
          other.castList == this.castList &&
          other.genres == this.genres &&
          other.rating == this.rating &&
          other.releaseDate == this.releaseDate &&
          other.tmdbId == this.tmdbId &&
          other.lastModified == this.lastModified &&
          other.episodesSyncedAt == this.episodesSyncedAt &&
          other.hidden == this.hidden);
}

class SeriesEntriesCompanion extends UpdateCompanion<SeriesEntry> {
  final Value<int> sourceId;
  final Value<String> remoteId;
  final Value<String> name;
  final Value<String> searchName;
  final Value<String?> coverUrl;
  final Value<String?> categoryRemoteId;
  final Value<String?> plot;
  final Value<String?> castList;
  final Value<String?> genres;
  final Value<double?> rating;
  final Value<String?> releaseDate;
  final Value<String?> tmdbId;
  final Value<DateTime?> lastModified;
  final Value<DateTime?> episodesSyncedAt;
  final Value<bool> hidden;
  final Value<int> rowid;
  const SeriesEntriesCompanion({
    this.sourceId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.name = const Value.absent(),
    this.searchName = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.categoryRemoteId = const Value.absent(),
    this.plot = const Value.absent(),
    this.castList = const Value.absent(),
    this.genres = const Value.absent(),
    this.rating = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.episodesSyncedAt = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesEntriesCompanion.insert({
    required int sourceId,
    required String remoteId,
    required String name,
    required String searchName,
    this.coverUrl = const Value.absent(),
    this.categoryRemoteId = const Value.absent(),
    this.plot = const Value.absent(),
    this.castList = const Value.absent(),
    this.genres = const Value.absent(),
    this.rating = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.episodesSyncedAt = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       remoteId = Value(remoteId),
       name = Value(name),
       searchName = Value(searchName);
  static Insertable<SeriesEntry> custom({
    Expression<int>? sourceId,
    Expression<String>? remoteId,
    Expression<String>? name,
    Expression<String>? searchName,
    Expression<String>? coverUrl,
    Expression<String>? categoryRemoteId,
    Expression<String>? plot,
    Expression<String>? castList,
    Expression<String>? genres,
    Expression<double>? rating,
    Expression<String>? releaseDate,
    Expression<String>? tmdbId,
    Expression<DateTime>? lastModified,
    Expression<DateTime>? episodesSyncedAt,
    Expression<bool>? hidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (remoteId != null) 'remote_id': remoteId,
      if (name != null) 'name': name,
      if (searchName != null) 'search_name': searchName,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (categoryRemoteId != null) 'category_remote_id': categoryRemoteId,
      if (plot != null) 'plot': plot,
      if (castList != null) 'cast_list': castList,
      if (genres != null) 'genres': genres,
      if (rating != null) 'rating': rating,
      if (releaseDate != null) 'release_date': releaseDate,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (lastModified != null) 'last_modified': lastModified,
      if (episodesSyncedAt != null) 'episodes_synced_at': episodesSyncedAt,
      if (hidden != null) 'hidden': hidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesEntriesCompanion copyWith({
    Value<int>? sourceId,
    Value<String>? remoteId,
    Value<String>? name,
    Value<String>? searchName,
    Value<String?>? coverUrl,
    Value<String?>? categoryRemoteId,
    Value<String?>? plot,
    Value<String?>? castList,
    Value<String?>? genres,
    Value<double?>? rating,
    Value<String?>? releaseDate,
    Value<String?>? tmdbId,
    Value<DateTime?>? lastModified,
    Value<DateTime?>? episodesSyncedAt,
    Value<bool>? hidden,
    Value<int>? rowid,
  }) {
    return SeriesEntriesCompanion(
      sourceId: sourceId ?? this.sourceId,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      searchName: searchName ?? this.searchName,
      coverUrl: coverUrl ?? this.coverUrl,
      categoryRemoteId: categoryRemoteId ?? this.categoryRemoteId,
      plot: plot ?? this.plot,
      castList: castList ?? this.castList,
      genres: genres ?? this.genres,
      rating: rating ?? this.rating,
      releaseDate: releaseDate ?? this.releaseDate,
      tmdbId: tmdbId ?? this.tmdbId,
      lastModified: lastModified ?? this.lastModified,
      episodesSyncedAt: episodesSyncedAt ?? this.episodesSyncedAt,
      hidden: hidden ?? this.hidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (searchName.present) {
      map['search_name'] = Variable<String>(searchName.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (categoryRemoteId.present) {
      map['category_remote_id'] = Variable<String>(categoryRemoteId.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (castList.present) {
      map['cast_list'] = Variable<String>(castList.value);
    }
    if (genres.present) {
      map['genres'] = Variable<String>(genres.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<String>(releaseDate.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<String>(tmdbId.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (episodesSyncedAt.present) {
      map['episodes_synced_at'] = Variable<DateTime>(episodesSyncedAt.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesEntriesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('searchName: $searchName, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('categoryRemoteId: $categoryRemoteId, ')
          ..write('plot: $plot, ')
          ..write('castList: $castList, ')
          ..write('genres: $genres, ')
          ..write('rating: $rating, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('lastModified: $lastModified, ')
          ..write('episodesSyncedAt: $episodesSyncedAt, ')
          ..write('hidden: $hidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTable extends Episodes with TableInfo<$EpisodesTable, Episode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesRemoteIdMeta = const VerificationMeta(
    'seriesRemoteId',
  );
  @override
  late final GeneratedColumn<String> seriesRemoteId = GeneratedColumn<String>(
    'series_remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeNumberMeta = const VerificationMeta(
    'episodeNumber',
  );
  @override
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
    'episode_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _containerExtensionMeta =
      const VerificationMeta('containerExtension');
  @override
  late final GeneratedColumn<String> containerExtension =
      GeneratedColumn<String>(
        'container_extension',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconUrlMeta = const VerificationMeta(
    'iconUrl',
  );
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
    'icon_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directUrlMeta = const VerificationMeta(
    'directUrl',
  );
  @override
  late final GeneratedColumn<String> directUrl = GeneratedColumn<String>(
    'direct_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    remoteId,
    seriesRemoteId,
    title,
    season,
    episodeNumber,
    containerExtension,
    plot,
    durationSeconds,
    iconUrl,
    addedAt,
    directUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Episode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('series_remote_id')) {
      context.handle(
        _seriesRemoteIdMeta,
        seriesRemoteId.isAcceptableOrUnknown(
          data['series_remote_id']!,
          _seriesRemoteIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seriesRemoteIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('episode_number')) {
      context.handle(
        _episodeNumberMeta,
        episodeNumber.isAcceptableOrUnknown(
          data['episode_number']!,
          _episodeNumberMeta,
        ),
      );
    }
    if (data.containsKey('container_extension')) {
      context.handle(
        _containerExtensionMeta,
        containerExtension.isAcceptableOrUnknown(
          data['container_extension']!,
          _containerExtensionMeta,
        ),
      );
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('icon_url')) {
      context.handle(
        _iconUrlMeta,
        iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('direct_url')) {
      context.handle(
        _directUrlMeta,
        directUrl.isAcceptableOrUnknown(data['direct_url']!, _directUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, remoteId};
  @override
  Episode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Episode(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      seriesRemoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_remote_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      ),
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_number'],
      ),
      containerExtension: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}container_extension'],
      ),
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      iconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_url'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      ),
      directUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direct_url'],
      ),
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class Episode extends DataClass implements Insertable<Episode> {
  final int sourceId;
  final String remoteId;

  /// The owning series' provider id, not the local row id, so episodes can be
  /// written before their series row is resolved.
  final String seriesRemoteId;
  final String title;
  final int? season;
  final int? episodeNumber;
  final String? containerExtension;
  final String? plot;
  final int? durationSeconds;
  final String? iconUrl;
  final DateTime? addedAt;
  final String? directUrl;
  const Episode({
    required this.sourceId,
    required this.remoteId,
    required this.seriesRemoteId,
    required this.title,
    this.season,
    this.episodeNumber,
    this.containerExtension,
    this.plot,
    this.durationSeconds,
    this.iconUrl,
    this.addedAt,
    this.directUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<int>(sourceId);
    map['remote_id'] = Variable<String>(remoteId);
    map['series_remote_id'] = Variable<String>(seriesRemoteId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<int>(season);
    }
    if (!nullToAbsent || episodeNumber != null) {
      map['episode_number'] = Variable<int>(episodeNumber);
    }
    if (!nullToAbsent || containerExtension != null) {
      map['container_extension'] = Variable<String>(containerExtension);
    }
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<DateTime>(addedAt);
    }
    if (!nullToAbsent || directUrl != null) {
      map['direct_url'] = Variable<String>(directUrl);
    }
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      sourceId: Value(sourceId),
      remoteId: Value(remoteId),
      seriesRemoteId: Value(seriesRemoteId),
      title: Value(title),
      season: season == null && nullToAbsent
          ? const Value.absent()
          : Value(season),
      episodeNumber: episodeNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNumber),
      containerExtension: containerExtension == null && nullToAbsent
          ? const Value.absent()
          : Value(containerExtension),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
      directUrl: directUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(directUrl),
    );
  }

  factory Episode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Episode(
      sourceId: serializer.fromJson<int>(json['sourceId']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      seriesRemoteId: serializer.fromJson<String>(json['seriesRemoteId']),
      title: serializer.fromJson<String>(json['title']),
      season: serializer.fromJson<int?>(json['season']),
      episodeNumber: serializer.fromJson<int?>(json['episodeNumber']),
      containerExtension: serializer.fromJson<String?>(
        json['containerExtension'],
      ),
      plot: serializer.fromJson<String?>(json['plot']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
      addedAt: serializer.fromJson<DateTime?>(json['addedAt']),
      directUrl: serializer.fromJson<String?>(json['directUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<int>(sourceId),
      'remoteId': serializer.toJson<String>(remoteId),
      'seriesRemoteId': serializer.toJson<String>(seriesRemoteId),
      'title': serializer.toJson<String>(title),
      'season': serializer.toJson<int?>(season),
      'episodeNumber': serializer.toJson<int?>(episodeNumber),
      'containerExtension': serializer.toJson<String?>(containerExtension),
      'plot': serializer.toJson<String?>(plot),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'iconUrl': serializer.toJson<String?>(iconUrl),
      'addedAt': serializer.toJson<DateTime?>(addedAt),
      'directUrl': serializer.toJson<String?>(directUrl),
    };
  }

  Episode copyWith({
    int? sourceId,
    String? remoteId,
    String? seriesRemoteId,
    String? title,
    Value<int?> season = const Value.absent(),
    Value<int?> episodeNumber = const Value.absent(),
    Value<String?> containerExtension = const Value.absent(),
    Value<String?> plot = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<String?> iconUrl = const Value.absent(),
    Value<DateTime?> addedAt = const Value.absent(),
    Value<String?> directUrl = const Value.absent(),
  }) => Episode(
    sourceId: sourceId ?? this.sourceId,
    remoteId: remoteId ?? this.remoteId,
    seriesRemoteId: seriesRemoteId ?? this.seriesRemoteId,
    title: title ?? this.title,
    season: season.present ? season.value : this.season,
    episodeNumber: episodeNumber.present
        ? episodeNumber.value
        : this.episodeNumber,
    containerExtension: containerExtension.present
        ? containerExtension.value
        : this.containerExtension,
    plot: plot.present ? plot.value : this.plot,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
    directUrl: directUrl.present ? directUrl.value : this.directUrl,
  );
  Episode copyWithCompanion(EpisodesCompanion data) {
    return Episode(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      seriesRemoteId: data.seriesRemoteId.present
          ? data.seriesRemoteId.value
          : this.seriesRemoteId,
      title: data.title.present ? data.title.value : this.title,
      season: data.season.present ? data.season.value : this.season,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      containerExtension: data.containerExtension.present
          ? data.containerExtension.value
          : this.containerExtension,
      plot: data.plot.present ? data.plot.value : this.plot,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      directUrl: data.directUrl.present ? data.directUrl.value : this.directUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Episode(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('seriesRemoteId: $seriesRemoteId, ')
          ..write('title: $title, ')
          ..write('season: $season, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('containerExtension: $containerExtension, ')
          ..write('plot: $plot, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('addedAt: $addedAt, ')
          ..write('directUrl: $directUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    remoteId,
    seriesRemoteId,
    title,
    season,
    episodeNumber,
    containerExtension,
    plot,
    durationSeconds,
    iconUrl,
    addedAt,
    directUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Episode &&
          other.sourceId == this.sourceId &&
          other.remoteId == this.remoteId &&
          other.seriesRemoteId == this.seriesRemoteId &&
          other.title == this.title &&
          other.season == this.season &&
          other.episodeNumber == this.episodeNumber &&
          other.containerExtension == this.containerExtension &&
          other.plot == this.plot &&
          other.durationSeconds == this.durationSeconds &&
          other.iconUrl == this.iconUrl &&
          other.addedAt == this.addedAt &&
          other.directUrl == this.directUrl);
}

class EpisodesCompanion extends UpdateCompanion<Episode> {
  final Value<int> sourceId;
  final Value<String> remoteId;
  final Value<String> seriesRemoteId;
  final Value<String> title;
  final Value<int?> season;
  final Value<int?> episodeNumber;
  final Value<String?> containerExtension;
  final Value<String?> plot;
  final Value<int?> durationSeconds;
  final Value<String?> iconUrl;
  final Value<DateTime?> addedAt;
  final Value<String?> directUrl;
  final Value<int> rowid;
  const EpisodesCompanion({
    this.sourceId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.seriesRemoteId = const Value.absent(),
    this.title = const Value.absent(),
    this.season = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.containerExtension = const Value.absent(),
    this.plot = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.directUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodesCompanion.insert({
    required int sourceId,
    required String remoteId,
    required String seriesRemoteId,
    required String title,
    this.season = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.containerExtension = const Value.absent(),
    this.plot = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.directUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       remoteId = Value(remoteId),
       seriesRemoteId = Value(seriesRemoteId),
       title = Value(title);
  static Insertable<Episode> custom({
    Expression<int>? sourceId,
    Expression<String>? remoteId,
    Expression<String>? seriesRemoteId,
    Expression<String>? title,
    Expression<int>? season,
    Expression<int>? episodeNumber,
    Expression<String>? containerExtension,
    Expression<String>? plot,
    Expression<int>? durationSeconds,
    Expression<String>? iconUrl,
    Expression<DateTime>? addedAt,
    Expression<String>? directUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (remoteId != null) 'remote_id': remoteId,
      if (seriesRemoteId != null) 'series_remote_id': seriesRemoteId,
      if (title != null) 'title': title,
      if (season != null) 'season': season,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (containerExtension != null) 'container_extension': containerExtension,
      if (plot != null) 'plot': plot,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (addedAt != null) 'added_at': addedAt,
      if (directUrl != null) 'direct_url': directUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodesCompanion copyWith({
    Value<int>? sourceId,
    Value<String>? remoteId,
    Value<String>? seriesRemoteId,
    Value<String>? title,
    Value<int?>? season,
    Value<int?>? episodeNumber,
    Value<String?>? containerExtension,
    Value<String?>? plot,
    Value<int?>? durationSeconds,
    Value<String?>? iconUrl,
    Value<DateTime?>? addedAt,
    Value<String?>? directUrl,
    Value<int>? rowid,
  }) {
    return EpisodesCompanion(
      sourceId: sourceId ?? this.sourceId,
      remoteId: remoteId ?? this.remoteId,
      seriesRemoteId: seriesRemoteId ?? this.seriesRemoteId,
      title: title ?? this.title,
      season: season ?? this.season,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      containerExtension: containerExtension ?? this.containerExtension,
      plot: plot ?? this.plot,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      iconUrl: iconUrl ?? this.iconUrl,
      addedAt: addedAt ?? this.addedAt,
      directUrl: directUrl ?? this.directUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (seriesRemoteId.present) {
      map['series_remote_id'] = Variable<String>(seriesRemoteId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (containerExtension.present) {
      map['container_extension'] = Variable<String>(containerExtension.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (directUrl.present) {
      map['direct_url'] = Variable<String>(directUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('seriesRemoteId: $seriesRemoteId, ')
          ..write('title: $title, ')
          ..write('season: $season, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('containerExtension: $containerExtension, ')
          ..write('plot: $plot, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('addedAt: $addedAt, ')
          ..write('directUrl: $directUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgChannelsTable extends EpgChannels
    with TableInfo<$EpgChannelsTable, EpgChannel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconUrlMeta = const VerificationMeta(
    'iconUrl',
  );
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
    'icon_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    channelId,
    displayName,
    iconUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgChannel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('icon_url')) {
      context.handle(
        _iconUrlMeta,
        iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, channelId};
  @override
  EpgChannel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgChannel(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      iconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_url'],
      ),
    );
  }

  @override
  $EpgChannelsTable createAlias(String alias) {
    return $EpgChannelsTable(attachedDatabase, alias);
  }
}

class EpgChannel extends DataClass implements Insertable<EpgChannel> {
  final int sourceId;

  /// The XMLTV channel id, which `Channels.epgChannelId` points at.
  final String channelId;
  final String? displayName;
  final String? iconUrl;
  const EpgChannel({
    required this.sourceId,
    required this.channelId,
    this.displayName,
    this.iconUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<int>(sourceId);
    map['channel_id'] = Variable<String>(channelId);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    return map;
  }

  EpgChannelsCompanion toCompanion(bool nullToAbsent) {
    return EpgChannelsCompanion(
      sourceId: Value(sourceId),
      channelId: Value(channelId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
    );
  }

  factory EpgChannel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgChannel(
      sourceId: serializer.fromJson<int>(json['sourceId']),
      channelId: serializer.fromJson<String>(json['channelId']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<int>(sourceId),
      'channelId': serializer.toJson<String>(channelId),
      'displayName': serializer.toJson<String?>(displayName),
      'iconUrl': serializer.toJson<String?>(iconUrl),
    };
  }

  EpgChannel copyWith({
    int? sourceId,
    String? channelId,
    Value<String?> displayName = const Value.absent(),
    Value<String?> iconUrl = const Value.absent(),
  }) => EpgChannel(
    sourceId: sourceId ?? this.sourceId,
    channelId: channelId ?? this.channelId,
    displayName: displayName.present ? displayName.value : this.displayName,
    iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
  );
  EpgChannel copyWithCompanion(EpgChannelsCompanion data) {
    return EpgChannel(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannel(')
          ..write('sourceId: $sourceId, ')
          ..write('channelId: $channelId, ')
          ..write('displayName: $displayName, ')
          ..write('iconUrl: $iconUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sourceId, channelId, displayName, iconUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgChannel &&
          other.sourceId == this.sourceId &&
          other.channelId == this.channelId &&
          other.displayName == this.displayName &&
          other.iconUrl == this.iconUrl);
}

class EpgChannelsCompanion extends UpdateCompanion<EpgChannel> {
  final Value<int> sourceId;
  final Value<String> channelId;
  final Value<String?> displayName;
  final Value<String?> iconUrl;
  final Value<int> rowid;
  const EpgChannelsCompanion({
    this.sourceId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgChannelsCompanion.insert({
    required int sourceId,
    required String channelId,
    this.displayName = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       channelId = Value(channelId);
  static Insertable<EpgChannel> custom({
    Expression<int>? sourceId,
    Expression<String>? channelId,
    Expression<String>? displayName,
    Expression<String>? iconUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (channelId != null) 'channel_id': channelId,
      if (displayName != null) 'display_name': displayName,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgChannelsCompanion copyWith({
    Value<int>? sourceId,
    Value<String>? channelId,
    Value<String?>? displayName,
    Value<String?>? iconUrl,
    Value<int>? rowid,
  }) {
    return EpgChannelsCompanion(
      sourceId: sourceId ?? this.sourceId,
      channelId: channelId ?? this.channelId,
      displayName: displayName ?? this.displayName,
      iconUrl: iconUrl ?? this.iconUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannelsCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('channelId: $channelId, ')
          ..write('displayName: $displayName, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgProgrammesTable extends EpgProgrammes
    with TableInfo<$EpgProgrammesTable, EpgProgramme> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgProgrammesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startUtcMeta = const VerificationMeta(
    'startUtc',
  );
  @override
  late final GeneratedColumn<DateTime> startUtc = GeneratedColumn<DateTime>(
    'start_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stopUtcMeta = const VerificationMeta(
    'stopUtc',
  );
  @override
  late final GeneratedColumn<DateTime> stopUtc = GeneratedColumn<DateTime>(
    'stop_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subTitleMeta = const VerificationMeta(
    'subTitle',
  );
  @override
  late final GeneratedColumn<String> subTitle = GeneratedColumn<String>(
    'sub_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoriesMeta = const VerificationMeta(
    'categories',
  );
  @override
  late final GeneratedColumn<String> categories = GeneratedColumn<String>(
    'categories',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconUrlMeta = const VerificationMeta(
    'iconUrl',
  );
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
    'icon_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeNumberMeta = const VerificationMeta(
    'episodeNumber',
  );
  @override
  late final GeneratedColumn<String> episodeNumber = GeneratedColumn<String>(
    'episode_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    channelId,
    startUtc,
    stopUtc,
    title,
    subTitle,
    description,
    categories,
    iconUrl,
    episodeNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_programmes';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgProgramme> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('start_utc')) {
      context.handle(
        _startUtcMeta,
        startUtc.isAcceptableOrUnknown(data['start_utc']!, _startUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_startUtcMeta);
    }
    if (data.containsKey('stop_utc')) {
      context.handle(
        _stopUtcMeta,
        stopUtc.isAcceptableOrUnknown(data['stop_utc']!, _stopUtcMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('sub_title')) {
      context.handle(
        _subTitleMeta,
        subTitle.isAcceptableOrUnknown(data['sub_title']!, _subTitleMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('categories')) {
      context.handle(
        _categoriesMeta,
        categories.isAcceptableOrUnknown(data['categories']!, _categoriesMeta),
      );
    }
    if (data.containsKey('icon_url')) {
      context.handle(
        _iconUrlMeta,
        iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta),
      );
    }
    if (data.containsKey('episode_number')) {
      context.handle(
        _episodeNumberMeta,
        episodeNumber.isAcceptableOrUnknown(
          data['episode_number']!,
          _episodeNumberMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpgProgramme map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgProgramme(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      startUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_utc'],
      )!,
      stopUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}stop_utc'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      subTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_title'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      categories: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories'],
      ),
      iconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_url'],
      ),
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_number'],
      ),
    );
  }

  @override
  $EpgProgrammesTable createAlias(String alias) {
    return $EpgProgrammesTable(attachedDatabase, alias);
  }
}

class EpgProgramme extends DataClass implements Insertable<EpgProgramme> {
  final int id;
  final int sourceId;
  final String channelId;

  /// Always UTC. Stored as a unix timestamp so range queries stay cheap.
  final DateTime startUtc;
  final DateTime? stopUtc;
  final String? title;
  final String? subTitle;
  final String? description;
  final String? categories;
  final String? iconUrl;
  final String? episodeNumber;
  const EpgProgramme({
    required this.id,
    required this.sourceId,
    required this.channelId,
    required this.startUtc,
    this.stopUtc,
    this.title,
    this.subTitle,
    this.description,
    this.categories,
    this.iconUrl,
    this.episodeNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<int>(sourceId);
    map['channel_id'] = Variable<String>(channelId);
    map['start_utc'] = Variable<DateTime>(startUtc);
    if (!nullToAbsent || stopUtc != null) {
      map['stop_utc'] = Variable<DateTime>(stopUtc);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || subTitle != null) {
      map['sub_title'] = Variable<String>(subTitle);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || categories != null) {
      map['categories'] = Variable<String>(categories);
    }
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    if (!nullToAbsent || episodeNumber != null) {
      map['episode_number'] = Variable<String>(episodeNumber);
    }
    return map;
  }

  EpgProgrammesCompanion toCompanion(bool nullToAbsent) {
    return EpgProgrammesCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      channelId: Value(channelId),
      startUtc: Value(startUtc),
      stopUtc: stopUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(stopUtc),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      subTitle: subTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(subTitle),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      categories: categories == null && nullToAbsent
          ? const Value.absent()
          : Value(categories),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
      episodeNumber: episodeNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNumber),
    );
  }

  factory EpgProgramme.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgProgramme(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<int>(json['sourceId']),
      channelId: serializer.fromJson<String>(json['channelId']),
      startUtc: serializer.fromJson<DateTime>(json['startUtc']),
      stopUtc: serializer.fromJson<DateTime?>(json['stopUtc']),
      title: serializer.fromJson<String?>(json['title']),
      subTitle: serializer.fromJson<String?>(json['subTitle']),
      description: serializer.fromJson<String?>(json['description']),
      categories: serializer.fromJson<String?>(json['categories']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
      episodeNumber: serializer.fromJson<String?>(json['episodeNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<int>(sourceId),
      'channelId': serializer.toJson<String>(channelId),
      'startUtc': serializer.toJson<DateTime>(startUtc),
      'stopUtc': serializer.toJson<DateTime?>(stopUtc),
      'title': serializer.toJson<String?>(title),
      'subTitle': serializer.toJson<String?>(subTitle),
      'description': serializer.toJson<String?>(description),
      'categories': serializer.toJson<String?>(categories),
      'iconUrl': serializer.toJson<String?>(iconUrl),
      'episodeNumber': serializer.toJson<String?>(episodeNumber),
    };
  }

  EpgProgramme copyWith({
    int? id,
    int? sourceId,
    String? channelId,
    DateTime? startUtc,
    Value<DateTime?> stopUtc = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> subTitle = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> categories = const Value.absent(),
    Value<String?> iconUrl = const Value.absent(),
    Value<String?> episodeNumber = const Value.absent(),
  }) => EpgProgramme(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    channelId: channelId ?? this.channelId,
    startUtc: startUtc ?? this.startUtc,
    stopUtc: stopUtc.present ? stopUtc.value : this.stopUtc,
    title: title.present ? title.value : this.title,
    subTitle: subTitle.present ? subTitle.value : this.subTitle,
    description: description.present ? description.value : this.description,
    categories: categories.present ? categories.value : this.categories,
    iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
    episodeNumber: episodeNumber.present
        ? episodeNumber.value
        : this.episodeNumber,
  );
  EpgProgramme copyWithCompanion(EpgProgrammesCompanion data) {
    return EpgProgramme(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      startUtc: data.startUtc.present ? data.startUtc.value : this.startUtc,
      stopUtc: data.stopUtc.present ? data.stopUtc.value : this.stopUtc,
      title: data.title.present ? data.title.value : this.title,
      subTitle: data.subTitle.present ? data.subTitle.value : this.subTitle,
      description: data.description.present
          ? data.description.value
          : this.description,
      categories: data.categories.present
          ? data.categories.value
          : this.categories,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgramme(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('channelId: $channelId, ')
          ..write('startUtc: $startUtc, ')
          ..write('stopUtc: $stopUtc, ')
          ..write('title: $title, ')
          ..write('subTitle: $subTitle, ')
          ..write('description: $description, ')
          ..write('categories: $categories, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('episodeNumber: $episodeNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    channelId,
    startUtc,
    stopUtc,
    title,
    subTitle,
    description,
    categories,
    iconUrl,
    episodeNumber,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgProgramme &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.channelId == this.channelId &&
          other.startUtc == this.startUtc &&
          other.stopUtc == this.stopUtc &&
          other.title == this.title &&
          other.subTitle == this.subTitle &&
          other.description == this.description &&
          other.categories == this.categories &&
          other.iconUrl == this.iconUrl &&
          other.episodeNumber == this.episodeNumber);
}

class EpgProgrammesCompanion extends UpdateCompanion<EpgProgramme> {
  final Value<int> id;
  final Value<int> sourceId;
  final Value<String> channelId;
  final Value<DateTime> startUtc;
  final Value<DateTime?> stopUtc;
  final Value<String?> title;
  final Value<String?> subTitle;
  final Value<String?> description;
  final Value<String?> categories;
  final Value<String?> iconUrl;
  final Value<String?> episodeNumber;
  const EpgProgrammesCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.startUtc = const Value.absent(),
    this.stopUtc = const Value.absent(),
    this.title = const Value.absent(),
    this.subTitle = const Value.absent(),
    this.description = const Value.absent(),
    this.categories = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.episodeNumber = const Value.absent(),
  });
  EpgProgrammesCompanion.insert({
    this.id = const Value.absent(),
    required int sourceId,
    required String channelId,
    required DateTime startUtc,
    this.stopUtc = const Value.absent(),
    this.title = const Value.absent(),
    this.subTitle = const Value.absent(),
    this.description = const Value.absent(),
    this.categories = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.episodeNumber = const Value.absent(),
  }) : sourceId = Value(sourceId),
       channelId = Value(channelId),
       startUtc = Value(startUtc);
  static Insertable<EpgProgramme> custom({
    Expression<int>? id,
    Expression<int>? sourceId,
    Expression<String>? channelId,
    Expression<DateTime>? startUtc,
    Expression<DateTime>? stopUtc,
    Expression<String>? title,
    Expression<String>? subTitle,
    Expression<String>? description,
    Expression<String>? categories,
    Expression<String>? iconUrl,
    Expression<String>? episodeNumber,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (channelId != null) 'channel_id': channelId,
      if (startUtc != null) 'start_utc': startUtc,
      if (stopUtc != null) 'stop_utc': stopUtc,
      if (title != null) 'title': title,
      if (subTitle != null) 'sub_title': subTitle,
      if (description != null) 'description': description,
      if (categories != null) 'categories': categories,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (episodeNumber != null) 'episode_number': episodeNumber,
    });
  }

  EpgProgrammesCompanion copyWith({
    Value<int>? id,
    Value<int>? sourceId,
    Value<String>? channelId,
    Value<DateTime>? startUtc,
    Value<DateTime?>? stopUtc,
    Value<String?>? title,
    Value<String?>? subTitle,
    Value<String?>? description,
    Value<String?>? categories,
    Value<String?>? iconUrl,
    Value<String?>? episodeNumber,
  }) {
    return EpgProgrammesCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      channelId: channelId ?? this.channelId,
      startUtc: startUtc ?? this.startUtc,
      stopUtc: stopUtc ?? this.stopUtc,
      title: title ?? this.title,
      subTitle: subTitle ?? this.subTitle,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      iconUrl: iconUrl ?? this.iconUrl,
      episodeNumber: episodeNumber ?? this.episodeNumber,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (startUtc.present) {
      map['start_utc'] = Variable<DateTime>(startUtc.value);
    }
    if (stopUtc.present) {
      map['stop_utc'] = Variable<DateTime>(stopUtc.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subTitle.present) {
      map['sub_title'] = Variable<String>(subTitle.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (categories.present) {
      map['categories'] = Variable<String>(categories.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<String>(episodeNumber.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgrammesCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('channelId: $channelId, ')
          ..write('startUtc: $startUtc, ')
          ..write('stopUtc: $stopUtc, ')
          ..write('title: $title, ')
          ..write('subTitle: $subTitle, ')
          ..write('description: $description, ')
          ..write('categories: $categories, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('episodeNumber: $episodeNumber')
          ..write(')'))
        .toString();
  }
}

class $FavouritesTable extends Favourites
    with TableInfo<$FavouritesTable, Favourite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavouritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ItemKind, String> itemKind =
      GeneratedColumn<String>(
        'item_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ItemKind>($FavouritesTable.$converteritemKind);
  static const VerificationMeta _itemRemoteIdMeta = const VerificationMeta(
    'itemRemoteId',
  );
  @override
  late final GeneratedColumn<String> itemRemoteId = GeneratedColumn<String>(
    'item_remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    itemKind,
    itemRemoteId,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favourites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favourite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('item_remote_id')) {
      context.handle(
        _itemRemoteIdMeta,
        itemRemoteId.isAcceptableOrUnknown(
          data['item_remote_id']!,
          _itemRemoteIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_itemRemoteIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, itemKind, itemRemoteId};
  @override
  Favourite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favourite(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      itemKind: $FavouritesTable.$converteritemKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}item_kind'],
        )!,
      ),
      itemRemoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_remote_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $FavouritesTable createAlias(String alias) {
    return $FavouritesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemKind, String, String> $converteritemKind =
      const EnumNameConverter<ItemKind>(ItemKind.values);
}

class Favourite extends DataClass implements Insertable<Favourite> {
  final int sourceId;
  final ItemKind itemKind;
  final String itemRemoteId;
  final DateTime addedAt;
  const Favourite({
    required this.sourceId,
    required this.itemKind,
    required this.itemRemoteId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<int>(sourceId);
    {
      map['item_kind'] = Variable<String>(
        $FavouritesTable.$converteritemKind.toSql(itemKind),
      );
    }
    map['item_remote_id'] = Variable<String>(itemRemoteId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavouritesCompanion toCompanion(bool nullToAbsent) {
    return FavouritesCompanion(
      sourceId: Value(sourceId),
      itemKind: Value(itemKind),
      itemRemoteId: Value(itemRemoteId),
      addedAt: Value(addedAt),
    );
  }

  factory Favourite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favourite(
      sourceId: serializer.fromJson<int>(json['sourceId']),
      itemKind: $FavouritesTable.$converteritemKind.fromJson(
        serializer.fromJson<String>(json['itemKind']),
      ),
      itemRemoteId: serializer.fromJson<String>(json['itemRemoteId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<int>(sourceId),
      'itemKind': serializer.toJson<String>(
        $FavouritesTable.$converteritemKind.toJson(itemKind),
      ),
      'itemRemoteId': serializer.toJson<String>(itemRemoteId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  Favourite copyWith({
    int? sourceId,
    ItemKind? itemKind,
    String? itemRemoteId,
    DateTime? addedAt,
  }) => Favourite(
    sourceId: sourceId ?? this.sourceId,
    itemKind: itemKind ?? this.itemKind,
    itemRemoteId: itemRemoteId ?? this.itemRemoteId,
    addedAt: addedAt ?? this.addedAt,
  );
  Favourite copyWithCompanion(FavouritesCompanion data) {
    return Favourite(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      itemKind: data.itemKind.present ? data.itemKind.value : this.itemKind,
      itemRemoteId: data.itemRemoteId.present
          ? data.itemRemoteId.value
          : this.itemRemoteId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favourite(')
          ..write('sourceId: $sourceId, ')
          ..write('itemKind: $itemKind, ')
          ..write('itemRemoteId: $itemRemoteId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sourceId, itemKind, itemRemoteId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favourite &&
          other.sourceId == this.sourceId &&
          other.itemKind == this.itemKind &&
          other.itemRemoteId == this.itemRemoteId &&
          other.addedAt == this.addedAt);
}

class FavouritesCompanion extends UpdateCompanion<Favourite> {
  final Value<int> sourceId;
  final Value<ItemKind> itemKind;
  final Value<String> itemRemoteId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavouritesCompanion({
    this.sourceId = const Value.absent(),
    this.itemKind = const Value.absent(),
    this.itemRemoteId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavouritesCompanion.insert({
    required int sourceId,
    required ItemKind itemKind,
    required String itemRemoteId,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       itemKind = Value(itemKind),
       itemRemoteId = Value(itemRemoteId),
       addedAt = Value(addedAt);
  static Insertable<Favourite> custom({
    Expression<int>? sourceId,
    Expression<String>? itemKind,
    Expression<String>? itemRemoteId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (itemKind != null) 'item_kind': itemKind,
      if (itemRemoteId != null) 'item_remote_id': itemRemoteId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavouritesCompanion copyWith({
    Value<int>? sourceId,
    Value<ItemKind>? itemKind,
    Value<String>? itemRemoteId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return FavouritesCompanion(
      sourceId: sourceId ?? this.sourceId,
      itemKind: itemKind ?? this.itemKind,
      itemRemoteId: itemRemoteId ?? this.itemRemoteId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (itemKind.present) {
      map['item_kind'] = Variable<String>(
        $FavouritesTable.$converteritemKind.toSql(itemKind.value),
      );
    }
    if (itemRemoteId.present) {
      map['item_remote_id'] = Variable<String>(itemRemoteId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavouritesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('itemKind: $itemKind, ')
          ..write('itemRemoteId: $itemRemoteId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackStatesTable extends PlaybackStates
    with TableInfo<$PlaybackStatesTable, PlaybackState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ItemKind, String> itemKind =
      GeneratedColumn<String>(
        'item_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ItemKind>($PlaybackStatesTable.$converteritemKind);
  static const VerificationMeta _itemRemoteIdMeta = const VerificationMeta(
    'itemRemoteId',
  );
  @override
  late final GeneratedColumn<String> itemRemoteId = GeneratedColumn<String>(
    'item_remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastWatchedUtcMeta = const VerificationMeta(
    'lastWatchedUtc',
  );
  @override
  late final GeneratedColumn<DateTime> lastWatchedUtc =
      GeneratedColumn<DateTime>(
        'last_watched_utc',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _parentRemoteIdMeta = const VerificationMeta(
    'parentRemoteId',
  );
  @override
  late final GeneratedColumn<String> parentRemoteId = GeneratedColumn<String>(
    'parent_remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    itemKind,
    itemRemoteId,
    positionMs,
    durationMs,
    lastWatchedUtc,
    completed,
    parentRemoteId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('item_remote_id')) {
      context.handle(
        _itemRemoteIdMeta,
        itemRemoteId.isAcceptableOrUnknown(
          data['item_remote_id']!,
          _itemRemoteIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_itemRemoteIdMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('last_watched_utc')) {
      context.handle(
        _lastWatchedUtcMeta,
        lastWatchedUtc.isAcceptableOrUnknown(
          data['last_watched_utc']!,
          _lastWatchedUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWatchedUtcMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('parent_remote_id')) {
      context.handle(
        _parentRemoteIdMeta,
        parentRemoteId.isAcceptableOrUnknown(
          data['parent_remote_id']!,
          _parentRemoteIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, itemKind, itemRemoteId};
  @override
  PlaybackState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackState(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      itemKind: $PlaybackStatesTable.$converteritemKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}item_kind'],
        )!,
      ),
      itemRemoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_remote_id'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      lastWatchedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_watched_utc'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      parentRemoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_remote_id'],
      ),
    );
  }

  @override
  $PlaybackStatesTable createAlias(String alias) {
    return $PlaybackStatesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemKind, String, String> $converteritemKind =
      const EnumNameConverter<ItemKind>(ItemKind.values);
}

class PlaybackState extends DataClass implements Insertable<PlaybackState> {
  final int sourceId;
  final ItemKind itemKind;
  final String itemRemoteId;

  /// Null for live, which has no meaningful resume point.
  final int? positionMs;
  final int? durationMs;
  final DateTime lastWatchedUtc;

  /// Set once the item is watched far enough to count as finished, so it can
  /// leave the continue-watching row without losing its history entry.
  final bool completed;

  /// For episodes, the series they belong to, so continue-watching can offer
  /// the next episode rather than the one just finished.
  final String? parentRemoteId;
  const PlaybackState({
    required this.sourceId,
    required this.itemKind,
    required this.itemRemoteId,
    this.positionMs,
    this.durationMs,
    required this.lastWatchedUtc,
    required this.completed,
    this.parentRemoteId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<int>(sourceId);
    {
      map['item_kind'] = Variable<String>(
        $PlaybackStatesTable.$converteritemKind.toSql(itemKind),
      );
    }
    map['item_remote_id'] = Variable<String>(itemRemoteId);
    if (!nullToAbsent || positionMs != null) {
      map['position_ms'] = Variable<int>(positionMs);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['last_watched_utc'] = Variable<DateTime>(lastWatchedUtc);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || parentRemoteId != null) {
      map['parent_remote_id'] = Variable<String>(parentRemoteId);
    }
    return map;
  }

  PlaybackStatesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackStatesCompanion(
      sourceId: Value(sourceId),
      itemKind: Value(itemKind),
      itemRemoteId: Value(itemRemoteId),
      positionMs: positionMs == null && nullToAbsent
          ? const Value.absent()
          : Value(positionMs),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      lastWatchedUtc: Value(lastWatchedUtc),
      completed: Value(completed),
      parentRemoteId: parentRemoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentRemoteId),
    );
  }

  factory PlaybackState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackState(
      sourceId: serializer.fromJson<int>(json['sourceId']),
      itemKind: $PlaybackStatesTable.$converteritemKind.fromJson(
        serializer.fromJson<String>(json['itemKind']),
      ),
      itemRemoteId: serializer.fromJson<String>(json['itemRemoteId']),
      positionMs: serializer.fromJson<int?>(json['positionMs']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      lastWatchedUtc: serializer.fromJson<DateTime>(json['lastWatchedUtc']),
      completed: serializer.fromJson<bool>(json['completed']),
      parentRemoteId: serializer.fromJson<String?>(json['parentRemoteId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<int>(sourceId),
      'itemKind': serializer.toJson<String>(
        $PlaybackStatesTable.$converteritemKind.toJson(itemKind),
      ),
      'itemRemoteId': serializer.toJson<String>(itemRemoteId),
      'positionMs': serializer.toJson<int?>(positionMs),
      'durationMs': serializer.toJson<int?>(durationMs),
      'lastWatchedUtc': serializer.toJson<DateTime>(lastWatchedUtc),
      'completed': serializer.toJson<bool>(completed),
      'parentRemoteId': serializer.toJson<String?>(parentRemoteId),
    };
  }

  PlaybackState copyWith({
    int? sourceId,
    ItemKind? itemKind,
    String? itemRemoteId,
    Value<int?> positionMs = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    DateTime? lastWatchedUtc,
    bool? completed,
    Value<String?> parentRemoteId = const Value.absent(),
  }) => PlaybackState(
    sourceId: sourceId ?? this.sourceId,
    itemKind: itemKind ?? this.itemKind,
    itemRemoteId: itemRemoteId ?? this.itemRemoteId,
    positionMs: positionMs.present ? positionMs.value : this.positionMs,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    lastWatchedUtc: lastWatchedUtc ?? this.lastWatchedUtc,
    completed: completed ?? this.completed,
    parentRemoteId: parentRemoteId.present
        ? parentRemoteId.value
        : this.parentRemoteId,
  );
  PlaybackState copyWithCompanion(PlaybackStatesCompanion data) {
    return PlaybackState(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      itemKind: data.itemKind.present ? data.itemKind.value : this.itemKind,
      itemRemoteId: data.itemRemoteId.present
          ? data.itemRemoteId.value
          : this.itemRemoteId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      lastWatchedUtc: data.lastWatchedUtc.present
          ? data.lastWatchedUtc.value
          : this.lastWatchedUtc,
      completed: data.completed.present ? data.completed.value : this.completed,
      parentRemoteId: data.parentRemoteId.present
          ? data.parentRemoteId.value
          : this.parentRemoteId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackState(')
          ..write('sourceId: $sourceId, ')
          ..write('itemKind: $itemKind, ')
          ..write('itemRemoteId: $itemRemoteId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('lastWatchedUtc: $lastWatchedUtc, ')
          ..write('completed: $completed, ')
          ..write('parentRemoteId: $parentRemoteId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    itemKind,
    itemRemoteId,
    positionMs,
    durationMs,
    lastWatchedUtc,
    completed,
    parentRemoteId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackState &&
          other.sourceId == this.sourceId &&
          other.itemKind == this.itemKind &&
          other.itemRemoteId == this.itemRemoteId &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.lastWatchedUtc == this.lastWatchedUtc &&
          other.completed == this.completed &&
          other.parentRemoteId == this.parentRemoteId);
}

class PlaybackStatesCompanion extends UpdateCompanion<PlaybackState> {
  final Value<int> sourceId;
  final Value<ItemKind> itemKind;
  final Value<String> itemRemoteId;
  final Value<int?> positionMs;
  final Value<int?> durationMs;
  final Value<DateTime> lastWatchedUtc;
  final Value<bool> completed;
  final Value<String?> parentRemoteId;
  final Value<int> rowid;
  const PlaybackStatesCompanion({
    this.sourceId = const Value.absent(),
    this.itemKind = const Value.absent(),
    this.itemRemoteId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.lastWatchedUtc = const Value.absent(),
    this.completed = const Value.absent(),
    this.parentRemoteId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackStatesCompanion.insert({
    required int sourceId,
    required ItemKind itemKind,
    required String itemRemoteId,
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    required DateTime lastWatchedUtc,
    this.completed = const Value.absent(),
    this.parentRemoteId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       itemKind = Value(itemKind),
       itemRemoteId = Value(itemRemoteId),
       lastWatchedUtc = Value(lastWatchedUtc);
  static Insertable<PlaybackState> custom({
    Expression<int>? sourceId,
    Expression<String>? itemKind,
    Expression<String>? itemRemoteId,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<DateTime>? lastWatchedUtc,
    Expression<bool>? completed,
    Expression<String>? parentRemoteId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (itemKind != null) 'item_kind': itemKind,
      if (itemRemoteId != null) 'item_remote_id': itemRemoteId,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (lastWatchedUtc != null) 'last_watched_utc': lastWatchedUtc,
      if (completed != null) 'completed': completed,
      if (parentRemoteId != null) 'parent_remote_id': parentRemoteId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackStatesCompanion copyWith({
    Value<int>? sourceId,
    Value<ItemKind>? itemKind,
    Value<String>? itemRemoteId,
    Value<int?>? positionMs,
    Value<int?>? durationMs,
    Value<DateTime>? lastWatchedUtc,
    Value<bool>? completed,
    Value<String?>? parentRemoteId,
    Value<int>? rowid,
  }) {
    return PlaybackStatesCompanion(
      sourceId: sourceId ?? this.sourceId,
      itemKind: itemKind ?? this.itemKind,
      itemRemoteId: itemRemoteId ?? this.itemRemoteId,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      lastWatchedUtc: lastWatchedUtc ?? this.lastWatchedUtc,
      completed: completed ?? this.completed,
      parentRemoteId: parentRemoteId ?? this.parentRemoteId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (itemKind.present) {
      map['item_kind'] = Variable<String>(
        $PlaybackStatesTable.$converteritemKind.toSql(itemKind.value),
      );
    }
    if (itemRemoteId.present) {
      map['item_remote_id'] = Variable<String>(itemRemoteId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (lastWatchedUtc.present) {
      map['last_watched_utc'] = Variable<DateTime>(lastWatchedUtc.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (parentRemoteId.present) {
      map['parent_remote_id'] = Variable<String>(parentRemoteId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackStatesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('itemKind: $itemKind, ')
          ..write('itemRemoteId: $itemRemoteId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('lastWatchedUtc: $lastWatchedUtc, ')
          ..write('completed: $completed, ')
          ..write('parentRemoteId: $parentRemoteId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStagesTable extends SyncStages
    with TableInfo<$SyncStagesTable, SyncStage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SyncStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncStatus>($SyncStagesTable.$converterstatus);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsWrittenMeta = const VerificationMeta(
    'itemsWritten',
  );
  @override
  late final GeneratedColumn<int> itemsWritten = GeneratedColumn<int>(
    'items_written',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    stage,
    status,
    updatedAt,
    itemsWritten,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_stages';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('items_written')) {
      context.handle(
        _itemsWrittenMeta,
        itemsWritten.isAcceptableOrUnknown(
          data['items_written']!,
          _itemsWrittenMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, stage};
  @override
  SyncStage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStage(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      status: $SyncStagesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      itemsWritten: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}items_written'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $SyncStagesTable createAlias(String alias) {
    return $SyncStagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncStatus, String, String> $converterstatus =
      const EnumNameConverter<SyncStatus>(SyncStatus.values);
}

class SyncStage extends DataClass implements Insertable<SyncStage> {
  final int sourceId;

  /// Stage name, from `SyncStage.name`.
  final String stage;
  final SyncStatus status;
  final DateTime updatedAt;
  final int itemsWritten;
  final String? error;
  const SyncStage({
    required this.sourceId,
    required this.stage,
    required this.status,
    required this.updatedAt,
    required this.itemsWritten,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<int>(sourceId);
    map['stage'] = Variable<String>(stage);
    {
      map['status'] = Variable<String>(
        $SyncStagesTable.$converterstatus.toSql(status),
      );
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['items_written'] = Variable<int>(itemsWritten);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  SyncStagesCompanion toCompanion(bool nullToAbsent) {
    return SyncStagesCompanion(
      sourceId: Value(sourceId),
      stage: Value(stage),
      status: Value(status),
      updatedAt: Value(updatedAt),
      itemsWritten: Value(itemsWritten),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory SyncStage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStage(
      sourceId: serializer.fromJson<int>(json['sourceId']),
      stage: serializer.fromJson<String>(json['stage']),
      status: $SyncStagesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      itemsWritten: serializer.fromJson<int>(json['itemsWritten']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<int>(sourceId),
      'stage': serializer.toJson<String>(stage),
      'status': serializer.toJson<String>(
        $SyncStagesTable.$converterstatus.toJson(status),
      ),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'itemsWritten': serializer.toJson<int>(itemsWritten),
      'error': serializer.toJson<String?>(error),
    };
  }

  SyncStage copyWith({
    int? sourceId,
    String? stage,
    SyncStatus? status,
    DateTime? updatedAt,
    int? itemsWritten,
    Value<String?> error = const Value.absent(),
  }) => SyncStage(
    sourceId: sourceId ?? this.sourceId,
    stage: stage ?? this.stage,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
    itemsWritten: itemsWritten ?? this.itemsWritten,
    error: error.present ? error.value : this.error,
  );
  SyncStage copyWithCompanion(SyncStagesCompanion data) {
    return SyncStage(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      stage: data.stage.present ? data.stage.value : this.stage,
      status: data.status.present ? data.status.value : this.status,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      itemsWritten: data.itemsWritten.present
          ? data.itemsWritten.value
          : this.itemsWritten,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStage(')
          ..write('sourceId: $sourceId, ')
          ..write('stage: $stage, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('itemsWritten: $itemsWritten, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sourceId, stage, status, updatedAt, itemsWritten, error);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStage &&
          other.sourceId == this.sourceId &&
          other.stage == this.stage &&
          other.status == this.status &&
          other.updatedAt == this.updatedAt &&
          other.itemsWritten == this.itemsWritten &&
          other.error == this.error);
}

class SyncStagesCompanion extends UpdateCompanion<SyncStage> {
  final Value<int> sourceId;
  final Value<String> stage;
  final Value<SyncStatus> status;
  final Value<DateTime> updatedAt;
  final Value<int> itemsWritten;
  final Value<String?> error;
  final Value<int> rowid;
  const SyncStagesCompanion({
    this.sourceId = const Value.absent(),
    this.stage = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.itemsWritten = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStagesCompanion.insert({
    required int sourceId,
    required String stage,
    required SyncStatus status,
    required DateTime updatedAt,
    this.itemsWritten = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       stage = Value(stage),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<SyncStage> custom({
    Expression<int>? sourceId,
    Expression<String>? stage,
    Expression<String>? status,
    Expression<DateTime>? updatedAt,
    Expression<int>? itemsWritten,
    Expression<String>? error,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (stage != null) 'stage': stage,
      if (status != null) 'status': status,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (itemsWritten != null) 'items_written': itemsWritten,
      if (error != null) 'error': error,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStagesCompanion copyWith({
    Value<int>? sourceId,
    Value<String>? stage,
    Value<SyncStatus>? status,
    Value<DateTime>? updatedAt,
    Value<int>? itemsWritten,
    Value<String?>? error,
    Value<int>? rowid,
  }) {
    return SyncStagesCompanion(
      sourceId: sourceId ?? this.sourceId,
      stage: stage ?? this.stage,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      itemsWritten: itemsWritten ?? this.itemsWritten,
      error: error ?? this.error,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $SyncStagesTable.$converterstatus.toSql(status.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (itemsWritten.present) {
      map['items_written'] = Variable<int>(itemsWritten.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStagesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('stage: $stage, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('itemsWritten: $itemsWritten, ')
          ..write('error: $error, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OpenTvDatabase extends GeneratedDatabase {
  _$OpenTvDatabase(QueryExecutor e) : super(e);
  $OpenTvDatabaseManager get managers => $OpenTvDatabaseManager(this);
  late final $SourcesTable sources = $SourcesTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ChannelsTable channels = $ChannelsTable(this);
  late final $MoviesTable movies = $MoviesTable(this);
  late final $SeriesEntriesTable seriesEntries = $SeriesEntriesTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  late final $EpgChannelsTable epgChannels = $EpgChannelsTable(this);
  late final $EpgProgrammesTable epgProgrammes = $EpgProgrammesTable(this);
  late final $FavouritesTable favourites = $FavouritesTable(this);
  late final $PlaybackStatesTable playbackStates = $PlaybackStatesTable(this);
  late final $SyncStagesTable syncStages = $SyncStagesTable(this);
  late final Index categorySourceKind = Index(
    'category_source_kind',
    'CREATE INDEX category_source_kind ON categories (source_id, kind)',
  );
  late final Index channelSourceCategory = Index(
    'channel_source_category',
    'CREATE INDEX channel_source_category ON channels (source_id, category_remote_id)',
  );
  late final Index channelSearch = Index(
    'channel_search',
    'CREATE INDEX channel_search ON channels (source_id, search_name)',
  );
  late final Index channelEpg = Index(
    'channel_epg',
    'CREATE INDEX channel_epg ON channels (source_id, epg_channel_id)',
  );
  late final Index movieSourceCategory = Index(
    'movie_source_category',
    'CREATE INDEX movie_source_category ON movies (source_id, category_remote_id)',
  );
  late final Index movieSearch = Index(
    'movie_search',
    'CREATE INDEX movie_search ON movies (source_id, search_name)',
  );
  late final Index seriesSourceCategory = Index(
    'series_source_category',
    'CREATE INDEX series_source_category ON series_entries (source_id, category_remote_id)',
  );
  late final Index seriesSearch = Index(
    'series_search',
    'CREATE INDEX series_search ON series_entries (source_id, search_name)',
  );
  late final Index episodeSeries = Index(
    'episode_series',
    'CREATE INDEX episode_series ON episodes (source_id, series_remote_id)',
  );
  late final Index epgLookup = Index(
    'epg_lookup',
    'CREATE INDEX epg_lookup ON epg_programmes (source_id, channel_id, start_utc)',
  );
  late final Index favouriteLookup = Index(
    'favourite_lookup',
    'CREATE INDEX favourite_lookup ON favourites (source_id, item_kind)',
  );
  late final Index playbackRecent = Index(
    'playback_recent',
    'CREATE INDEX playback_recent ON playback_states (last_watched_utc)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sources,
    categories,
    channels,
    movies,
    seriesEntries,
    episodes,
    epgChannels,
    epgProgrammes,
    favourites,
    playbackStates,
    syncStages,
    categorySourceKind,
    channelSourceCategory,
    channelSearch,
    channelEpg,
    movieSourceCategory,
    movieSearch,
    seriesSourceCategory,
    seriesSearch,
    episodeSeries,
    epgLookup,
    favouriteLookup,
    playbackRecent,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$SourcesTableCreateCompanionBuilder = SourcesCompanion Function({
  Value<int> id,
  required String name,
  required SourceKind kind,
  required String url,
  Value<String?> username,
  Value<String?> credentialRef,
  Value<String?> epgUrl,
  Value<bool> enabled,
  Value<int> sortOrder,
  Value<DateTime?> lastSyncedAt,
  required DateTime createdAt,
});
typedef $$SourcesTableUpdateCompanionBuilder = SourcesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<SourceKind> kind,
  Value<String> url,
  Value<String?> username,
  Value<String?> credentialRef,
  Value<String?> epgUrl,
  Value<bool> enabled,
  Value<int> sortOrder,
  Value<DateTime?> lastSyncedAt,
  Value<DateTime> createdAt,
});

class $$SourcesTableFilterComposer
    extends Composer<_$OpenTvDatabase, $SourcesTable> {
  $$SourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SourceKind, SourceKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgUrl => $composableBuilder(
    column: $table.epgUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourcesTableOrderingComposer
    extends Composer<_$OpenTvDatabase, $SourcesTable> {
  $$SourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgUrl => $composableBuilder(
    column: $table.epgUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourcesTableAnnotationComposer
    extends Composer<_$OpenTvDatabase, $SourcesTable> {
  $$SourcesTableAnnotationComposer({
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

  GeneratedColumnWithTypeConverter<SourceKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get epgUrl =>
      $composableBuilder(column: $table.epgUrl, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SourcesTableTableManager
    extends
        RootTableManager<
          _$OpenTvDatabase,
          $SourcesTable,
          Source,
          $$SourcesTableFilterComposer,
          $$SourcesTableOrderingComposer,
          $$SourcesTableAnnotationComposer,
          $$SourcesTableCreateCompanionBuilder,
          $$SourcesTableUpdateCompanionBuilder,
          (Source, BaseReferences<_$OpenTvDatabase, $SourcesTable, Source>),
          Source,
          PrefetchHooks Function()
        > {
  $$SourcesTableTableManager(_$OpenTvDatabase db, $SourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<SourceKind> kind = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> credentialRef = const Value.absent(),
                Value<String?> epgUrl = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                name: name,
                kind: kind,
                url: url,
                username: username,
                credentialRef: credentialRef,
                epgUrl: epgUrl,
                enabled: enabled,
                sortOrder: sortOrder,
                lastSyncedAt: lastSyncedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required SourceKind kind,
                required String url,
                Value<String?> username = const Value.absent(),
                Value<String?> credentialRef = const Value.absent(),
                Value<String?> epgUrl = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                required DateTime createdAt,
              }) => SourcesCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                url: url,
                username: username,
                credentialRef: credentialRef,
                epgUrl: epgUrl,
                enabled: enabled,
                sortOrder: sortOrder,
                lastSyncedAt: lastSyncedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$OpenTvDatabase,
      $SourcesTable,
      Source,
      $$SourcesTableFilterComposer,
      $$SourcesTableOrderingComposer,
      $$SourcesTableAnnotationComposer,
      $$SourcesTableCreateCompanionBuilder,
      $$SourcesTableUpdateCompanionBuilder,
      (Source, BaseReferences<_$OpenTvDatabase, $SourcesTable, Source>),
      Source,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required int sourceId,
  required String remoteId,
  required String name,
  required ItemKind kind,
  Value<int> sortOrder,
  Value<bool> hidden,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> sourceId,
  Value<String> remoteId,
  Value<String> name,
  Value<ItemKind> kind,
  Value<int> sortOrder,
  Value<bool> hidden,
  Value<int> rowid,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$OpenTvDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ItemKind, ItemKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$OpenTvDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$OpenTvDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ItemKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$OpenTvDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (
            Category,
            BaseReferences<_$OpenTvDatabase, $CategoriesTable, Category>,
          ),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$OpenTvDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sourceId = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<ItemKind> kind = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                sourceId: sourceId,
                remoteId: remoteId,
                name: name,
                kind: kind,
                sortOrder: sortOrder,
                hidden: hidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int sourceId,
                required String remoteId,
                required String name,
                required ItemKind kind,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                sourceId: sourceId,
                remoteId: remoteId,
                name: name,
                kind: kind,
                sortOrder: sortOrder,
                hidden: hidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$OpenTvDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$OpenTvDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$ChannelsTableCreateCompanionBuilder = ChannelsCompanion Function({
  required int sourceId,
  required String remoteId,
  required String name,
  required String searchName,
  Value<String?> iconUrl,
  Value<String?> categoryRemoteId,
  Value<String?> epgChannelId,
  Value<int?> number,
  Value<bool> hasArchive,
  Value<int?> archiveDays,
  Value<DateTime?> addedAt,
  Value<bool> hidden,
  Value<String?> streamOptions,
  Value<String?> directUrl,
  Value<int> rowid,
});
typedef $$ChannelsTableUpdateCompanionBuilder = ChannelsCompanion Function({
  Value<int> sourceId,
  Value<String> remoteId,
  Value<String> name,
  Value<String> searchName,
  Value<String?> iconUrl,
  Value<String?> categoryRemoteId,
  Value<String?> epgChannelId,
  Value<int?> number,
  Value<bool> hasArchive,
  Value<int?> archiveDays,
  Value<DateTime?> addedAt,
  Value<bool> hidden,
  Value<String?> streamOptions,
  Value<String?> directUrl,
  Value<int> rowid,
});

class $$ChannelsTableFilterComposer
    extends Composer<_$OpenTvDatabase, $ChannelsTable> {
  $$ChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryRemoteId => $composableBuilder(
    column: $table.categoryRemoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasArchive => $composableBuilder(
    column: $table.hasArchive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archiveDays => $composableBuilder(
    column: $table.archiveDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamOptions => $composableBuilder(
    column: $table.streamOptions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directUrl => $composableBuilder(
    column: $table.directUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChannelsTableOrderingComposer
    extends Composer<_$OpenTvDatabase, $ChannelsTable> {
  $$ChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryRemoteId => $composableBuilder(
    column: $table.categoryRemoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasArchive => $composableBuilder(
    column: $table.hasArchive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archiveDays => $composableBuilder(
    column: $table.archiveDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamOptions => $composableBuilder(
    column: $table.streamOptions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directUrl => $composableBuilder(
    column: $table.directUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChannelsTableAnnotationComposer
    extends Composer<_$OpenTvDatabase, $ChannelsTable> {
  $$ChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumn<String> get categoryRemoteId => $composableBuilder(
    column: $table.categoryRemoteId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<bool> get hasArchive => $composableBuilder(
    column: $table.hasArchive,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archiveDays => $composableBuilder(
    column: $table.archiveDays,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<String> get streamOptions => $composableBuilder(
    column: $table.streamOptions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get directUrl =>
      $composableBuilder(column: $table.directUrl, builder: (column) => column);
}

class $$ChannelsTableTableManager
    extends
        RootTableManager<
          _$OpenTvDatabase,
          $ChannelsTable,
          Channel,
          $$ChannelsTableFilterComposer,
          $$ChannelsTableOrderingComposer,
          $$ChannelsTableAnnotationComposer,
          $$ChannelsTableCreateCompanionBuilder,
          $$ChannelsTableUpdateCompanionBuilder,
          (Channel, BaseReferences<_$OpenTvDatabase, $ChannelsTable, Channel>),
          Channel,
          PrefetchHooks Function()
        > {
  $$ChannelsTableTableManager(_$OpenTvDatabase db, $ChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sourceId = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> searchName = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<String?> categoryRemoteId = const Value.absent(),
                Value<String?> epgChannelId = const Value.absent(),
                Value<int?> number = const Value.absent(),
                Value<bool> hasArchive = const Value.absent(),
                Value<int?> archiveDays = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<String?> streamOptions = const Value.absent(),
                Value<String?> directUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelsCompanion(
                sourceId: sourceId,
                remoteId: remoteId,
                name: name,
                searchName: searchName,
                iconUrl: iconUrl,
                categoryRemoteId: categoryRemoteId,
                epgChannelId: epgChannelId,
                number: number,
                hasArchive: hasArchive,
                archiveDays: archiveDays,
                addedAt: addedAt,
                hidden: hidden,
                streamOptions: streamOptions,
                directUrl: directUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int sourceId,
                required String remoteId,
                required String name,
                required String searchName,
                Value<String?> iconUrl = const Value.absent(),
                Value<String?> categoryRemoteId = const Value.absent(),
                Value<String?> epgChannelId = const Value.absent(),
                Value<int?> number = const Value.absent(),
                Value<bool> hasArchive = const Value.absent(),
                Value<int?> archiveDays = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<String?> streamOptions = const Value.absent(),
                Value<String?> directUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelsCompanion.insert(
                sourceId: sourceId,
                remoteId: remoteId,
                name: name,
                searchName: searchName,
                iconUrl: iconUrl,
                categoryRemoteId: categoryRemoteId,
                epgChannelId: epgChannelId,
                number: number,
                hasArchive: hasArchive,
                archiveDays: archiveDays,
                addedAt: addedAt,
                hidden: hidden,
                streamOptions: streamOptions,
                directUrl: directUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$OpenTvDatabase,
      $ChannelsTable,
      Channel,
      $$ChannelsTableFilterComposer,
      $$ChannelsTableOrderingComposer,
      $$ChannelsTableAnnotationComposer,
      $$ChannelsTableCreateCompanionBuilder,
      $$ChannelsTableUpdateCompanionBuilder,
      (Channel, BaseReferences<_$OpenTvDatabase, $ChannelsTable, Channel>),
      Channel,
      PrefetchHooks Function()
    >;
typedef $$MoviesTableCreateCompanionBuilder = MoviesCompanion Function({
  required int sourceId,
  required String remoteId,
  required String name,
  required String searchName,
  Value<String?> iconUrl,
  Value<String?> categoryRemoteId,
  Value<String?> containerExtension,
  Value<double?> rating,
  Value<DateTime?> addedAt,
  Value<String?> tmdbId,
  Value<bool> hidden,
  Value<String?> streamOptions,
  Value<String?> directUrl,
  Value<int> rowid,
});
typedef $$MoviesTableUpdateCompanionBuilder = MoviesCompanion Function({
  Value<int> sourceId,
  Value<String> remoteId,
  Value<String> name,
  Value<String> searchName,
  Value<String?> iconUrl,
  Value<String?> categoryRemoteId,
  Value<String?> containerExtension,
  Value<double?> rating,
  Value<DateTime?> addedAt,
  Value<String?> tmdbId,
  Value<bool> hidden,
  Value<String?> streamOptions,
  Value<String?> directUrl,
  Value<int> rowid,
});

class $$MoviesTableFilterComposer
    extends Composer<_$OpenTvDatabase, $MoviesTable> {
  $$MoviesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryRemoteId => $composableBuilder(
    column: $table.categoryRemoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get containerExtension => $composableBuilder(
    column: $table.containerExtension,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamOptions => $composableBuilder(
    column: $table.streamOptions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directUrl => $composableBuilder(
    column: $table.directUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MoviesTableOrderingComposer
    extends Composer<_$OpenTvDatabase, $MoviesTable> {
  $$MoviesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryRemoteId => $composableBuilder(
    column: $table.categoryRemoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get containerExtension => $composableBuilder(
    column: $table.containerExtension,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamOptions => $composableBuilder(
    column: $table.streamOptions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directUrl => $composableBuilder(
    column: $table.directUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MoviesTableAnnotationComposer
    extends Composer<_$OpenTvDatabase, $MoviesTable> {
  $$MoviesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumn<String> get categoryRemoteId => $composableBuilder(
    column: $table.categoryRemoteId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get containerExtension => $composableBuilder(
    column: $table.containerExtension,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<String> get streamOptions => $composableBuilder(
    column: $table.streamOptions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get directUrl =>
      $composableBuilder(column: $table.directUrl, builder: (column) => column);
}

class $$MoviesTableTableManager
    extends
        RootTableManager<
          _$OpenTvDatabase,
          $MoviesTable,
          Movie,
          $$MoviesTableFilterComposer,
          $$MoviesTableOrderingComposer,
          $$MoviesTableAnnotationComposer,
          $$MoviesTableCreateCompanionBuilder,
          $$MoviesTableUpdateCompanionBuilder,
          (Movie, BaseReferences<_$OpenTvDatabase, $MoviesTable, Movie>),
          Movie,
          PrefetchHooks Function()
        > {
  $$MoviesTableTableManager(_$OpenTvDatabase db, $MoviesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoviesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoviesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoviesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sourceId = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> searchName = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<String?> categoryRemoteId = const Value.absent(),
                Value<String?> containerExtension = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<String?> tmdbId = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<String?> streamOptions = const Value.absent(),
                Value<String?> directUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MoviesCompanion(
                sourceId: sourceId,
                remoteId: remoteId,
                name: name,
                searchName: searchName,
                iconUrl: iconUrl,
                categoryRemoteId: categoryRemoteId,
                containerExtension: containerExtension,
                rating: rating,
                addedAt: addedAt,
                tmdbId: tmdbId,
                hidden: hidden,
                streamOptions: streamOptions,
                directUrl: directUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int sourceId,
                required String remoteId,
                required String name,
                required String searchName,
                Value<String?> iconUrl = const Value.absent(),
                Value<String?> categoryRemoteId = const Value.absent(),
                Value<String?> containerExtension = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<String?> tmdbId = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<String?> streamOptions = const Value.absent(),
                Value<String?> directUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MoviesCompanion.insert(
                sourceId: sourceId,
                remoteId: remoteId,
                name: name,
                searchName: searchName,
                iconUrl: iconUrl,
                categoryRemoteId: categoryRemoteId,
                containerExtension: containerExtension,
                rating: rating,
                addedAt: addedAt,
                tmdbId: tmdbId,
                hidden: hidden,
                streamOptions: streamOptions,
                directUrl: directUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MoviesTableProcessedTableManager =
    ProcessedTableManager<
      _$OpenTvDatabase,
      $MoviesTable,
      Movie,
      $$MoviesTableFilterComposer,
      $$MoviesTableOrderingComposer,
      $$MoviesTableAnnotationComposer,
      $$MoviesTableCreateCompanionBuilder,
      $$MoviesTableUpdateCompanionBuilder,
      (Movie, BaseReferences<_$OpenTvDatabase, $MoviesTable, Movie>),
      Movie,
      PrefetchHooks Function()
    >;
typedef $$SeriesEntriesTableCreateCompanionBuilder =
    SeriesEntriesCompanion Function({
      required int sourceId,
      required String remoteId,
      required String name,
      required String searchName,
      Value<String?> coverUrl,
      Value<String?> categoryRemoteId,
      Value<String?> plot,
      Value<String?> castList,
      Value<String?> genres,
      Value<double?> rating,
      Value<String?> releaseDate,
      Value<String?> tmdbId,
      Value<DateTime?> lastModified,
      Value<DateTime?> episodesSyncedAt,
      Value<bool> hidden,
      Value<int> rowid,
    });
typedef $$SeriesEntriesTableUpdateCompanionBuilder =
    SeriesEntriesCompanion Function({
      Value<int> sourceId,
      Value<String> remoteId,
      Value<String> name,
      Value<String> searchName,
      Value<String?> coverUrl,
      Value<String?> categoryRemoteId,
      Value<String?> plot,
      Value<String?> castList,
      Value<String?> genres,
      Value<double?> rating,
      Value<String?> releaseDate,
      Value<String?> tmdbId,
      Value<DateTime?> lastModified,
      Value<DateTime?> episodesSyncedAt,
      Value<bool> hidden,
      Value<int> rowid,
    });

class $$SeriesEntriesTableFilterComposer
    extends Composer<_$OpenTvDatabase, $SeriesEntriesTable> {
  $$SeriesEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryRemoteId => $composableBuilder(
    column: $table.categoryRemoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get castList => $composableBuilder(
    column: $table.castList,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genres => $composableBuilder(
    column: $table.genres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get episodesSyncedAt => $composableBuilder(
    column: $table.episodesSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeriesEntriesTableOrderingComposer
    extends Composer<_$OpenTvDatabase, $SeriesEntriesTable> {
  $$SeriesEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryRemoteId => $composableBuilder(
    column: $table.categoryRemoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get castList => $composableBuilder(
    column: $table.castList,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genres => $composableBuilder(
    column: $table.genres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get episodesSyncedAt => $composableBuilder(
    column: $table.episodesSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeriesEntriesTableAnnotationComposer
    extends Composer<_$OpenTvDatabase, $SeriesEntriesTable> {
  $$SeriesEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get categoryRemoteId => $composableBuilder(
    column: $table.categoryRemoteId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get castList =>
      $composableBuilder(column: $table.castList, builder: (column) => column);

  GeneratedColumn<String> get genres =>
      $composableBuilder(column: $table.genres, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get episodesSyncedAt => $composableBuilder(
    column: $table.episodesSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);
}

class $$SeriesEntriesTableTableManager
    extends
        RootTableManager<
          _$OpenTvDatabase,
          $SeriesEntriesTable,
          SeriesEntry,
          $$SeriesEntriesTableFilterComposer,
          $$SeriesEntriesTableOrderingComposer,
          $$SeriesEntriesTableAnnotationComposer,
          $$SeriesEntriesTableCreateCompanionBuilder,
          $$SeriesEntriesTableUpdateCompanionBuilder,
          (
            SeriesEntry,
            BaseReferences<_$OpenTvDatabase, $SeriesEntriesTable, SeriesEntry>,
          ),
          SeriesEntry,
          PrefetchHooks Function()
        > {
  $$SeriesEntriesTableTableManager(
    _$OpenTvDatabase db,
    $SeriesEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sourceId = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> searchName = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> categoryRemoteId = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> castList = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<String?> tmdbId = const Value.absent(),
                Value<DateTime?> lastModified = const Value.absent(),
                Value<DateTime?> episodesSyncedAt = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesEntriesCompanion(
                sourceId: sourceId,
                remoteId: remoteId,
                name: name,
                searchName: searchName,
                coverUrl: coverUrl,
                categoryRemoteId: categoryRemoteId,
                plot: plot,
                castList: castList,
                genres: genres,
                rating: rating,
                releaseDate: releaseDate,
                tmdbId: tmdbId,
                lastModified: lastModified,
                episodesSyncedAt: episodesSyncedAt,
                hidden: hidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int sourceId,
                required String remoteId,
                required String name,
                required String searchName,
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> categoryRemoteId = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> castList = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<String?> tmdbId = const Value.absent(),
                Value<DateTime?> lastModified = const Value.absent(),
                Value<DateTime?> episodesSyncedAt = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesEntriesCompanion.insert(
                sourceId: sourceId,
                remoteId: remoteId,
                name: name,
                searchName: searchName,
                coverUrl: coverUrl,
                categoryRemoteId: categoryRemoteId,
                plot: plot,
                castList: castList,
                genres: genres,
                rating: rating,
                releaseDate: releaseDate,
                tmdbId: tmdbId,
                lastModified: lastModified,
                episodesSyncedAt: episodesSyncedAt,
                hidden: hidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeriesEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$OpenTvDatabase,
      $SeriesEntriesTable,
      SeriesEntry,
      $$SeriesEntriesTableFilterComposer,
      $$SeriesEntriesTableOrderingComposer,
      $$SeriesEntriesTableAnnotationComposer,
      $$SeriesEntriesTableCreateCompanionBuilder,
      $$SeriesEntriesTableUpdateCompanionBuilder,
      (
        SeriesEntry,
        BaseReferences<_$OpenTvDatabase, $SeriesEntriesTable, SeriesEntry>,
      ),
      SeriesEntry,
      PrefetchHooks Function()
    >;
typedef $$EpisodesTableCreateCompanionBuilder = EpisodesCompanion Function({
  required int sourceId,
  required String remoteId,
  required String seriesRemoteId,
  required String title,
  Value<int?> season,
  Value<int?> episodeNumber,
  Value<String?> containerExtension,
  Value<String?> plot,
  Value<int?> durationSeconds,
  Value<String?> iconUrl,
  Value<DateTime?> addedAt,
  Value<String?> directUrl,
  Value<int> rowid,
});
typedef $$EpisodesTableUpdateCompanionBuilder = EpisodesCompanion Function({
  Value<int> sourceId,
  Value<String> remoteId,
  Value<String> seriesRemoteId,
  Value<String> title,
  Value<int?> season,
  Value<int?> episodeNumber,
  Value<String?> containerExtension,
  Value<String?> plot,
  Value<int?> durationSeconds,
  Value<String?> iconUrl,
  Value<DateTime?> addedAt,
  Value<String?> directUrl,
  Value<int> rowid,
});

class $$EpisodesTableFilterComposer
    extends Composer<_$OpenTvDatabase, $EpisodesTable> {
  $$EpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesRemoteId => $composableBuilder(
    column: $table.seriesRemoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get containerExtension => $composableBuilder(
    column: $table.containerExtension,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directUrl => $composableBuilder(
    column: $table.directUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpisodesTableOrderingComposer
    extends Composer<_$OpenTvDatabase, $EpisodesTable> {
  $$EpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesRemoteId => $composableBuilder(
    column: $table.seriesRemoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get containerExtension => $composableBuilder(
    column: $table.containerExtension,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directUrl => $composableBuilder(
    column: $table.directUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpisodesTableAnnotationComposer
    extends Composer<_$OpenTvDatabase, $EpisodesTable> {
  $$EpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get seriesRemoteId => $composableBuilder(
    column: $table.seriesRemoteId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get containerExtension => $composableBuilder(
    column: $table.containerExtension,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get directUrl =>
      $composableBuilder(column: $table.directUrl, builder: (column) => column);
}

class $$EpisodesTableTableManager
    extends
        RootTableManager<
          _$OpenTvDatabase,
          $EpisodesTable,
          Episode,
          $$EpisodesTableFilterComposer,
          $$EpisodesTableOrderingComposer,
          $$EpisodesTableAnnotationComposer,
          $$EpisodesTableCreateCompanionBuilder,
          $$EpisodesTableUpdateCompanionBuilder,
          (Episode, BaseReferences<_$OpenTvDatabase, $EpisodesTable, Episode>),
          Episode,
          PrefetchHooks Function()
        > {
  $$EpisodesTableTableManager(_$OpenTvDatabase db, $EpisodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sourceId = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String> seriesRemoteId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episodeNumber = const Value.absent(),
                Value<String?> containerExtension = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<String?> directUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpisodesCompanion(
                sourceId: sourceId,
                remoteId: remoteId,
                seriesRemoteId: seriesRemoteId,
                title: title,
                season: season,
                episodeNumber: episodeNumber,
                containerExtension: containerExtension,
                plot: plot,
                durationSeconds: durationSeconds,
                iconUrl: iconUrl,
                addedAt: addedAt,
                directUrl: directUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int sourceId,
                required String remoteId,
                required String seriesRemoteId,
                required String title,
                Value<int?> season = const Value.absent(),
                Value<int?> episodeNumber = const Value.absent(),
                Value<String?> containerExtension = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<String?> directUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpisodesCompanion.insert(
                sourceId: sourceId,
                remoteId: remoteId,
                seriesRemoteId: seriesRemoteId,
                title: title,
                season: season,
                episodeNumber: episodeNumber,
                containerExtension: containerExtension,
                plot: plot,
                durationSeconds: durationSeconds,
                iconUrl: iconUrl,
                addedAt: addedAt,
                directUrl: directUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$OpenTvDatabase,
      $EpisodesTable,
      Episode,
      $$EpisodesTableFilterComposer,
      $$EpisodesTableOrderingComposer,
      $$EpisodesTableAnnotationComposer,
      $$EpisodesTableCreateCompanionBuilder,
      $$EpisodesTableUpdateCompanionBuilder,
      (Episode, BaseReferences<_$OpenTvDatabase, $EpisodesTable, Episode>),
      Episode,
      PrefetchHooks Function()
    >;
typedef $$EpgChannelsTableCreateCompanionBuilder =
    EpgChannelsCompanion Function({
      required int sourceId,
      required String channelId,
      Value<String?> displayName,
      Value<String?> iconUrl,
      Value<int> rowid,
    });
typedef $$EpgChannelsTableUpdateCompanionBuilder =
    EpgChannelsCompanion Function({
      Value<int> sourceId,
      Value<String> channelId,
      Value<String?> displayName,
      Value<String?> iconUrl,
      Value<int> rowid,
    });

class $$EpgChannelsTableFilterComposer
    extends Composer<_$OpenTvDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpgChannelsTableOrderingComposer
    extends Composer<_$OpenTvDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpgChannelsTableAnnotationComposer
    extends Composer<_$OpenTvDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);
}

class $$EpgChannelsTableTableManager
    extends
        RootTableManager<
          _$OpenTvDatabase,
          $EpgChannelsTable,
          EpgChannel,
          $$EpgChannelsTableFilterComposer,
          $$EpgChannelsTableOrderingComposer,
          $$EpgChannelsTableAnnotationComposer,
          $$EpgChannelsTableCreateCompanionBuilder,
          $$EpgChannelsTableUpdateCompanionBuilder,
          (
            EpgChannel,
            BaseReferences<_$OpenTvDatabase, $EpgChannelsTable, EpgChannel>,
          ),
          EpgChannel,
          PrefetchHooks Function()
        > {
  $$EpgChannelsTableTableManager(_$OpenTvDatabase db, $EpgChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sourceId = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgChannelsCompanion(
                sourceId: sourceId,
                channelId: channelId,
                displayName: displayName,
                iconUrl: iconUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int sourceId,
                required String channelId,
                Value<String?> displayName = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgChannelsCompanion.insert(
                sourceId: sourceId,
                channelId: channelId,
                displayName: displayName,
                iconUrl: iconUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpgChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$OpenTvDatabase,
      $EpgChannelsTable,
      EpgChannel,
      $$EpgChannelsTableFilterComposer,
      $$EpgChannelsTableOrderingComposer,
      $$EpgChannelsTableAnnotationComposer,
      $$EpgChannelsTableCreateCompanionBuilder,
      $$EpgChannelsTableUpdateCompanionBuilder,
      (
        EpgChannel,
        BaseReferences<_$OpenTvDatabase, $EpgChannelsTable, EpgChannel>,
      ),
      EpgChannel,
      PrefetchHooks Function()
    >;
typedef $$EpgProgrammesTableCreateCompanionBuilder =
    EpgProgrammesCompanion Function({
      Value<int> id,
      required int sourceId,
      required String channelId,
      required DateTime startUtc,
      Value<DateTime?> stopUtc,
      Value<String?> title,
      Value<String?> subTitle,
      Value<String?> description,
      Value<String?> categories,
      Value<String?> iconUrl,
      Value<String?> episodeNumber,
    });
typedef $$EpgProgrammesTableUpdateCompanionBuilder =
    EpgProgrammesCompanion Function({
      Value<int> id,
      Value<int> sourceId,
      Value<String> channelId,
      Value<DateTime> startUtc,
      Value<DateTime?> stopUtc,
      Value<String?> title,
      Value<String?> subTitle,
      Value<String?> description,
      Value<String?> categories,
      Value<String?> iconUrl,
      Value<String?> episodeNumber,
    });

class $$EpgProgrammesTableFilterComposer
    extends Composer<_$OpenTvDatabase, $EpgProgrammesTable> {
  $$EpgProgrammesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get stopUtc => $composableBuilder(
    column: $table.stopUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subTitle => $composableBuilder(
    column: $table.subTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpgProgrammesTableOrderingComposer
    extends Composer<_$OpenTvDatabase, $EpgProgrammesTable> {
  $$EpgProgrammesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get stopUtc => $composableBuilder(
    column: $table.stopUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subTitle => $composableBuilder(
    column: $table.subTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpgProgrammesTableAnnotationComposer
    extends Composer<_$OpenTvDatabase, $EpgProgrammesTable> {
  $$EpgProgrammesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<DateTime> get startUtc =>
      $composableBuilder(column: $table.startUtc, builder: (column) => column);

  GeneratedColumn<DateTime> get stopUtc =>
      $composableBuilder(column: $table.stopUtc, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subTitle =>
      $composableBuilder(column: $table.subTitle, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categories => $composableBuilder(
    column: $table.categories,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumn<String> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );
}

class $$EpgProgrammesTableTableManager
    extends
        RootTableManager<
          _$OpenTvDatabase,
          $EpgProgrammesTable,
          EpgProgramme,
          $$EpgProgrammesTableFilterComposer,
          $$EpgProgrammesTableOrderingComposer,
          $$EpgProgrammesTableAnnotationComposer,
          $$EpgProgrammesTableCreateCompanionBuilder,
          $$EpgProgrammesTableUpdateCompanionBuilder,
          (
            EpgProgramme,
            BaseReferences<_$OpenTvDatabase, $EpgProgrammesTable, EpgProgramme>,
          ),
          EpgProgramme,
          PrefetchHooks Function()
        > {
  $$EpgProgrammesTableTableManager(
    _$OpenTvDatabase db,
    $EpgProgrammesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgProgrammesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgProgrammesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgProgrammesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sourceId = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<DateTime> startUtc = const Value.absent(),
                Value<DateTime?> stopUtc = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> subTitle = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> categories = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<String?> episodeNumber = const Value.absent(),
              }) => EpgProgrammesCompanion(
                id: id,
                sourceId: sourceId,
                channelId: channelId,
                startUtc: startUtc,
                stopUtc: stopUtc,
                title: title,
                subTitle: subTitle,
                description: description,
                categories: categories,
                iconUrl: iconUrl,
                episodeNumber: episodeNumber,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sourceId,
                required String channelId,
                required DateTime startUtc,
                Value<DateTime?> stopUtc = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> subTitle = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> categories = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<String?> episodeNumber = const Value.absent(),
              }) => EpgProgrammesCompanion.insert(
                id: id,
                sourceId: sourceId,
                channelId: channelId,
                startUtc: startUtc,
                stopUtc: stopUtc,
                title: title,
                subTitle: subTitle,
                description: description,
                categories: categories,
                iconUrl: iconUrl,
                episodeNumber: episodeNumber,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpgProgrammesTableProcessedTableManager =
    ProcessedTableManager<
      _$OpenTvDatabase,
      $EpgProgrammesTable,
      EpgProgramme,
      $$EpgProgrammesTableFilterComposer,
      $$EpgProgrammesTableOrderingComposer,
      $$EpgProgrammesTableAnnotationComposer,
      $$EpgProgrammesTableCreateCompanionBuilder,
      $$EpgProgrammesTableUpdateCompanionBuilder,
      (
        EpgProgramme,
        BaseReferences<_$OpenTvDatabase, $EpgProgrammesTable, EpgProgramme>,
      ),
      EpgProgramme,
      PrefetchHooks Function()
    >;
typedef $$FavouritesTableCreateCompanionBuilder = FavouritesCompanion Function({
  required int sourceId,
  required ItemKind itemKind,
  required String itemRemoteId,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$FavouritesTableUpdateCompanionBuilder = FavouritesCompanion Function({
  Value<int> sourceId,
  Value<ItemKind> itemKind,
  Value<String> itemRemoteId,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

class $$FavouritesTableFilterComposer
    extends Composer<_$OpenTvDatabase, $FavouritesTable> {
  $$FavouritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ItemKind, ItemKind, String> get itemKind =>
      $composableBuilder(
        column: $table.itemKind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get itemRemoteId => $composableBuilder(
    column: $table.itemRemoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavouritesTableOrderingComposer
    extends Composer<_$OpenTvDatabase, $FavouritesTable> {
  $$FavouritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemKind => $composableBuilder(
    column: $table.itemKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemRemoteId => $composableBuilder(
    column: $table.itemRemoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavouritesTableAnnotationComposer
    extends Composer<_$OpenTvDatabase, $FavouritesTable> {
  $$FavouritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ItemKind, String> get itemKind =>
      $composableBuilder(column: $table.itemKind, builder: (column) => column);

  GeneratedColumn<String> get itemRemoteId => $composableBuilder(
    column: $table.itemRemoteId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$FavouritesTableTableManager
    extends
        RootTableManager<
          _$OpenTvDatabase,
          $FavouritesTable,
          Favourite,
          $$FavouritesTableFilterComposer,
          $$FavouritesTableOrderingComposer,
          $$FavouritesTableAnnotationComposer,
          $$FavouritesTableCreateCompanionBuilder,
          $$FavouritesTableUpdateCompanionBuilder,
          (
            Favourite,
            BaseReferences<_$OpenTvDatabase, $FavouritesTable, Favourite>,
          ),
          Favourite,
          PrefetchHooks Function()
        > {
  $$FavouritesTableTableManager(_$OpenTvDatabase db, $FavouritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavouritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavouritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavouritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sourceId = const Value.absent(),
                Value<ItemKind> itemKind = const Value.absent(),
                Value<String> itemRemoteId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavouritesCompanion(
                sourceId: sourceId,
                itemKind: itemKind,
                itemRemoteId: itemRemoteId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int sourceId,
                required ItemKind itemKind,
                required String itemRemoteId,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => FavouritesCompanion.insert(
                sourceId: sourceId,
                itemKind: itemKind,
                itemRemoteId: itemRemoteId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavouritesTableProcessedTableManager =
    ProcessedTableManager<
      _$OpenTvDatabase,
      $FavouritesTable,
      Favourite,
      $$FavouritesTableFilterComposer,
      $$FavouritesTableOrderingComposer,
      $$FavouritesTableAnnotationComposer,
      $$FavouritesTableCreateCompanionBuilder,
      $$FavouritesTableUpdateCompanionBuilder,
      (
        Favourite,
        BaseReferences<_$OpenTvDatabase, $FavouritesTable, Favourite>,
      ),
      Favourite,
      PrefetchHooks Function()
    >;
typedef $$PlaybackStatesTableCreateCompanionBuilder =
    PlaybackStatesCompanion Function({
      required int sourceId,
      required ItemKind itemKind,
      required String itemRemoteId,
      Value<int?> positionMs,
      Value<int?> durationMs,
      required DateTime lastWatchedUtc,
      Value<bool> completed,
      Value<String?> parentRemoteId,
      Value<int> rowid,
    });
typedef $$PlaybackStatesTableUpdateCompanionBuilder =
    PlaybackStatesCompanion Function({
      Value<int> sourceId,
      Value<ItemKind> itemKind,
      Value<String> itemRemoteId,
      Value<int?> positionMs,
      Value<int?> durationMs,
      Value<DateTime> lastWatchedUtc,
      Value<bool> completed,
      Value<String?> parentRemoteId,
      Value<int> rowid,
    });

class $$PlaybackStatesTableFilterComposer
    extends Composer<_$OpenTvDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ItemKind, ItemKind, String> get itemKind =>
      $composableBuilder(
        column: $table.itemKind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get itemRemoteId => $composableBuilder(
    column: $table.itemRemoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastWatchedUtc => $composableBuilder(
    column: $table.lastWatchedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentRemoteId => $composableBuilder(
    column: $table.parentRemoteId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackStatesTableOrderingComposer
    extends Composer<_$OpenTvDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemKind => $composableBuilder(
    column: $table.itemKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemRemoteId => $composableBuilder(
    column: $table.itemRemoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastWatchedUtc => $composableBuilder(
    column: $table.lastWatchedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentRemoteId => $composableBuilder(
    column: $table.parentRemoteId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackStatesTableAnnotationComposer
    extends Composer<_$OpenTvDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ItemKind, String> get itemKind =>
      $composableBuilder(column: $table.itemKind, builder: (column) => column);

  GeneratedColumn<String> get itemRemoteId => $composableBuilder(
    column: $table.itemRemoteId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastWatchedUtc => $composableBuilder(
    column: $table.lastWatchedUtc,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<String> get parentRemoteId => $composableBuilder(
    column: $table.parentRemoteId,
    builder: (column) => column,
  );
}

class $$PlaybackStatesTableTableManager
    extends
        RootTableManager<
          _$OpenTvDatabase,
          $PlaybackStatesTable,
          PlaybackState,
          $$PlaybackStatesTableFilterComposer,
          $$PlaybackStatesTableOrderingComposer,
          $$PlaybackStatesTableAnnotationComposer,
          $$PlaybackStatesTableCreateCompanionBuilder,
          $$PlaybackStatesTableUpdateCompanionBuilder,
          (
            PlaybackState,
            BaseReferences<
              _$OpenTvDatabase,
              $PlaybackStatesTable,
              PlaybackState
            >,
          ),
          PlaybackState,
          PrefetchHooks Function()
        > {
  $$PlaybackStatesTableTableManager(
    _$OpenTvDatabase db,
    $PlaybackStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sourceId = const Value.absent(),
                Value<ItemKind> itemKind = const Value.absent(),
                Value<String> itemRemoteId = const Value.absent(),
                Value<int?> positionMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<DateTime> lastWatchedUtc = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<String?> parentRemoteId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackStatesCompanion(
                sourceId: sourceId,
                itemKind: itemKind,
                itemRemoteId: itemRemoteId,
                positionMs: positionMs,
                durationMs: durationMs,
                lastWatchedUtc: lastWatchedUtc,
                completed: completed,
                parentRemoteId: parentRemoteId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int sourceId,
                required ItemKind itemKind,
                required String itemRemoteId,
                Value<int?> positionMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required DateTime lastWatchedUtc,
                Value<bool> completed = const Value.absent(),
                Value<String?> parentRemoteId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackStatesCompanion.insert(
                sourceId: sourceId,
                itemKind: itemKind,
                itemRemoteId: itemRemoteId,
                positionMs: positionMs,
                durationMs: durationMs,
                lastWatchedUtc: lastWatchedUtc,
                completed: completed,
                parentRemoteId: parentRemoteId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$OpenTvDatabase,
      $PlaybackStatesTable,
      PlaybackState,
      $$PlaybackStatesTableFilterComposer,
      $$PlaybackStatesTableOrderingComposer,
      $$PlaybackStatesTableAnnotationComposer,
      $$PlaybackStatesTableCreateCompanionBuilder,
      $$PlaybackStatesTableUpdateCompanionBuilder,
      (
        PlaybackState,
        BaseReferences<_$OpenTvDatabase, $PlaybackStatesTable, PlaybackState>,
      ),
      PlaybackState,
      PrefetchHooks Function()
    >;
typedef $$SyncStagesTableCreateCompanionBuilder = SyncStagesCompanion Function({
  required int sourceId,
  required String stage,
  required SyncStatus status,
  required DateTime updatedAt,
  Value<int> itemsWritten,
  Value<String?> error,
  Value<int> rowid,
});
typedef $$SyncStagesTableUpdateCompanionBuilder = SyncStagesCompanion Function({
  Value<int> sourceId,
  Value<String> stage,
  Value<SyncStatus> status,
  Value<DateTime> updatedAt,
  Value<int> itemsWritten,
  Value<String?> error,
  Value<int> rowid,
});

class $$SyncStagesTableFilterComposer
    extends Composer<_$OpenTvDatabase, $SyncStagesTable> {
  $$SyncStagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncStatus, SyncStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemsWritten => $composableBuilder(
    column: $table.itemsWritten,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStagesTableOrderingComposer
    extends Composer<_$OpenTvDatabase, $SyncStagesTable> {
  $$SyncStagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemsWritten => $composableBuilder(
    column: $table.itemsWritten,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStagesTableAnnotationComposer
    extends Composer<_$OpenTvDatabase, $SyncStagesTable> {
  $$SyncStagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SyncStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get itemsWritten => $composableBuilder(
    column: $table.itemsWritten,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$SyncStagesTableTableManager
    extends
        RootTableManager<
          _$OpenTvDatabase,
          $SyncStagesTable,
          SyncStage,
          $$SyncStagesTableFilterComposer,
          $$SyncStagesTableOrderingComposer,
          $$SyncStagesTableAnnotationComposer,
          $$SyncStagesTableCreateCompanionBuilder,
          $$SyncStagesTableUpdateCompanionBuilder,
          (
            SyncStage,
            BaseReferences<_$OpenTvDatabase, $SyncStagesTable, SyncStage>,
          ),
          SyncStage,
          PrefetchHooks Function()
        > {
  $$SyncStagesTableTableManager(_$OpenTvDatabase db, $SyncStagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sourceId = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<SyncStatus> status = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> itemsWritten = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStagesCompanion(
                sourceId: sourceId,
                stage: stage,
                status: status,
                updatedAt: updatedAt,
                itemsWritten: itemsWritten,
                error: error,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int sourceId,
                required String stage,
                required SyncStatus status,
                required DateTime updatedAt,
                Value<int> itemsWritten = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStagesCompanion.insert(
                sourceId: sourceId,
                stage: stage,
                status: status,
                updatedAt: updatedAt,
                itemsWritten: itemsWritten,
                error: error,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStagesTableProcessedTableManager =
    ProcessedTableManager<
      _$OpenTvDatabase,
      $SyncStagesTable,
      SyncStage,
      $$SyncStagesTableFilterComposer,
      $$SyncStagesTableOrderingComposer,
      $$SyncStagesTableAnnotationComposer,
      $$SyncStagesTableCreateCompanionBuilder,
      $$SyncStagesTableUpdateCompanionBuilder,
      (
        SyncStage,
        BaseReferences<_$OpenTvDatabase, $SyncStagesTable, SyncStage>,
      ),
      SyncStage,
      PrefetchHooks Function()
    >;

class $OpenTvDatabaseManager {
  final _$OpenTvDatabase _db;
  $OpenTvDatabaseManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db, _db.channels);
  $$MoviesTableTableManager get movies =>
      $$MoviesTableTableManager(_db, _db.movies);
  $$SeriesEntriesTableTableManager get seriesEntries =>
      $$SeriesEntriesTableTableManager(_db, _db.seriesEntries);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
  $$EpgChannelsTableTableManager get epgChannels =>
      $$EpgChannelsTableTableManager(_db, _db.epgChannels);
  $$EpgProgrammesTableTableManager get epgProgrammes =>
      $$EpgProgrammesTableTableManager(_db, _db.epgProgrammes);
  $$FavouritesTableTableManager get favourites =>
      $$FavouritesTableTableManager(_db, _db.favourites);
  $$PlaybackStatesTableTableManager get playbackStates =>
      $$PlaybackStatesTableTableManager(_db, _db.playbackStates);
  $$SyncStagesTableTableManager get syncStages =>
      $$SyncStagesTableTableManager(_db, _db.syncStages);
}
