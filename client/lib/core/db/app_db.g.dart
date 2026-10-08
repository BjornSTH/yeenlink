// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $ServersTable extends Servers with TableInfo<$ServersTable, ServerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _serverPubMeta = const VerificationMeta('serverPub');
  @override
  late final GeneratedColumn<Uint8List> serverPub = GeneratedColumn<Uint8List>(
    'server_pub',
    aliasedName,
    false,
    check: () => serverPub.length.equals(32),
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _positionMeta = const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, serverPub, host, port, name, position, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_pub')) {
      context.handle(
        _serverPubMeta,
        serverPub.isAcceptableOrUnknown(data['server_pub']!, _serverPubMeta),
      );
    } else if (isInserting) {
      context.missing(_serverPubMeta);
    }
    if (data.containsKey('host')) {
      context.handle(_hostMeta, host.isAcceptableOrUnknown(data['host']!, _hostMeta));
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('port')) {
      context.handle(_portMeta, port.isAcceptableOrUnknown(data['port']!, _portMeta));
    } else if (isInserting) {
      context.missing(_portMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta, addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      serverPub: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}server_pub'],
      )!,
      host: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}host'])!,
      port: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}port'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $ServersTable createAlias(String alias) {
    return $ServersTable(attachedDatabase, alias);
  }
}

class ServerRow extends DataClass implements Insertable<ServerRow> {
  final int id;

  /// Ключ сервера Ed25519 — личность сервера; адрес может меняться.
  final Uint8List serverPub;

  /// Адрес, по которому подключались последний раз.
  final String host;
  final int port;

  /// Название из server_info — для рельсы, пока нет связи.
  final String name;

  /// Порядок в рельсе.
  final int position;

