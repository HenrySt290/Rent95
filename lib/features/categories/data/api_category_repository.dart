import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../shared/models/category.dart';
import 'category_repository.dart';

class ApiCategoryRepository implements CategoryRepository {
  ApiCategoryRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<Category>> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/categories');
    return decodeList(res, _fromApi);
  }

  @override
  Future<List<Category>> tree() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/categories/tree');
    return decodeList(res, _fromApi);
  }

  Category _fromApi(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
        slug: j['slug'] as String,
        allowedModes: ((j['allowedModes'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        iconName: (j['iconName'] as String?) ?? 'category',
        parentId: j['parentId'] as String?,
        description: j['description'] as String?,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: (j['isActive'] as bool?) ?? true,
      );
}
