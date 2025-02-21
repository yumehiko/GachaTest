// lib/gacha/gacha_prize_ball.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/cancellation_token.dart';

/// ガチャの景品ボールを管理するクラス
///
/// ボール自体の初期位置は (0, -10) 単位（= (0, -1000px)）
/// サイズは 512 x 512 px（1.0 単位＝100 px と換算）
///
/// 内部は以下のレイヤーで構成されます（上が最前面）：
/*
  ・GachaPrizeBallTopLine.svg (512 x 512, origin: center)
  ・GachaPrizeBallTop.svg (512 x 512, origin: center)
  
  ・GachaPrizeBallBottomLine.svg (512 x 512, origin: center)
  ・GachaPrizeBallBottom.svg (512 x 512, origin: center)
  
  ボール上部のレイヤーは [ballTopParent] で、下部のレイヤーは [ballBottomParent] で管理し、
  SplitAsync により上下に分離するアニメーションを実現します。
*/
class GachaPrizeBall {
  // 単位変換：1.0 単位 = 100 px
  static const double unitFactor = 100.0;

  // 全体のボール位置（単位）
  final ValueNotifier<Offset> _position = ValueNotifier<Offset>(const Offset(0, -10));
  // ボール上部グループの Y オフセット（単位）
  final ValueNotifier<double> _topOffset = ValueNotifier<double>(0.0);
  // ボール下部グループの Y オフセット（単位）
  final ValueNotifier<double> _bottomOffset = ValueNotifier<double>(0.0);

  GachaPrizeBall();

  /// 初期状態を設定します。
  void initialize() {
    // ボール自体は初期位置 (0, -10) 単位（＝ (0, -1000px)）
    _position.value = const Offset(0, -10);
    // 内部グループは中央に固定
    _topOffset.value = 0.0;
    _bottomOffset.value = 0.0;
  }

  /// Appear アニメーション：ボール自体を現在位置から (0,0) に移動させます。
  Future<void> appearAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    ct.throwIfCancellationRequested();
    final controller = AnimationController(vsync: ticker, duration: duration);
    final tween = Tween<Offset>(begin: _position.value, end: const Offset(0, 0));
    final animation = tween.animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutQuad),
    );
    final completer = Completer<void>();

    void listener() {
      _position.value = animation.value;
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

  /// Split アニメーション：ボール上部と下部のグループを Y 軸方向に分離させます。
  ///
  /// [distance] は移動量（単位）。上部は +[distance]、下部は -[distance] となります。
  Future<void> splitAsync({
    required Duration duration,
    required double distance,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    ct.throwIfCancellationRequested();
    // 上部グループのアニメーション
    final topController = AnimationController(vsync: ticker, duration: duration);
    final topTween = Tween<double>(begin: _topOffset.value, end: distance);
    final topAnimation = topTween.animate(
      CurvedAnimation(parent: topController, curve: Curves.easeOutQuad),
    );
    final topCompleter = Completer<void>();

    void topListener() {
      _topOffset.value = topAnimation.value;
      if (topController.status == AnimationStatus.completed) {
        topCompleter.complete();
      }
    }
    topController.addListener(topListener);
    topController.forward();

    // 下部グループのアニメーション
    final bottomController = AnimationController(vsync: ticker, duration: duration);
    final bottomTween = Tween<double>(begin: _bottomOffset.value, end: -distance);
    final bottomAnimation = bottomTween.animate(
      CurvedAnimation(parent: bottomController, curve: Curves.easeOutQuad),
    );
    final bottomCompleter = Completer<void>();

    void bottomListener() {
      _bottomOffset.value = bottomAnimation.value;
      if (bottomController.status == AnimationStatus.completed) {
        bottomCompleter.complete();
      }
    }
    bottomController.addListener(bottomListener);
    bottomController.forward();

    if (ct.isCancelled) {
      topController.dispose();
      bottomController.dispose();
      throw CancellationException();
    }
    await Future.wait([topCompleter.future, bottomCompleter.future]);
    topController.removeListener(topListener);
    bottomController.removeListener(bottomListener);
    topController.dispose();
    bottomController.dispose();
  }

  /// Close アニメーション：ここでは Split アニメーションを呼び出し、[distance] を 10 単位とします。
  Future<void> closeAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    await splitAsync(
      duration: duration,
      distance: 10.0,
      ct: ct,
      ticker: ticker,
    );
  }

  /// Widget ツリーに組み込むためのビルドメソッド
  ///
  /// ボール全体は [Transform.translate] により _position の値を反映し、
  /// 内部は [Stack] と [ValueListenableBuilder] で各グループのオフセット（_topOffset, _bottomOffset）を反映します。
  Widget buildWidget() {
    return ValueListenableBuilder<Offset>(
      valueListenable: _position,
      builder: (context, pos, child) {
        return Transform.translate(
          offset: pos * unitFactor, // 単位変換
          child: SizedBox(
            width: 512,
            height: 512,
            // Stack で内部レイヤーを重ねる
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ボール上部グループ
                ValueListenableBuilder<double>(
                  valueListenable: _topOffset,
                  builder: (context, topY, child) {
                    return Transform.translate(
                      offset: Offset(0, topY * unitFactor),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // GachaPrizeBallTopLine.svg
                          SvgPicture.asset(
                            'assets/gacha/GachaPrizeBallTopLine.svg',
                            width: 512,
                            height: 512,
                            alignment: Alignment.center,
                          ),
                          // GachaPrizeBallTop.svg
                          SvgPicture.asset(
                            'assets/gacha/GachaPrizeBallTop.svg',
                            width: 512,
                            height: 512,
                            alignment: Alignment.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // ボール下部グループ
                ValueListenableBuilder<double>(
                  valueListenable: _bottomOffset,
                  builder: (context, bottomY, child) {
                    return Transform.translate(
                      offset: Offset(0, bottomY * unitFactor),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // GachaPrizeBallBottomLine.svg
                          SvgPicture.asset(
                            'assets/gacha/GachaPrizeBallBottomLine.svg',
                            width: 512,
                            height: 512,
                            alignment: Alignment.center,
                          ),
                          // GachaPrizeBallBottom.svg
                          SvgPicture.asset(
                            'assets/gacha/GachaPrizeBallBottom.svg',
                            width: 512,
                            height: 512,
                            alignment: Alignment.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
