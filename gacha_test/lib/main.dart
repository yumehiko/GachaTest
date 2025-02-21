// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'gacha/gacha_animation.dart';
import 'gacha/gacha_machine.dart';
import 'gacha/gacha_machine_shadow.dart';
import 'gacha/gacha_prize_get_button.dart';
import 'gacha/gacha_prize_ball.dart';
import 'gacha/gacha_prize_view.dart';
import 'gacha/gacha_scrim.dart';
import 'gacha/gacha_tap_button.dart';
import 'gacha/gacha_inside_ball.dart';
import 'utils/cancellation_token.dart';

void main() {
  runApp(const GachaApp());
}

class GachaApp extends StatelessWidget {
  const GachaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gacha Animation Demo',
      theme: ThemeData.dark(),
      home: const GachaAnimationScreen(),
    );
  }
}

class GachaAnimationScreen extends StatefulWidget {
  const GachaAnimationScreen({super.key});

  @override
  _GachaAnimationScreenState createState() => _GachaAnimationScreenState();
}

class _GachaAnimationScreenState extends State<GachaAnimationScreen>
    with TickerProviderStateMixin {
  late GachaAnimation _gachaAnimation;
  late CancellationTokenSource _globalCts;
  bool _isAnimating = false;
  String _statusText = 'Press SPACE to start animation';
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _globalCts = CancellationTokenSource();

    // 各コンポーネントのインスタンスを生成
    final prizeGetButton = GachaPrizeGetButton();
    final prizeBall = GachaPrizeBall();
    final prizeView = GachaPrizeView();
    final tapButton = GachaTapButton();
    // 内部ボールは16個生成
    List<GachaInsideBall> insideBalls =
        List.generate(16, (_) => GachaInsideBall());
    // ボールに設定する色一覧
    final ballColors = <Color>[
      const Color(0xFFE60000),
      const Color(0xFFF27900),
      const Color(0xFFF2DE00),
      const Color(0xFF24D900),
      const Color(0xFF00AAFF),
      const Color(0xFFC000E6),
    ];
    final machine = GachaMachine(
      gachaBalls: insideBalls,
      ballColors: ballColors,
    );
    final shadow = GachaMachineShadow();
    final scrim = GachaScrim();

    _gachaAnimation = GachaAnimation(
      prizeGetButton: prizeGetButton,
      prizeBall: prizeBall,
      prizeView: prizeView,
      tapButton: tapButton,
      machine: machine,
      shadow: shadow,
      scrim: scrim,
      ticker: this,
    );

    _gachaAnimation.initialize();

    // 初回フレーム後にフォーカスをリクエストしてキー入力を有効にする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      print('Focus requested.');
    });
  }

  @override
  void dispose() {
    _globalCts.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  /// アニメーションシーケンスを実行する非同期処理（各ステップの前後でログ出力）
  Future<void> _runAnimationSequence() async {
    if (_isAnimating) return;
    setState(() {
      _isAnimating = true;
      _statusText = 'Animation: Appear';
    });
    print('Animation sequence started.');
    try {
      print('Starting appearAsync...');
      await _gachaAnimation.appearAsync(_globalCts.token);
      print('appearAsync finished.');
      
      setState(() {
        _statusText = 'Animation: Idle';
      });
      print('Starting idleAsync...');
      await _gachaAnimation.idleAsync(_globalCts.token);
      print('idleAsync finished.');
      
      setState(() {
        _statusText = 'Animation: Lottery';
      });
      print('Starting playGachaAsync...');
      await _gachaAnimation.playGachaAsync(_globalCts.token);
      print('playGachaAsync finished.');
      
      setState(() {
        _statusText = 'Animation: Wait Confirm';
      });
      print('Waiting for user confirmation...');
      // ユーザー確認待ち処理を入れる場合はここに記述
      setState(() {
        _statusText = 'Animation: Closing';
      });
      print('Starting closeAsync...');
      await _gachaAnimation.closeAsync(_globalCts.token);
      print('closeAsync finished.');
      
      setState(() {
        _statusText = 'Animation finished';
      });
      print('Animation sequence completed.');
    } catch (e) {
      setState(() {
        _statusText = 'Animation cancelled or error: $e';
      });
      print('Error during animation sequence: $e');
    } finally {
      setState(() {
        _isAnimating = false;
      });
      print('Animation sequence ended.');
    }
  }

  /// RawKeyboardListener の onKey コールバック
  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space && !_isAnimating) {
        print('Space key pressed.');
        _runAnimationSequence();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gacha Animation Demo'),
        ),
        body: Stack(
          children: [
            _gachaAnimation.scrim.buildWidget(),
            _gachaAnimation.machine.buildWidget(),
            _gachaAnimation.shadow.buildWidget(),
            _gachaAnimation.tapButton.buildWidget(),
            _gachaAnimation.prizeView.buildMaskedWidget(),
            _gachaAnimation.prizeBall.buildWidget(),
            _gachaAnimation.prizeGetButton.buildWidget(),
            // 状態表示テキスト
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _statusText,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _isAnimating ? null : _runAnimationSequence,
          tooltip: 'Start Animation (or press SPACE)',
          child: const Icon(Icons.play_arrow),
        ),
      ),
    );
  }
}
