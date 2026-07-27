import 'package:flutter/foundation.dart';

enum OrderType { rental, purchase, service }

OrderType orderTypeFromString(String v) => OrderType.values.firstWhere(
      (e) => e.name == v,
      orElse: () => OrderType.rental,
    );

enum OrderStatus {
  pending,
  accepted,
  rejected,
  awaitingPayment,
  paid,
  active,
  completed,
  cancelled,
  refunded,
  disputed,
}

OrderStatus orderStatusFromString(String v) {
  switch (v) {
    case 'awaiting_payment':
      return OrderStatus.awaitingPayment;
    default:
      return OrderStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => OrderStatus.pending,
      );
  }
}

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.rejected:
        return 'Rejected';
      case OrderStatus.awaitingPayment:
        return 'Awaiting payment';
      case OrderStatus.paid:
        return 'Paid';
      case OrderStatus.active:
        return 'Active';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
      case OrderStatus.disputed:
        return 'Disputed';
    }
  }
}

@immutable
class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.productTitle,
    required this.productImage,
    required this.orderType,
    required this.status,
    required this.subtotal,
    required this.totalAmount,
    required this.currency,
    required this.createdAt,
    this.quantity = 1,
    this.startDate,
    this.endDate,
    this.securityDeposit = 0,
    this.platformFee = 0,
    this.taxAmount = 0,
    this.deliveryFee = 0,
    this.deliveryMethod = 'pickup',
    this.buyerName = '',
    this.sellerName = '',
  });

  final String id;
  final String orderNumber;
  final String buyerId;
  final String sellerId;
  final String productId;
  final String productTitle;
  final String productImage;
  final OrderType orderType;
  final OrderStatus status;
  final int quantity;
  final DateTime? startDate;
  final DateTime? endDate;
  final double subtotal;
  final double securityDeposit;
  final double platformFee;
  final double taxAmount;
  final double deliveryFee;
  final double totalAmount;
  final String currency;
  final String deliveryMethod;
  final DateTime createdAt;
  final String buyerName;
  final String sellerName;

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        orderNumber: orderNumber,
        buyerId: buyerId,
        sellerId: sellerId,
        productId: productId,
        productTitle: productTitle,
        productImage: productImage,
        orderType: orderType,
        status: status ?? this.status,
        quantity: quantity,
        startDate: startDate,
        endDate: endDate,
        subtotal: subtotal,
        securityDeposit: securityDeposit,
        platformFee: platformFee,
        taxAmount: taxAmount,
        deliveryFee: deliveryFee,
        totalAmount: totalAmount,
        currency: currency,
        deliveryMethod: deliveryMethod,
        createdAt: createdAt,
        buyerName: buyerName,
        sellerName: sellerName,
      );
}
