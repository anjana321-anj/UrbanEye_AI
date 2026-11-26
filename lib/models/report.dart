import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id, trackingId, category, subCategory, status, description, reporterName, address;
  final String? violationType, rejectionReason, reporterId, assignedWorkerId, plate;
  final bool isAnonymous, isUrgent;
  final int severity, upvotes, reporterCount, ward;
  final double priorityScore, lat, lng;
  final List<String> mediaUrls;
  final List<Map<String, dynamic>> timeline;
  final DateTime? createdAt;
  Report.fromDoc(DocumentSnapshot<Map<String, dynamic>> d)
      : id = d.id,
        trackingId = d['trackingId'] ?? 'Pending…',
        category = d['category'] ?? '',
        subCategory = d['subCategory'] ?? '',
        status = d['status'] ?? 'Submitted',
        description = d['description'] ?? '',
        reporterName = d['reporterName'] ?? 'Anonymous Citizen',
        address = (d['location']?['address']) ?? '',
        ward = (d['location']?['ward']) ?? 0,
        lat = (d['location']?['lat'] ?? 0).toDouble(),
        lng = (d['location']?['lng'] ?? 0).toDouble(),
        violationType = d.data()!['violationType'],
        rejectionReason = d.data()!['rejectionReason'],
        reporterId = d.data()!['reporterId'],
        assignedWorkerId = d.data()!['assignedWorkerId'],
        plate = d.data()!['plateNumber'],
        isAnonymous = d['isAnonymous'] ?? false,
        isUrgent = d['isUrgent'] ?? false,
        severity = d['severity'] ?? 1,
        upvotes = d['upvotes'] ?? 0,
        reporterCount = d['reporterCount'] ?? 1,
        priorityScore = (d['priorityScore'] ?? 0).toDouble(),
        mediaUrls = List<String>.from(d['mediaUrls'] ?? []),
        timeline = List<Map<String, dynamic>>.from(d['timeline'] ?? []),
        createdAt = (d.data()!['createdAt'] as Timestamp?)?.toDate();
}
