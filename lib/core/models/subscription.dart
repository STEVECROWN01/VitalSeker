import 'package:json_annotation/json_annotation.dart';

part 'subscription.g.dart';

@JsonSerializable()
class Subscription {
  final String id;
  final String userId;
  final String plan;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String? revenueCatId;
  final String status;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    this.plan = 'free',
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.revenueCatId,
    this.status = 'active',
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) => _$SubscriptionFromJson(json);
  Map<String, dynamic> toJson() => _$SubscriptionToJson(this);

  bool get isPro => plan == 'pro' && status == 'active';
  bool get isEnterprise => plan == 'enterprise' && status == 'active';
  bool get isFree => plan == 'free' || status != 'active';
  bool get isActive => status == 'active';
}
