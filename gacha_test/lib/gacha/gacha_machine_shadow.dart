// lib/gacha/gacha_machine_shadow.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/cancellation_token.dart';

/// GachaMachineShadow.svg
/// ・サイズ: 320 x 64 px
/// ・原点: 中心
/// ・初期位置: (0, -192px)
///
/// このクラスは、ガチャマシンの影のアニメーション（出現、消滅）を管理します。
class GachaMachineShadow {
  // 内部状態：スケールと不透明度を管理
  final ValueNotifier<double> _scale = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _opacity = ValueNotifier<double>(1.0);
  bool _active = true;

  /// 初期状態として、オブジェクトを有効にし、スケールを 0 に設定します。
  void initialize() {
    _active = true;
    _scale.value = 0.0;
  }

  /// 出現アニメーション
  /// 1. 色を黒（α = 0.12）に設定
  /// 2. スケールを 0 から 1 にアニメーションさせる
  Future<void> appearAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    // 色設定（Flutter では不透明度で管理）
    _opacity.value = 0.12;
    ct.throwIfCancellationRequested();

    final controller = AnimationController(vsync: ticker, duration: duration);
    final animation = Tween<double>(begin: _scale.value, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutQuad),
    );
    final completer = Completer<void>();

    void listener() {
      _scale.value = animation.value;
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

  /// 消滅アニメーション
  /// opacity を現在の値から 0 にアニメーションさせます。
  Future<void> disappearAsync({
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

  /// オブジェクトを非表示にします。
  void hide() {
    _active = false;
  }

  /// Widget ツリーに組み込むためのビルドメソッド
  Widget buildWidget() {
    if (!_active) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<double>(
      valueListenable: _scale,
      builder: (context, scaleValue, child) {
        return ValueListenableBuilder<double>(
          valueListenable: _opacity,
          builder: (context, opacityValue, child) {
            return Opacity(
              opacity: opacityValue,
              child: Transform.translate(
                offset: const Offset(0, -192),
                child: Transform.scale(
                  scale: scaleValue,
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/gacha/GachaMachineShadow.svg',
                    width: 320,
                    height: 64,
                    alignment: Alignment.center,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
