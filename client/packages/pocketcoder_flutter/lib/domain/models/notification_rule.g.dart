// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationRule _$NotificationRuleFromJson(Map<String, dynamic> json) =>
    _NotificationRule(
      id: json['id'] as String,
      user: json['user'] as String,
      rules: json['rules'],
    );

Map<String, dynamic> _$NotificationRuleToJson(_NotificationRule instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'rules': instance.rules,
    };
