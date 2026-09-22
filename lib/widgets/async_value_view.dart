import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:am_in/core/errors/app_exception.dart';
import 'package:am_in/widgets/state_views.dart';

/// Renders an [AsyncValue] with consistent loading / error / data handling.
///
/// - loading  → [LoadingView]
/// - error    → [ErrorView] with the error humanised via [ErrorMapper]
/// - data     → [dataBuilder]; if the data is an empty list and [emptyBuilder]
///   is provided, that is shown instead.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.dataBuilder,
    this.emptyBuilder,
    this.onRetry,
    this.loadingMessage,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) dataBuilder;
  final Widget Function()? emptyBuilder;
  final VoidCallback? onRetry;
  final String? loadingMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (T data) {
        if (emptyBuilder != null && data is Iterable && data.isEmpty) {
          return emptyBuilder!();
        }
        return dataBuilder(data);
      },
      loading: () => LoadingView(message: loadingMessage),
      error: (Object error, _) =>
          ErrorView(message: ErrorMapper.map(error).message, onRetry: onRetry),
    );
  }
}
