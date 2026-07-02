import 'package:flutter/material.dart';

const Color kMoneyGreen = Color(0xFF00A37B); // ETMONEY brand green (darker for high readability in light mode)
const Color kScaffoldBg = Color(0xFFF4F6F9);  // ETMONEY light mode background
const Color kCardBg = Color(0xFFFFFFFF);      // Pure white card background

/// Native-mode Firestore database ID. The project's (default) DB is Datastore
/// mode and cannot be used by the Flutter SDK — create this DB in Firebase Console.
const String kFirestoreDatabaseId = 'lifegoal';
