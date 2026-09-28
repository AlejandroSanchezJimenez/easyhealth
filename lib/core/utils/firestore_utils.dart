import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? readDate(Object? v) => v is Timestamp ? v.toDate() : null;

List<String> readStrings(Object? v) =>
    v is Iterable ? v.map((e) => e.toString()).toList() : const [];
