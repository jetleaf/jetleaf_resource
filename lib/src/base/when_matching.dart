/// Defines how a `when` condition performs comparison or existence checks
/// against a value, which may originate from:
/// - An environment variable
/// - A method parameter
///
/// This enum is used by conditional evaluators to determine whether a rule
/// should apply based on runtime or configuration-derived values.
///
/// {@template env_match_type}
/// ### Matching Modes
///
/// - **[EQUALS]**  
///   Matches when the value is exactly equal (case-sensitive).
///
/// - **[NOT_EQUALS]**  
///   Matches when the value is not exactly equal (case-sensitive).
///
/// - **[EQUALS_IGNORE_CASE]**  
///   Matches when the value equals another value but using a
///   case-insensitive comparison.
///
/// - **[NOT_EQUALS_IGNORE_CASE]**  
///   Matches when the value does *not* equal another value using a
///   case-insensitive comparison.
///
/// - **[EXISTS]**  
///   Matches when the key, variable, or parameter is present and not null.
///
/// - **[NOT_EXISTS]**  
///   Matches when the key, variable, or parameter is missing or null.
///
/// - **[REGEX]**  
///   Matches when the value satisfies a regular expression pattern.
/// {@endtemplate}
enum WhenMatching {
  /// Exact string equality comparison (case-sensitive).
  EQUALS,

  /// Inverse of [EQUALS]; matches only when values differ (case-sensitive).
  NOT_EQUALS,

  /// Case-insensitive equality comparison.
  EQUALS_IGNORE_CASE,

  /// Case-insensitive inequality comparison.
  NOT_EQUALS_IGNORE_CASE,

  /// Matches when the value or key is present.
  EXISTS,

  /// Matches when the value or key is absent.
  NOT_EXISTS,

  /// Matches when the value conforms to the given regular expression.
  REGEX;
}