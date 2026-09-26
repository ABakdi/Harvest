import 'package:flutter/material.dart';
import 'package:harvest/features/finances/domain/expense.dart';

/// The traffic-light color of a budget status, shared by the Field
/// pulse and the Granary gauge.
Color budgetColor(ColorScheme scheme, BudgetStatus status) => switch (status) {
  BudgetStatus.under => scheme.secondary,
  BudgetStatus.close => scheme.tertiary,
  BudgetStatus.over => scheme.error,
};
