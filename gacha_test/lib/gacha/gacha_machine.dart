// lib/gacha/gacha_machine.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/cancellation_token.dart';
import 'gacha_inside_ball.dart';

class GachaMachine {
  bool _active = true;

  // transform プロパティ（1.0 単位＝100px 換算）
  final ValueNotifier<Offset> _position =
      ValueNotifier<Offset>(const Offset(0, 5.0)); // 初期位置：画面上部（見えない位置）
  final ValueNotifier<Offset> _scale =
      ValueNotifier<Offset>(const Offset(1.0, 1.2));
  final ValueNotifier<double> _rotation = ValueNotifier<double>(0.0); // 単位：度
  final ValueNotifier<double> _knobRotation = ValueNotifier<double>(0.0);

  // 内部ボール群とボールに設定する色一覧
  final List<GachaInsideBall> _gachaBalls;
  final List<Color> _ballColors;

  // ガラス内部領域の中心（単位）
  final Offset _glassOrigin = const Offset(0.0, 3.0);
  static const double containerRadius = 1.0;

  GachaMachine({
    required List<GachaInsideBall> gachaBalls,
    required List<Color> ballColors,
  })  : _gachaBalls = gachaBalls,
        _ballColors = ballColors;

  /// 初期化処理
  void initialize() {
    _active = true;
    _position.value = const Offset(0, 5.0); // 画面上部（非表示領域）
    _rotation.value = 0.0;
    _scale.value = const Offset(1.0, 1.2);
    _knobRotation.value = 0.0;

    // Poisson Disk Sampling により内部ボールの位置を生成
    List<Offset> ballPositions =
        _generateBallPositions(_glassOrigin, containerRadius, 0.32, 64);
    final random = Random();
    for (int i = 0; i < _gachaBalls.length; i++) {
      final ball = _gachaBalls[i];
      ball.setPosition(ballPositions[i]);
      ball.setRandomAngle();
      // ランダムな色を設定
      Color randomColor = _ballColors[random.nextInt(_ballColors.length)];
      ball.setColor(randomColor);
    }
  }

  /// 落下アニメーション：位置とスケールの変更を並行実行
  Future<void> fallAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    ct.throwIfCancellationRequested();

    final positionController =
        AnimationController(vsync: ticker, duration: duration);
    final scaleController =
        AnimationController(vsync: ticker, duration: duration);

    final positionTween =
        Tween<Offset>(begin: _position.value, end: const Offset(0, -2.24));
    final scaleTween =
        Tween<Offset>(begin: _scale.value, end: const Offset(1.0, 1.0));

    final positionCompleter = Completer<void>();
    final scaleCompleter = Completer<void>();

    positionController.addListener(() {
      _position.value = positionTween.evaluate(positionController);
      if (positionController.status == AnimationStatus.completed) {
        positionCompleter.complete();
      }
    });
    scaleController.addListener(() {
      _scale.value = scaleTween.evaluate(scaleController);
      if (scaleController.status == AnimationStatus.completed) {
        scaleCompleter.complete();
      }
    });

    positionController.forward();
    scaleController.forward();

    if (ct.isCancelled) {
      positionController.dispose();
      scaleController.dispose();
      throw CancellationException();
    }

