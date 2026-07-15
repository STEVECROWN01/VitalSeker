// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sos_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SosEvent _$SosEventFromJson(Map<String, dynamic> json) => SosEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAddress: json['location_address'] as String?,
      contactsNotified: (json['contacts_notified'] as List<dynamic>?)
              ?.map((e) =>
                  ContactNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      smsSent: json['sms_sent'] as bool? ?? false,
      resolved: json['resolved'] as bool? ?? false,
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SosEventToJson(SosEvent instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'location_address': instance.locationAddress,
      'contacts_notified': instance.contactsNotified,
      'sms_sent': instance.smsSent,
      'resolved': instance.resolved,
      'resolved_at': instance.resolvedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };

ContactNotification _$ContactNotificationFromJson(Map<String, dynamic> json) =>
    ContactNotification(
      name: json['name'] as String,
      phone: json['phone'] as String,
      status: json['status'] as String,
    );

Map<String, dynamic> _$ContactNotificationToJson(
        ContactNotification instance) =>
    <String, dynamic>{
      'name': instance.name,
      'phone': instance.phone,
      'status': instance.status,
    };
