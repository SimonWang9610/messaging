import 'sql_builder.dart';

typedef ModelMapper<T> = T Function(Map<String, dynamic>);
typedef ModelConverter<T> = Map<String, dynamic> Function(T);

typedef ModelDeletionBuilder<T> = DeleteBuilder Function(T);

typedef UpsertBuilderFromData<T> = UpsertBuilder Function(T);

abstract class DatabaseInterface {
  // Future<void> init([bool dropAll = false]);
  // Future<void> close();

  Future<List<T>> load<T>(
    QueryBuilder query, {
    required ModelMapper<T> mapToModel,
  }) =>
      throw UnimplementedError("Not implemented for Web");

  Future<void> delete<T>(
    List<T> data, {
    required ModelDeletionBuilder<T> deletionBuilder,
  }) =>
      throw UnimplementedError("Not implemented for Web");

  Future<void> update<T>(
    String table,
    List<T> data, {
    required ModelConverter<T> toDatabaseMap,
  }) =>
      throw UnimplementedError("Not implemented for Web");

  Future<void> upsert<T>(
    List<T> data, {
    required UpsertBuilderFromData<T> upsertBuilder,
  }) =>
      throw UnimplementedError("Not implemented for Web");
}