    await Future.wait([positionCompleter.future, scaleCompleter.future]);
    positionController.dispose();
    scaleController.dispose();
  }

  /// 着地時のアニメーション（シェイクとリバウンドを並行実行）
  Future<void> landAsync({
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    await Future.wait([
      _shakingAnimation(duration: const Duration(milliseconds: 400), ct: ct),
      _reboundAnimation(ct: ct, ticker: ticker),
    ]);
  }

  Future<void> _shakingAnimation({
    required Duration duration,
    required CancellationToken ct,
  }) async {
    final original = _position.value;
    final stopwatch = Stopwatch()..start();
    final random = Random();
    while (stopwatch.elapsed < duration) {
      if (ct.isCancelled) break;
      // x軸方向に ±0.2 単位のランダムなオフセット
      double offsetX = (random.nextDouble() * 2 - 1) * 0.2;
      _position.value = original + Offset(offsetX, 0);
      await Future.delayed(const Duration(milliseconds: 16));
    }
    _position.value = original;
  }

  Future<void> _reboundAnimation({
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    await _animateScale(
      from: _scale.value,
      to: const Offset(1.1, 0.8),
      duration: const Duration(milliseconds: 125),
      ticker: ticker,
      ct: ct,
    );
    await _animateScale(
      from: _scale.value,
      to: const Offset(0.95, 1.05),
      duration: const Duration(milliseconds: 125),
      ticker: ticker,
      ct: ct,
    );
    await _animateScale(
      from: _scale.value,
      to: const Offset(1.0, 1.0),
      duration: const Duration(milliseconds: 125),
      ticker: ticker,
      ct: ct,
    );
  }

  Future<void> _animateScale({
    required Offset from,
    required Offset to,
    required Duration duration,
    required TickerProvider ticker,
    required CancellationToken ct,
  }) async {
    ct.throwIfCancellationRequested();
    final controller =
        AnimationController(vsync: ticker, duration: duration);
    final tween = Tween<Offset>(begin: from, end: to);
    final completer = Completer<void>();

    controller.addListener(() {
      _scale.value = tween.evaluate(controller);
      if (controller.status == AnimationStatus.completed) {
        completer.complete();
      }
    });

    controller.forward();
    if (ct.isCancelled) {
      controller.dispose();
      throw CancellationException();
    }

    await completer.future;
    controller.dispose();
  }

  /// ビートループ：一定間隔でスケールを変化させるループアニメーション
  Future<void> beatLoopAsync({
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    const beatScale = Offset(1.05, 0.95);
    try {
      while (!ct.isCancelled) {
        _scale.value = beatScale;
        await _animateScale(
          from: beatScale,
          to: const Offset(1.0, 1.0),
          duration: const Duration(milliseconds: 500),
          ticker: ticker,
          ct: ct,
        );
      }
    } finally {
      _scale.value = const Offset(1.0, 1.0);
    }
  }

  /// ノブの回転アニメーション
  Future<void> rotateKnobAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    // 第1フェーズ：現在の回転から -90° へ（duration の 40%）
    await _animateKnobRotation(
      from: _knobRotation.value,
      to: -90.0,
      duration: Duration(milliseconds: (duration.inMilliseconds * 0.4).round()),
      ticker: ticker,
      ct: ct,
    );
    // 20% 分待機
    await Future.delayed(
      Duration(milliseconds: (duration.inMilliseconds * 0.2).round()),
      () {
        ct.throwIfCancellationRequested();
      },
    );
    // 第2フェーズ：-90° から -180° へ（duration の 40%）
    await _animateKnobRotation(
      from: _knobRotation.value,
      to: -180.0,
      duration: Duration(milliseconds: (duration.inMilliseconds * 0.4).round()),
      ticker: ticker,
      ct: ct,
    );
    // ノブの回転をリセット
    _knobRotation.value = 0.0;
  }

  Future<void> _animateKnobRotation({
    required double from,
    required double to,
    required Duration duration,
    required TickerProvider ticker,
    required CancellationToken ct,
  }) async {
    ct.throwIfCancellationRequested();
    final controller =
        AnimationController(vsync: ticker, duration: duration);
    final tween = Tween<double>(begin: from, end: to);
    final completer = Completer<void>();

    controller.addListener(() {
      _knobRotation.value = tween.evaluate(controller);
      if (controller.status == AnimationStatus.completed) {
        completer.complete();
      }
    });

    controller.forward();
    if (ct.isCancelled) {
      controller.dispose();
      throw CancellationException();
    }
    await completer.future;
    controller.dispose();
  }

  /// 抽選アニメーション：
  /// ・各内部ボールのバウンス＆回転ループを開始し、
  /// ・機体全体に軽い揺れ（回転シェイク）を与え、一定時間後にキャンセルします。
  Future<void> lotteryAsync({
    required Duration duration,
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    final lotteryCts = CancellationTokenSource.createLinked(ct);

    // 各内部ボールのバウンス＆回転ループ開始
    _gachaBalls.map((ball) {
      return ball.bounceLoopAsync(
        containerCenter: _glassOrigin,
        containerRadius: containerRadius,
        speed: 12.0,
        ct: lotteryCts.token,
        ticker: ticker,
      );
    }).toList();
    _gachaBalls.map((ball) {
      return ball.rotateLoopAsync(
        speed: 360.0,
        ct: lotteryCts.token,
        ticker: ticker,
      );
    }).toList();

    // 機体全体の回転を -2° に設定
    _rotation.value = -2.0;
    // 軽い回転シェイクを開始
    _startShakeRotation(ct: lotteryCts.token, ticker: ticker);

    // 指定時間待機後、抽選アニメーションを終了
    await Future.delayed(duration);
    lotteryCts.cancel();
  }

  Future<void> _startShakeRotation({
    required CancellationToken ct,
    required TickerProvider ticker,
  }) async {
    try {
      while (!ct.isCancelled) {
        await _animateRotation(
          from: -2.0,
          to: 2.0,
          duration: const Duration(milliseconds: 50),
          ticker: ticker,
          ct: ct,
        );
        await _animateRotation(
          from: 2.0,
          to: -2.0,
          duration: const Duration(milliseconds: 50),
          ticker: ticker,
          ct: ct,
        );
      }
    } catch (e) {
      // キャンセル例外は握りつぶす
    }
  }

  Future<void> _animateRotation({
    required double from,
    required double to,
    required Duration duration,
    required TickerProvider ticker,
    required CancellationToken ct,
  }) async {
    ct.throwIfCancellationRequested();
    final controller =
        AnimationController(vsync: ticker, duration: duration);
    final tween = Tween<double>(begin: from, end: to);
    final completer = Completer<void>();

    controller.addListener(() {
      _rotation.value = tween.evaluate(controller);
      if (controller.status == AnimationStatus.completed) {
        completer.complete();
      }
    });
    controller.forward();
    if (ct.isCancelled) {
      controller.dispose();
      throw CancellationException();
    }
    await completer.future;
    controller.dispose();
  }

  /// 非表示にする
  void hide() {
    _active = false;
  }

  /// Poisson Disk Sampling により、円形領域内で各点間が [minDistance] 以上離れている点群を生成し、
  /// Y 座標が低い順にソートしたリストを返します。
  List<Offset> _generateBallPositions(
      Offset center, double containerRadius, double minDistance, int desiredCount,
      {int k = 30, int? seed}) {
    final random = seed != null ? Random(seed) : Random();
    List<Offset> points = [];
    List<Offset> activeList = [];

    const int targetCircumferencePoints = 32;
    int validCircumferencePoints = 0;
    int attempts = 0;
    int maxAttempts = targetCircumferencePoints * 8;

    // 円周上のランダムな点を生成
    while (validCircumferencePoints < targetCircumferencePoints &&
        attempts < maxAttempts) {
      attempts++;
      double angle = random.nextDouble() * 2 * pi;
      Offset candidate =
          center + Offset(containerRadius * cos(angle), containerRadius * sin(angle));
      if (!points.every((p) => (candidate - p).distance >= minDistance)) continue;
      points.add(candidate);
      activeList.add(candidate);
      validCircumferencePoints++;
    }

    // Poisson Disk Sampling により内部の点を生成
    while (activeList.isNotEmpty && points.length < desiredCount) {
      int index = random.nextInt(activeList.length);
      Offset point = activeList[index];
      bool candidateAccepted = false;
      for (int i = 0; i < k; i++) {
        double angle = random.nextDouble() * 2 * pi;
        double distance = minDistance * (1 + random.nextDouble());
        Offset candidate = point + Offset(cos(angle), sin(angle)) * distance;
        if ((candidate - center).distance > containerRadius) continue;
        if (!points.every((p) => (candidate - p).distance >= minDistance)) continue;
        points.add(candidate);
        activeList.add(candidate);
        candidateAccepted = true;
        break;
      }
      if (!candidateAccepted) {
        activeList.removeAt(index);
      }
    }

    points.sort((a, b) => a.dy.compareTo(b.dy));
    return points;
  }

  /// Widget ツリーに組み込むためのビルドメソッド
  Widget buildWidget() {
    if (!_active) return const SizedBox.shrink();
    return ValueListenableBuilder<Offset>(
      valueListenable: _position,
      builder: (context, pos, child) {
        return ValueListenableBuilder<Offset>(
          valueListenable: _scale,
          builder: (context, scale, child) {
            return ValueListenableBuilder<double>(
              valueListenable: _rotation,
              builder: (context, rotation, child) {
                return Transform(
                  transform: Matrix4.identity()
                    ..translate(pos.dx * 100, pos.dy * 100)
                    ..rotateZ(rotation * pi / 180)
                    ..scale(scale.dx, scale.dy),
                  alignment: Alignment.center,
                  child: _buildMachineStack(),
                );
              },
            );
          },
        );
      },
    );
  }

  /// 機体の各レイヤーを重ねた Widget
  Widget _buildMachineStack() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // 背面レイヤー：GachaMachine.svg（304 x 456 px, origin: bottom）
        SvgPicture.asset(
          'assets/gacha/GachaMachine.svg',
          width: 304,
          height: 456,
          alignment: Alignment.bottomCenter,
        ),
        // 内部ボール（各ボールは ball.buildWidget() で描画）
        ..._gachaBalls.map((ball) => ball.buildWidget()),
        // ノブ：GachaMachineKnob.svg（80 x 80 px, origin: center, position: (0, 132)）
        ValueListenableBuilder<double>(
          valueListenable: _knobRotation,
          builder: (context, knobRot, child) {
            return Transform.translate(
              offset: const Offset(0, 132),
              child: Transform.rotate(
                angle: knobRot * pi / 180,
                child: SvgPicture.asset(
                  'assets/gacha/GachaMachineKnob.svg',
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                ),
              ),
            );
          },
        ),
        // 前面レイヤー：GachaMachineFront.svg（304 x 456 px, origin: bottom）
        SvgPicture.asset(
          'assets/gacha/GachaMachineFront.svg',
          width: 304,
          height: 456,
          alignment: Alignment.bottomCenter,
        ),
      ],
    );
  }
}
