import 'package:json_annotation/json_annotation.dart';

part 'subscription.g.dart';

/// FIX (audit M-12): typed enums for plan and status instead of raw Strings.
/// The DB CHECK constraints (`plan IN ('free','pro','enterprise')`,
/// `status IN ('active','past_due','canceled','expired')`) are now mirrored
/// in the model, preventing typos like `status = 'Actve'` from silently
/// disabling every status check.
enum SubscriptionPlan {
  free,
  pro,
  enterprise;

  String get jsonValue => name;
}

enum SubscriptionStatus {
  active,
  pastDue,
  canceled,
  expired;

  /// The DB stores 'past_due' (snake_case), but the enum name is `pastDue`
  /// (camelCase). We need to serialize as snake_case.
  String get jsonValue {
    switch (this) {
      case SubscriptionStatus.active: return 'active';
      case SubscriptionStatus.pastDue: return 'past_due';
      case SubscriptionStatus.canceled: return 'canceled';
      case SubscriptionStatus.expired: return 'expired';
    }
  }
}

@JsonSerializable()
class Subscription {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String plan;
  @JsonKey(name: 'stripe_customer_id')
  final String? stripeCustomerId;
  @JsonKey(name: 'stripe_subscription_id')
  final String? stripeSubscriptionId;
  @JsonKey(name: 'revenue_cat_id')
  final String? revenueCatId;
  final String status;
  @JsonKey(name: 'current_period_start')
  final DateTime? currentPeriodStart;
  @JsonKey(name: 'current_period_end')
  final DateTime? currentPeriodEnd;
  @JsonKey(name: 'cancel_at_period_end')
  final bool cancelAtPeriodEnd;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
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

  /// Typed accessors (audit M-12). The raw String fields are kept for
  /// backward compatibility with the generated JSON serializer, but all
  /// new code should use these typed getters.
  SubscriptionPlan get planEnum {
    switch (plan) {
      case 'free': return SubscriptionPlan.free;
      case 'pro': return SubscriptionPlan.pro;
      case 'enterprise': return SubscriptionPlan.enterprise;
      default: return SubscriptionPlan.free;
    }
  }

  SubscriptionStatus get statusEnum {
    switch (status) {
      case 'active': return SubscriptionStatus.active;
      case 'past_due': return SubscriptionStatus.pastDue;
      case 'canceled': return SubscriptionStatus.canceled;
      case 'expired': return SubscriptionStatus.expired;
      default: return SubscriptionStatus.expired;
    }
  }

  bool get isPro => plan == 'pro' && status == 'active';
  bool get isEnterprise => plan == 'enterprise' && status == 'active';
  bool get isFree => plan == 'free' || status != 'active';
  bool get isActive => status == 'active';

  /// FIX (audit H-11): also check that the subscription hasn't expired.
  /// If `currentPeriodEnd` is in the past, the subscription is no longer
  /// active even if the DB row hasn't been updated yet.
  bool get isProAndNotExpired {
    if (!isPro) return false;
    if (currentPeriodEnd != null && currentPeriodEnd!.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  /// FIX (audit M-16): add copyWith for immutable updates.
  Subscription copyWith({
    String? id,
    String? userId,
    String? plan,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? revenueCatId,
    String? status,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    bool? cancelAtPeriodEnd,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plan: plan ?? this.plan,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      revenueCatId: revenueCatId ?? this.revenueCatId,
      status: status ?? this.status,
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
