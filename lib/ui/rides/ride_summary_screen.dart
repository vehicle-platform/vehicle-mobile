import 'package:flutter/material.dart';

import '../../services/app_settings.dart';
import '../../services/ride_client.dart';

class RideSummaryScreen extends StatelessWidget {
  const RideSummaryScreen({
    super.key,
    required this.sessionId,
    this.settingsStore = const AppSettingsStore(),
    this.client,
  });

  final String sessionId;
  final AppSettingsStore settingsStore;
  final RideClient? client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride summary')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
