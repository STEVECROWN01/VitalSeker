import 'package:json_annotation/json_annotation.dart';

part 'sos_event.g.dart';

@JsonSerializable()
class SosEvent {
  final String id;
  final String userId;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final List<ContactNotification> contactsNotified;
  final bool smsSent;
  final bool resolved;
  final DateTime? resolvedAt;
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