  /// unix-время в мс.
  final int addedAt;
  const ServerRow({
    required this.id,
    required this.serverPub,
    required this.host,
    required this.port,
    required this.name,
    required this.position,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['server_pub'] = Variable<Uint8List>(serverPub);
    map['host'] = Variable<String>(host);
    map['port'] = Variable<int>(port);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  ServersCompanion toCompanion(bool nullToAbsent) {
    return ServersCompanion(
      id: Value(id),
      serverPub: Value(serverPub),
      host: Value(host),
      port: Value(port),
      name: Value(name),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory ServerRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerRow(
      id: serializer.fromJson<int>(json['id']),
      serverPub: serializer.fromJson<Uint8List>(json['serverPub']),
      host: serializer.fromJson<String>(json['host']),
      port: serializer.fromJson<int>(json['port']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverPub': serializer.toJson<Uint8List>(serverPub),
      'host': serializer.toJson<String>(host),
      'port': serializer.toJson<int>(port),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  ServerRow copyWith({
    int? id,
    Uint8List? serverPub,
    String? host,
    int? port,
    String? name,
    int? position,
    int? addedAt,
  }) => ServerRow(
    id: id ?? this.id,
    serverPub: serverPub ?? this.serverPub,
    host: host ?? this.host,
    port: port ?? this.port,
    name: name ?? this.name,
    position: position ?? this.position,
    addedAt: addedAt ?? this.addedAt,
  );
  ServerRow copyWithCompanion(ServersCompanion data) {
    return ServerRow(
      id: data.id.present ? data.id.value : this.id,
      serverPub: data.serverPub.present ? data.serverPub.value : this.serverPub,
      host: data.host.present ? data.host.value : this.host,
      port: data.port.present ? data.port.value : this.port,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerRow(')
          ..write('id: $id, ')
          ..write('serverPub: $serverPub, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, $driftBlobEquality.hash(serverPub), host, port, name, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerRow &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.serverPub, this.serverPub) &&
          other.host == this.host &&
          other.port == this.port &&
          other.name == this.name &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class ServersCompanion extends UpdateCompanion<ServerRow> {
  final Value<int> id;
  final Value<Uint8List> serverPub;
  final Value<String> host;
  final Value<int> port;
  final Value<String> name;
  final Value<int> position;
  final Value<int> addedAt;
  const ServersCompanion({
    this.id = const Value.absent(),
    this.serverPub = const Value.absent(),
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  ServersCompanion.insert({
    this.id = const Value.absent(),
    required Uint8List serverPub,
    required String host,
    required int port,
    required String name,
    required int position,
    required int addedAt,
  }) : serverPub = Value(serverPub),
       host = Value(host),
       port = Value(port),
       name = Value(name),
       position = Value(position),
       addedAt = Value(addedAt);
  static Insertable<ServerRow> custom({
    Expression<int>? id,
    Expression<Uint8List>? serverPub,
    Expression<String>? host,
    Expression<int>? port,
    Expression<String>? name,
    Expression<int>? position,
    Expression<int>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverPub != null) 'server_pub': serverPub,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  ServersCompanion copyWith({
    Value<int>? id,
    Value<Uint8List>? serverPub,
    Value<String>? host,
    Value<int>? port,
    Value<String>? name,
    Value<int>? position,
    Value<int>? addedAt,
  }) {
    return ServersCompanion(
      id: id ?? this.id,
      serverPub: serverPub ?? this.serverPub,
      host: host ?? this.host,
      port: port ?? this.port,
      name: name ?? this.name,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverPub.present) {
      map['server_pub'] = Variable<Uint8List>(serverPub.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServersCompanion(')
          ..write('id: $id, ')
          ..write('serverPub: $serverPub, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $ServersTable servers = $ServersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [servers];
}

typedef $$ServersTableCreateCompanionBuilder =
    ServersCompanion Function({
      Value<int> id,
      required Uint8List serverPub,
      required String host,
      required int port,
      required String name,
      required int position,
      required int addedAt,
    });
typedef $$ServersTableUpdateCompanionBuilder =
    ServersCompanion Function({
      Value<int> id,
      Value<Uint8List> serverPub,
      Value<String> host,
      Value<int> port,
      Value<String> name,
      Value<int> position,
      Value<int> addedAt,
    });

class $$ServersTableFilterComposer extends Composer<_$AppDb, $ServersTable> {
  $$ServersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get serverPub =>
      $composableBuilder(column: $table.serverPub, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$ServersTableOrderingComposer extends Composer<_$AppDb, $ServersTable> {
  $$ServersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get serverPub =>
      $composableBuilder(column: $table.serverPub, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$ServersTableAnnotationComposer extends Composer<_$AppDb, $ServersTable> {
  $$ServersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get serverPub =>
      $composableBuilder(column: $table.serverPub, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$ServersTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ServersTable,
          ServerRow,
          $$ServersTableFilterComposer,
          $$ServersTableOrderingComposer,
          $$ServersTableAnnotationComposer,
          $$ServersTableCreateCompanionBuilder,
          $$ServersTableUpdateCompanionBuilder,
          (ServerRow, BaseReferences<_$AppDb, $ServersTable, ServerRow>),
          ServerRow,
          PrefetchHooks Function()
        > {
  $$ServersTableTableManager(_$AppDb db, $ServersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ServersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ServersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<Uint8List> serverPub = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
              }) => ServersCompanion(
                id: id,
                serverPub: serverPub,
                host: host,
                port: port,
                name: name,
                position: position,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Uint8List serverPub,
                required String host,
                required int port,
                required String name,
                required int position,
                required int addedAt,
              }) => ServersCompanion.insert(
                id: id,
                serverPub: serverPub,
                host: host,
                port: port,
                name: name,
                position: position,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ServersTable, ServerRow>(table),
                  BaseReferences<_$AppDb, $ServersTable, ServerRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ServersTable,
      ServerRow,
      $$ServersTableFilterComposer,
      $$ServersTableOrderingComposer,
      $$ServersTableAnnotationComposer,
      $$ServersTableCreateCompanionBuilder,
      $$ServersTableUpdateCompanionBuilder,
      (ServerRow, BaseReferences<_$AppDb, $ServersTable, ServerRow>),
      ServerRow,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$ServersTableTableManager get servers => $$ServersTableTableManager(_db, _db.servers);
}
