import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/cancellation_token.dart';

/// GachaTapButton.svg
/// ・サイズ: 288 x 96 px
/// ・原点: 中心
/// ・初期位置: (0, -300px)
///
/// タップ挙動はなく、単なる飾りとしてのボタンのアニメーションを提供します。
class GachaTapButton {
  // 内部で管理する不透明度。Widget では ValueListenableBuilder を利用して再描画します。
  final ValueNotifier<double> _opacity = ValueNotifier<double>(0.0);

  /// 初期状態として、不透明度を 0 に設定します。
  void initialize() {
    _opacity.value = 0.0;
  }

  /// フェードインアニメーション（不透明度 0 -> 1）
  /// [duration] はアニメーションの所要時間、[ticker] は AnimationController 用の TickerProvider、[ct] はキャンセル用トークンです。
  Future<void> fadeInAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    // すでにキャンセル済みなら例外を投げる
    ct.throwIfCancellationRequested();

    final controller = AnimationController(vsync: ticker, duration: duration);
    final animation = Tween<double>(begin: _opacity.value, end: 1.0).animate(
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

    // アニメーション中にキャンセルがあれば、dispose 後例外を投げる
    if (ct.isCancelled) {
      controller.dispose();
      throw CancellationException();
    }

    await completer.future;
    controller.removeListener(listener);
    controller.dispose();
  }

  /// フェードアウトアニメーション（不透明度 1 -> 0）
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

  /// Widget を構築します。アニメーション中の不透明度の変化に合わせて再描画されます。
  Widget buildWidget() {
    // ここでは、SvgPicture を利用して GachaTapButton.svg を表示します。
    return ValueListenableBuilder<double>(
      valueListenable: _opacity,
      builder: (context, opacityValue, child) {
        return Opacity(
          opacity: opacityValue,
          child: Transform.translate(
            offset: const Offset(0, -300), // 初期位置: 0, -300px
            child: SvgPicture.asset(
              'assets/gacha/GachaTapButton.svg',
              width: 288,
              height: 96,
              alignment: Alignment.center,
            ),
          ),
        );
      },
    );
  }
}
