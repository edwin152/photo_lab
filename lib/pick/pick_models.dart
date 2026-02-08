import 'package:flutter/material.dart';

@immutable
class PickPhoto {
  const PickPhoto({
    required this.id,
    required this.assetId,
    required this.sessionId,
    required this.groupName,
    required this.tag1,
    required this.tag2,
    required this.tag3,
    required this.createdAt,
  });

  final int id;
  final String assetId;
  final int sessionId;
  final String? groupName;
  final int? tag1;
  final int? tag2;
  final int? tag3;
  final DateTime createdAt;

  PickPhoto copyWith({
    int? id,
    String? assetId,
    int? sessionId,
    String? groupName,
    int? tag1,
    int? tag2,
    int? tag3,
    DateTime? createdAt,
  }) {
    return PickPhoto(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      sessionId: sessionId ?? this.sessionId,
      groupName: groupName ?? this.groupName,
      tag1: tag1 ?? this.tag1,
      tag2: tag2 ?? this.tag2,
      tag3: tag3 ?? this.tag3,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

@immutable
class PickSession {
  const PickSession({
    required this.id,
    required this.createdAt,
    required this.isActive,
  });

  final int id;
  final DateTime createdAt;
  final bool isActive;
}

class PickGroupSummary {
  const PickGroupSummary({
    required this.groupName,
    required this.count,
  });

  final String groupName;
  final int count;
}
