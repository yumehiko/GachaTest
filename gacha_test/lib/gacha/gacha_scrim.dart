import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/cancellation_token.dart';

/// 画面全体を覆うスクリムのアニメーションを管理します。
class GachaScrim {
  // 不透明度（初期値は 0.0：完全に透明）
  final ValueNotifier<double> _opacity = ValueNotifier<double>(0.0);

  /// フェードイン：opacity を現在値から 0.5 にアニメーションさせます。
  Future<void> fadeInAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    ct.throwIfCancellationRequested();
    final controller = AnimationController(vsync: ticker, duration: duration);
    final animation = Tween<double>(begin: _opacity.value, end: 0.5).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutQuad),
    );
    final completer = Completer<void>();

    void listener() {
      _opacity.value = animation.value;
      if (controller.status == AnimationStatus.completed) {
        completer.complete();
      }
    }
    controller.addListener(listener);
    controller.forward();

    if (ct.isCancelled) {
      controller.dispose();
      throw CancellationException();
    }

    await completer.future;
    controller.removeListener(listener);
    controller.dispose();
  }

  /// 暗転：opacity を現在値から 0.7 にアニメーションさせます。
  Future<void> darkerAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    ct.throwIfCancellationRequested();
    final controller = AnimationController(vsync: ticker, duration: duration);
    final animation = Tween<double>(begin: _opacity.value, end: 0.7).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutQuad),
    );
    final completer = Completer<void>();

    void listener() {
      _opacity.value = animation.value;
      if (controller.status == AnimationStatus.completed) {
        completer.complete();
      }
    }
    controller.addListener(listener);
    controller.forward();

    if (ct.isCancelled) {
      controller.dispose();
      throw CancellationException();
    }

    await completer.future;
    controller.removeListener(listener);
    controller.dispose();
  }

  /// フェードアウト：opacity を現在値から 0.0 にアニメーションさせます。
  Future<void> fadeOutAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    ct.throwIfCancellationRequested();
    final controller = AnimationController(vsync: ticker, duration: duration);
    final animation = Tween<double>(begin: _opacity.value, end: 0.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutQuad),
    );
    final completer = Completer<void>();

    void listener() {
      _opacity.value = animation.value;
      if (controller.status == AnimationStatus.completed) {
        completer.complete();
      }
    }
    controller.addListener(listener);
    controller.forward();

    if (ct.isCancelled) {
      controller.dispose();
      throw CancellationException();
    }

    await completer.future;
    controller.removeListener(listener);
    controller.dispose();
  }

  /// Widget ツリーに組み込むためのビルドメソッド
  Widget buildWidget() {
    return ValueListenableBuilder<double>(
      valueListenable: _opacity,
      builder: (context, opacityValue, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(opacityValue),
        );
      },
    );
  }
}
