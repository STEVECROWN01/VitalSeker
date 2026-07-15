import 'package:json_annotation/json_annotation.dart';

part 'sos_event.g.dart';

@JsonSerializable()
class SosEvent {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'location_address')
  final String? locationAddress;
  @JsonKey(name: 'contacts_notified')
  final List<ContactNotification> contactsNotified;
  @JsonKey(name: 'sms_sent')
  final bool smsSent;
  final bool resolved;
  @JsonKey(name: 'resolved_at')
  final DateTime? resolvedAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  SosEvent({
    required this.id,
    required this.userId,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.contactsNotified = const [],
    this.smsSent = false,
    this.resolved = false,
    this.resolvedAt,
    required this.createdAt,
  });

  factory SosEvent.fromJson(Map<String, dynamic> json) => _$SosEventFromJson(json);
  Map<String, dynamic> toJson() => _$SosEventToJson(this);

  /// FIX (audit M-16): add copyWith for immutable updates.
  SosEvent copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    String? locationAddress,
    List<ContactNotification>? contactsNotified,
    bool? smsSent,
    bool? resolved,
    DateTime? resolvedAt,
    DateTime? createdAt,
  }) {
    return SosEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAddress: locationAddress ?? this.locationAddress,
      contactsNotified: contactsNotified ?? this.contactsNotified,
      smsSent: smsSent ?? this.smsSent,
      resolved: resolved ?? this.resolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

@JsonSerializable()
class ContactNotification {
  final String name;
  final String phone;
  final String status;

  ContactNotification({
    required this.name,
    required this.phone,
    required this.status,
  });

  factory ContactNotification.fromJson(Map<String, dynamic> json) => _$ContactNotificationFromJson(json);
  Map<String, dynamic> toJson() => _$ContactNotificationToJson(this);
}
