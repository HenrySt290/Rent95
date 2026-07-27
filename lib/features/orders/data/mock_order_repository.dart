import '../../../shared/models/order.dart';
import '../../../shared/services/mock_store.dart';
import 'order_repository.dart';

class MockOrderRepository implements OrderRepository {
  MockOrderRepository(this._store);
  final MockStore _store;

  @override
  Future<Order> create(OrderDraft d) async {
    final listing = _store.listings.firstWhere(
      (l) => l.id == d.productId,
      orElse: () => throw StateError('Listing ${d.productId} not found in mock store'),
    );
    return _store.createOrder(
      listing: listing,
      type: d.orderType,
      start: d.startDate,
      end: d.endDate,
      quantity: d.quantity,
    );
  }

  @override
  Future<Order> byId(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final match = _store.orders.where((o) => o.id == id).firstOrNull;
    if (match == null) throw StateError('Order not found');
    return match;
  }

  @override
  Future<List<Order>> myBuyerOrders() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final me = _store.currentUser.id;
    final l = _store.orders.where((o) => o.buyerId == me).toList();
    l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return l;
  }

  @override
  Future<List<Order>> mySellerOrders() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final me = _store.currentUser.id;
    return _store.orders.where((o) => o.sellerId == me).toList();
  }

  @override
  Future<Order> updateStatus(String orderId, OrderStatus next) {
    return _store.updateOrderStatus(orderId, next);
  }
}
