// lib/gacha/gacha_inside_ball.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/cancellation_token.dart';

/// ガチャマシーン内部のボールを表すクラス
///
/// レイヤー構造（下から描画順）：
/*
  - GachaInsideBallBack.svg (64 x 64 px, origin: center) ※ 色変更あり
  - GachaInsideBallWhite.svg (64 x 64 px, origin: center)
  - GachaInsideBallCoin.svg (32 x 32 px, origin: center)
  - GachaInsideBallFront.svg (64 x 64 px, origin: center) ※ 色変更あり
*/
class GachaInsideBall {
  // ボールのローカル位置（単位：1.0 = 100 px）
  final ValueNotifier<Offset> _position = ValueNotifier<Offset>(Offset.zero);
  // ボールのローカル回転（角度：度）
  final ValueNotifier<double> _rotation = ValueNotifier<double>(0.0);
  // _back と _front に適用する色（初期は白）
  Color _color = Colors.white;

  /// 内部ボールの初期位置を設定
  void setPosition(Offset pos) {
    _position.value = pos;
  }

  /// ボールの色を設定（_back, _front 用）
  void setColor(Color color) {
    _color = color;
  }

  /// ボールの回転をランダムに設定（0～359°）
  void setRandomAngle() {
    _rotation.value = Random().nextInt(360).toDouble();
  }

  /// ボールを容器内部の円周上（containerCenter を中心、containerRadius の円）へ弾き飛ばすアニメーションをループ実行
  ///
  /// [speed] は単位（1.0 単位あたりの秒数ではなく、DOTween の SetSpeedBased 相当で「速度」として解釈」されます。
  /// ここでは「1.0 単位あたりの秒数」で duration = (distance / speed) としています。
  Future<void> bounceLoopAsync({
    required Offset containerCenter,
    required double containerRadius,
    required double speed,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    final random = Random();
    while (!ct.isCancelled) {
      // ランダムな方向の単位ベクトル
      double angle = random.nextDouble() * 2 * pi;
      Offset direction = Offset(cos(angle), sin(angle));
      // 目標位置は円周上
      Offset targetPosition = containerCenter + direction * containerRadius;
      // 現在位置との距離に応じた duration（秒）
      Offset current = _position.value;
      double distance = (targetPosition - current).distance;
      Duration duration = Duration(milliseconds: (distance / speed * 1000).round());
      await _animatePosition(
        from: current,
        to: targetPosition,
        duration: duration,
        ticker: ticker,
        ct: ct,
      );
    }
  }

  /// ボールを連続して 360° 回転させるアニメーションをループ実行
  ///
  /// [speed] は 1 周あたりの回転速度（度/秒）として解釈し、duration = 360 / speed としています。
  Future<void> rotateLoopAsync({
    required double speed,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    while (!ct.isCancelled) {
      double currentRotation = _rotation.value;
      double targetRotation = currentRotation + 360.0;
      Duration duration = Duration(milliseconds: (360.0 / speed * 1000).round());
      await _animateRotation(
        from: currentRotation,
        to: targetRotation,
        duration: duration,
        ticker: ticker,
        ct: ct,
      );
    }
  }

  /// 内部ヘルパー：位置アニメーション
  Future<void> _animatePosition({
    required Offset from,
    required Offset to,
    required Duration duration,
    required TickerProvider ticker,
    required CancellationToken ct,
  }) async {
    ct.throwIfCancellationRequested();
    final controller = AnimationController(vsync: ticker, duration: duration);
    final tween = Tween<Offset>(begin: from, end: to);
    final completer = Completer<void>();

    void listener() {
      _position.value = tween.evaluate(controller);
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

  /// 内部ヘルパー：回転アニメーション
  Future<void> _animateRotation({
    required double from,
    required double to,
    required Duration duration,
    required TickerProvider ticker,
    required CancellationToken ct,
  }) async {
    ct.throwIfCancellationRequested();
    final controller = AnimationController(vsync: ticker, duration: duration);
    final tween = Tween<double>(begin: from, end: to);
    final completer = Completer<void>();

    void listener() {
      _rotation.value = tween.evaluate(controller);
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
  ///
  /// ボールの位置・回転は、Transform で反映されます。1.0 単位は 100 px と換算しています。
  Widget buildWidget() {
    return ValueListenableBuilder<Offset>(
      valueListenable: _position,
      builder: (context, pos, child) {
        return ValueListenableBuilder<double>(
          valueListenable: _rotation,
          builder: (context, rot, child) {
            return Transform.translate(
              offset: pos * 100,
              child: Transform.rotate(
                angle: rot * pi / 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 背面レイヤー（色変更あり）
                    SvgPicture.asset(
                      'assets/gacha/GachaInsideBallBack.svg',
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      color: _color,
                    ),
                    // ホワイトレイヤー
                    SvgPicture.asset(
                      'assets/gacha/GachaInsideBallWhite.svg',
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                    ),
                    // コインレイヤー（サイズ 32 x 32）
                    SvgPicture.asset(
                      'assets/gacha/GachaInsideBallCoin.svg',
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                    ),
                    // 前面レイヤー（色変更あり）
                    SvgPicture.asset(
                      'assets/gacha/GachaInsideBallFront.svg',
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      color: _color,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
