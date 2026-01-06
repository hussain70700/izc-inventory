// Path: lib/utils/dashboard_service.dart

import 'package:flutter/material.dart';

// The breakpoint constant used across the dashboard.
const double kTabletBreakpoint = 850.0;

// The data model for the dashboard.
class DashboardData {
  final String totalBooked;
  final String handedOver;
  final String inProcess;
  final String delivered;
  final String shipperAdvice;
  final String returned;
  final String paymentProcessed;
  final String paymentTransferred;
  final String toBeTransferred;
  final double deliveredPercentage;
  final double returnRatio;
  final String totalSales;
  final String onlineSales;
  final String offlineSales;

  const DashboardData({
    required this.totalBooked,
    required this.handedOver,
    required this.inProcess,
    required this.delivered,
    required this.shipperAdvice,
    required this.returned,
    required this.paymentProcessed,
    required this.paymentTransferred,
    required this.toBeTransferred,
    required this.deliveredPercentage,
    required this.returnRatio,
    required this.totalSales,
    required this.onlineSales,
    required this.offlineSales,
  });
}

// The service class to fetch the data.
class DashboardService {
  final Map<String, DashboardData> _dummyDatabase = {
    "Dashboard": const DashboardData(
      totalBooked: "1,248",
      handedOver: "856",
      inProcess: "342",
      delivered: "1,105",
      shipperAdvice: "24",
      returned: "45",
      paymentProcessed: "\$45,280.00",
      paymentTransferred: "\$38,150.00",
      toBeTransferred: "\$7,130.00",
      deliveredPercentage: 0.94,
      returnRatio: 0.036,
      totalSales: "\$83,430.00",
      onlineSales: "\$55,120.00",
      offlineSales: "\$28,310.00",
    ),
  };

  Future<DashboardData> fetchDataFor(String viewName) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    if (_dummyDatabase.containsKey("Dashboard")) {
      return _dummyDatabase["Dashboard"]!;
    }
    throw Exception('Data not found for Dashboard');
  }
}
