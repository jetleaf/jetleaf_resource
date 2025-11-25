import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_logging/logging.dart';

/// Utility helpers for resolving dynamic or static storage names.
///
/// This class provides logic for interpreting storage name declarations
/// that may contain *parameter-derived* values.  
/// Names beginning with `#param_` are considered **dynamic storage keys** and
/// are resolved by inspecting method arguments at invocation time.
///
/// ## Example
/// ```dart
/// @RateLimit(storages: {'local', '#param_userStore'})
/// Future<void> handler(String userStore) { ... }
///
/// // If userStore = 'redis-main':
/// // → resolves to {'local', 'redis-main'}
/// ```
///
/// ## Resolution Rules
/// - Static names (not starting with `#param_`) are returned as-is.
/// - Dynamic names are resolved by:
///   1. Extracting the parameter name following the prefix  
///   2. Fetching the corresponding method parameter  
///   3. Reading its runtime argument value  
///   4. Ensuring the value is a `String`  
///   5. Including the resolved string in the output set
///
/// If a parameter is missing or cannot be evaluated, the entry is skipped.
/// Trace logs are emitted for all decisions when tracing is enabled.
///
/// This class is not meant to be instantiated.
abstract interface class ResourceUtils {
  /// Prefix that marks a dynamic storage key based on a method parameter.
  static const String PARAM_KEY = "#param_";

  /// Internal logger instance for diagnostic and trace output.
  static final Log _logger = LogFactory.getLog(ResourceUtils);

  /// Resolves storage names by expanding dynamic parameter-based entries.
  ///
  /// ### Parameters
  /// - [names] – The declared storage names (static or dynamic).
  /// - [invocation] – The current method invocation context.
  /// - [type] – The type on which the method is invoked.
  ///
  /// ### Returns
  /// A set of fully resolved storage names, with dynamic entries substituted
  /// using the corresponding method argument values.
  ///
  /// ### Logging Behavior
  /// When TRACE is enabled:
  /// - Logs each dynamic parameter resolution attempt
  /// - Logs type mismatches
  /// - Logs missing parameter values
  /// - Logs the final resolved set of storages
  static Set<String> resolveStorageNames(Set<String> names, MethodInvocation invocation, Type type) {
    final result = <String>{};

    for (final name in names) {
      // Dynamic parameter-based storage key
      if (name.startsWith(PARAM_KEY)) {
        final paramName = name.replaceAll(PARAM_KEY, "");
        final param = invocation.getMethod().getParameter(paramName);

        // Parameter exists?
        if (param != null) {
          Object? paramValue;

          // Get param value based on whether argument is named or positional
          if (param.isNamed()) {
            paramValue = invocation.getArgument()?.getNamedArguments()[paramName];
          } else {
            paramValue = invocation.getArgument()?.getPositionalArguments().elementAt(param.getIndex());
          }

          // Handle missing parameter value
          if (paramValue == null) {
            if (_logger.getIsTraceEnabled()) {
              _logger.trace(
                "Dynamic storage key `$name` could not be resolved because "
                "its mapped parameter `$paramName` has no runtime value.",
              );
            }
            continue;
          }

          // Handle type mismatch
          if (paramValue is! String) {
            if (_logger.getIsTraceEnabled()) {
              _logger.trace(
                "Ignoring dynamic storage key `$name`: "
                "parameter `$paramName` resolved to a non-string value "
                "(${paramValue.runtimeType}) → $paramValue",
              );
            }
            continue;
          }

          if (_logger.getIsTraceEnabled()) {
            _logger.trace("Resolved dynamic storage key `$name`: parameter `$paramName` → `$paramValue`");
          }

          result.add(paramValue.toString());
        }
      } else { // Standard static storage name
        result.add(name);
      }
    }

    if (_logger.getIsTraceEnabled()) {
      _logger.trace("Final resolved storage names for target `$type`: $result");
    }

    return result;
  }
}