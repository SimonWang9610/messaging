class QueryBuilder {
  final String table;
  final bool distinct;
  final List<String>? columns;
  final String? where;
  final List<Object?>? whereArgs;
  final String? groupBy;
  final String? having;
  final String? orderBy;
  final int? limit;
  final int? offset;

  const QueryBuilder(
    this.table, {
    this.distinct = true,
    this.columns,
    this.where,
    this.whereArgs,
    this.orderBy,
    this.limit,
    this.offset,
    this.groupBy,
    this.having,
  });
}

class DeleteBuilder {
  final String table;
  final String where;
  final List<Object?> whereArgs;

  const DeleteBuilder(
    this.table, {
    required this.where,
    required this.whereArgs,
  });
}

// INSERT INTO phonebook(name,phonenumber) VALUES('Alice','704-555-1212')
//   ON CONFLICT(name) DO UPDATE SET phonenumber=excluded.phonenumber;
class UpsertBuilder {
  final String table;
  final Map<String, dynamic> rowData;

  /// the columns should be primary key/unique
  final List<String> conflictColumns;
  final Map<String, dynamic> conflictUpdates;
  final bool ignoreNullForConflict;

  UpsertBuilder(
    this.table, {
    required this.rowData,
    this.conflictColumns = const [],
    this.conflictUpdates = const {},
    this.ignoreNullForConflict = true,
  }) {
    build();
  }

  String sql = "";
  List<Object?> arguments = [];

  void build() {
    final buf = StringBuffer();

    buf.write("INSERT INTO ");
    buf.write(_escapeName(table));
    buf.write(" (");

    final valueBuf = StringBuffer(") VALUES (");

    int i = 0;

    for (final entry in rowData.entries) {
      if (i++ > 0) {
        valueBuf.write(",");
        buf.write(",");
      }

      buf.write(_escapeName(entry.key));

      if (entry.value == null) {
        valueBuf.write("NULL");
      } else {
        valueBuf.write("?");
        arguments.add(entry.value);
      }
    }

    valueBuf.write(")");
    buf.write(valueBuf);

    if (conflictUpdates.isNotEmpty && conflictColumns.isNotEmpty) {
      _buildConflicts(buf);
    }

    sql = buf.toString();
  }

  void _buildConflicts(StringBuffer insertBuf) {
    final buf = StringBuffer(" ON CONFLICT(");

    int i = 0;

    for (final col in conflictColumns) {
      if (i++ > 0) {
        buf.write(",");
      }

      buf.write(_escapeName(col));
    }
    buf.write(") DO UPDATE SET ");

    i = 0;

    for (final entry in conflictUpdates.entries) {
      if (entry.value != null || !ignoreNullForConflict) {
        if (i > 0) {
          buf.write(",");
        }

        buf.write(_escapeName(entry.key));
        buf.write("=?");
        arguments.add(entry.value);
        i++;
      }
    }

    if (i > 0) {
      insertBuf.write(buf);
    }
  }
}

String _escapeName(String name) {
  if (_escapedNames.contains(name.toLowerCase())) {
    return '"$name"';
  }
  return name;
}

final Set<String> _escapedNames = <String>{
  'add',
  'all',
  'alter',
  'and',
  'as',
  'autoincrement',
  'between',
  'case',
  'check',
  'collate',
  'commit',
  'constraint',
  'create',
  'default',
  'deferrable',
  'delete',
  'distinct',
  'drop',
  'else',
  'escape',
  'except',
  'exists',
  'foreign',
  'from',
  'group',
  'having',
  'if',
  'in',
  'index',
  'insert',
  'intersect',
  'into',
  'is',
  'isnull',
  'join',
  'limit',
  'not',
  'notnull',
  'null',
  'on',
  'or',
  'order',
  'primary',
  'references',
  'select',
  'set',
  'table',
  'then',
  'to',
  'transaction',
  'union',
  'unique',
  'update',
  'using',
  'values',
  'when',
  'where'
};
