import '../../domain/strategies/fulfillment_strategy.dart';
import '../strategies/api_strategy.dart';
import '../strategies/manual_strategy.dart';
import '../strategies/tasker_strategy.dart';

class FulfillmentStrategyFactory {
  /// Returns the corresponding IFulfillmentStrategy for the given config value.
  static IFulfillmentStrategy getStrategy(String configValue) {
    switch (configValue) {
      case 'API':
        return ApiFulfillmentStrategy();
      case 'TASKER_SCRIPT':
        return TaskerFulfillmentStrategy();
      case 'MANUAL':
      default:
        return ManualFulfillmentStrategy();
    }
  }
}
