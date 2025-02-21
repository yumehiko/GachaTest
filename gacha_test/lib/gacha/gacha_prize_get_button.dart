import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/cancellation_token.dart';

/// ゲットボタンのアニメーションを管理するクラス。
///
/// GachaPrizeGetButton.svg を用いて、
/// サイズ: 288 x 96 px, 原点: center, 位置: (0, -230) px で表示されます。
/// ボタン自体は実際の挙動を持たず、単なる飾りとしてフェードイン／フェードアウトします。
class GachaPrizeGetButton {
  final ValueNotifier<double> _opacity = ValueNotifier<double>(0.0);

  /// 初期化。ボタンの不透明度を 0 に設定します。
  void initialize() {
    _opacity.value = 0.0;
  }

  /// フェードインアニメーション（不透明度を 0 から 1 に）
  Future<void> showAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    ct.throwIfCancellationRequested();
    final controller = AnimationController(vsync: ticker, duration: duration);
    final tween = Tween<double>(begin: _opacity.value, end: 1.0);
    final animation = tween.animate(
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

  /// フェードアウトアニメーション（不透明度を 1 から 0 に）
  Future<void> hideAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    ct.throwIfCancellationRequested();
    final controller = AnimationController(vsync: ticker, duration: duration);
    final tween = Tween<double>(begin: _opacity.value, end: 0.0);
    final animation = tween.animate(
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
        return Opacity(
          opacity: opacityValue,
          child: Transform.translate(
            offset: const Offset(0, -230), // 位置: 0, -230px
            child: SvgPicture.asset(
              'assets/gacha/GachaPrizeGetButton.svg',
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
