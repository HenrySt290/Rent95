import '../../../shared/models/order.dart';

class OrderDraft {
  const OrderDraft({
    required this.productId,
    required this.orderType,
    this.quantity = 1,
    this.startDate,
    this.endDate,
    this.deliveryMethod = 'pickup',
  });

  final String productId;
  final OrderType orderType;
  final int quantity;
  final DateTime? startDate;
  final DateTime? endDate;
  final String deliveryMethod;
}

/// Data source for buyer/seller order lifecycles.
abstract class OrderRepository {
  Future<Order> create(OrderDraft draft);

  Future<Order> byId(String id);

  Future<List<Order>> myBuyerOrders();

  Future<List<Order>> mySellerOrders();

  /// Available transitions depend on the current status + actor role — those
  /// checks live server-side in `order.service.ts`.
  Future<Order> updateStatus(String orderId, OrderStatus next);
}
