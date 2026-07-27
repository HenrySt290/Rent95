import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/interceptors/request_id_interceptor.dart';
import '../../../shared/models/order.dart';
import 'order_repository.dart';

class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this._dio) : _uuid = const Uuid();
  final Dio _dio;
  final Uuid _uuid;

  @override
  Future<Order> create(OrderDraft d) async {
    // Idempotency-Key so a network hiccup can't produce two orders.
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/orders',
      data: <String, dynamic>{
        'productId': d.productId,
        'orderType': d.orderType.name,
        'quantity': d.quantity,
        if (d.startDate != null) 'startDatetime': d.startDate!.toUtc().toIso8601String(),
        if (d.endDate != null) 'endDatetime': d.endDate!.toUtc().toIso8601String(),
        'deliveryMethod': d.deliveryMethod,
      },
      options: Options(extra: {RequestIdInterceptor.idempotencyKey: _uuid.v4()}),
    );
    return decodeObject(res, _fromApi);
  }

  @override
  Future<Order> byId(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/orders/$id');
    return decodeObject(res, _fromApi);
  }

  @override
  Future<List<Order>> myBuyerOrders() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/buyer/orders');
    return decodeList(res, _fromApi);
  }

  @override
  Future<List<Order>> mySellerOrders() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/seller/orders');
    return decodeList(res, _fromApi);
  }

  @override
  Future<Order> updateStatus(String orderId, OrderStatus next) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/orders/$orderId/status',
      data: {'status': _statusToApi(next)},
    );
    return decodeObject(res, _fromApi);
  }

  Order _fromApi(Map<String, dynamic> j) {
    final product = (j['product'] as Map?)?.cast<String, dynamic>();
    final media = ((product?['media'] as List?) ?? const []);
    final image = media.isEmpty
        ? ''
        : (((media.first as Map).cast<String, dynamic>()['url']) as String? ?? '');
    final buyer = (j['buyer'] as Map?)?.cast<String, dynamic>();
    final seller = (j['seller'] as Map?)?.cast<String, dynamic>();

    return Order(
      id: j['id'] as String,
      orderNumber: j['orderNumber'] as String,
      buyerId: j['buyerId'] as String,
      sellerId: j['sellerId'] as String,
      productId: j['productId'] as String,
      productTitle: (product?['title'] as String?) ?? '',
      productImage: image,
      orderType: orderTypeFromString((j['orderType'] as String?) ?? 'rental'),
      status: orderStatusFromString((j['status'] as String?) ?? 'pending'),
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      startDate: j['startDatetime'] == null ? null : DateTime.parse(j['startDatetime'] as String),
      endDate: j['endDatetime'] == null ? null : DateTime.parse(j['endDatetime'] as String),
      subtotal: (j['subtotal'] as num).toDouble(),
      securityDeposit: (j['securityDeposit'] as num?)?.toDouble() ?? 0,
      platformFee: (j['platformFee'] as num?)?.toDouble() ?? 0,
      taxAmount: (j['taxAmount'] as num?)?.toDouble() ?? 0,
      deliveryFee: (j['deliveryFee'] as num?)?.toDouble() ?? 0,
      totalAmount: (j['totalAmount'] as num).toDouble(),
      currency: (j['currency'] as String?) ?? 'USD',
      deliveryMethod: (j['deliveryMethod'] as String?) ?? 'pickup',
      createdAt: DateTime.parse(j['createdAt'] as String),
      buyerName: (buyer?['fullName'] as String?) ?? '',
      sellerName: (seller?['fullName'] as String?) ?? '',
    );
  }

  /// Client-side enum → API-side snake_case for the couple of statuses that
  /// differ (`awaitingPayment` vs `awaiting_payment`).
  String _statusToApi(OrderStatus s) {
    switch (s) {
      case OrderStatus.awaitingPayment:
        return 'awaiting_payment';
      default:
        return s.name;
    }
  }
}
