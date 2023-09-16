import 'dart:async';
import 'package:flutter/material.dart';

const _kAnimationDuration = Duration(milliseconds: 350);

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Animated Cursor Demo",
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const DemoPage(title: "Animated Cursor Demo"),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key, required this.title});

  final String title;

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> with TickerProviderStateMixin {
  static const double _padding = 16;

  static const _border = OutlineInputBorder(
    borderSide: BorderSide(color: Color(0xffecebec), width: .8),
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  static const _textStyle = TextStyle(fontSize: 20);
  static const _boldTextStyle = TextStyle(
    color: Colors.black,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  final _textFieldKey = GlobalKey();
  late final _controller = TextEditingController();
  late final _focusNode = FocusNode();

  ///Whether the text field's content has passed all checks
  bool _valid = false;
  bool _animateBack = false;
  bool _isCursorBlinking = false;
  bool _throttling = false;

  double _progress = 0;
  double _height = 0;
  double _offset = 0;
  double? _textFieldWidth;
  int _textLength = 0;

  Timer? _timer;
  Timer? _cursorTimer;

  late final AnimationController _cursorAnimationController =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late Animation<double> _cursorAnimation;

  void _animationListener() {
    if (_throttling) return;
    if (_cursorAnimationController.status == AnimationStatus.completed) {
      _cursorAnimationController.reverse();
    }

    if (_isCursorBlinking &&
        _cursorAnimationController.status == AnimationStatus.dismissed) {
      _cursorAnimationController.forward();
    }
  }

  void _textFieldListener() {
    final length = _controller.text.length;
    if (length == _textLength) {
      return;
    }
    _textLength = length;

    if (_valid && _computeProgress(false) < 1) {
      _animateCursor(forward: false);
      return;
    }

    if (_valid) return;

    _throttleCursorBlink();
    _animateBack = false;

    if (_textFieldWidth == null) {
      final size = _textFieldKey.currentContext?.size;
      _textFieldWidth = size?.width;
    }
    _computeOffsetAndProgress();
  }

  void _computeOffsetAndProgress() {
    final text = _controller.text;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: text,
        style: _textStyle,
      ),
    );

    _computeProgress();
    if (_progress == 1) {
      _animateCursor(forward: true);
    }

    painter.layout();
    setState(() {
      _height = painter.height * 1.2;
      _offset = painter.width + _padding * .75;
    });
  }

  final _lowerCaseRegex = RegExp(r'(?=.*[a-z])');
  final _upperCaseRegex = RegExp(r'(?=.*[A-Z])');
  final _digitRegex = RegExp(r'(?=.*\d)');
  final _specialCharacterRegex = RegExp(r'(?=.*[-+_!@#$%^&*.,?])');

  late final _expressions = [
    _lowerCaseRegex,
    _upperCaseRegex,
    _digitRegex,
    _specialCharacterRegex,
  ];

  double _computeProgress([bool shouldUpdateState = true]) {
    final text = _controller.text;
    int progress = 0;
    if (text.length >= 8) {
      progress += 1;
    }

    for (final regex in _expressions) {
      if (regex.hasMatch(text)) {
        progress += 1;
      }
    }

    if (shouldUpdateState) {
      setState(() {
        _progress = progress / 5;
      });
    }

    return progress / 5;
  }

  void _animateCursor({bool forward = true}) {
    _valid = forward;

    Future.delayed(
      const Duration(milliseconds: 50),
      () {
        if (forward) {
          _offset = (_textFieldWidth ?? _offset) - (_padding * 2.2);
          _stopBlinkingCursor();
        } else {
          _animateBack = true;
          _isCursorBlinking = true;
          _computeOffsetAndProgress();
          _throttleCursorBlink();
        }
      },
    );
  }

  /// Prevents cursor blinking while user is actively typing
  void _throttleCursorBlink() {
    _throttling = true;
    _stopBlinkingCursor();
    _cursorTimer?.cancel();
    _cursorTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (timer) {
        if (_valid) {
          _throttling = false;
          timer.cancel();
          return;
        }
        _startBlinkingCursor();
        _throttling = false;
        timer.cancel();
      },
    );
  }

  void _stopBlinkingCursor() {
    _cursorAnimationController.stop();
    setState(() {
      _isCursorBlinking = false;
    });
  }

  void _startBlinkingCursor() {
    _cursorAnimationController.forward(from: 0);
    setState(() {
      _isCursorBlinking = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_textFieldListener);

    _cursorAnimationController.addListener(_animationListener);
    _cursorAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _cursorAnimationController,
        curve: Curves.bounceInOut,
      ),
    );

    Future.microtask(() {
      _computeOffsetAndProgress();
      _timer?.cancel();
      _timer = Timer.periodic(
        const Duration(milliseconds: 100),
        (timer) {
          try {
            if (_textFieldKey.currentContext?.size != null) {
              _focusNode.requestFocus();
              timer.cancel();
              _startBlinkingCursor();
            }
          } catch (e) {}
        },
      );
    });
  }

  @override
  void dispose() {
    _cursorAnimationController.removeListener(_animationListener);
    _controller.removeListener(_textFieldListener);
    _controller.dispose();
    _focusNode.dispose();
    _cursorAnimationController.dispose();
    _timer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f7f8),
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              "Password",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xff898889),
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                TextField(
                  showCursor: false,
                  key: _textFieldKey,
                  focusNode: _focusNode,
                  controller: _controller,
                  style: _textStyle,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: _border,
                    border: _border,
                    disabledBorder: _border,
                    focusedBorder: _border,
                  ),
                ),
                AnimatedPositioned(
                  duration:
                      Duration(milliseconds: _valid || _animateBack ? 180 : 0),
                  left: _offset,
                  top: _height * 0.6,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _cursorAnimation,
                    builder: (context, opacity, _) {
                      return AnimatedCursor(
                        height: _height,
                        progress: _progress,
                        opacity: _throttling
                            ? 1
                            : _isCursorBlinking
                                ? opacity
                                : 0,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "*",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: "Must contain at least ",
                      style: TextStyle(
                        color: Colors.black.withOpacity(.8),
                        fontSize: 14,
                      ),
                      children: const [
                        TextSpan(
                          text: "8 characters",
                          style: _boldTextStyle,
                        ),
                        TextSpan(text: ", "),
                        TextSpan(
                          text: "one uppercase character",
                          style: _boldTextStyle,
                        ),
                        TextSpan(text: ", "),
                        TextSpan(
                          text: "one lower case character",
                          style: _boldTextStyle,
                        ),
                        TextSpan(text: ", "),
                        TextSpan(
                          text: "one special character",
                          style: _boldTextStyle,
                        ),
                        TextSpan(text: " and "),
                        TextSpan(
                          text: "one digit",
                          style: _boldTextStyle,
                        ),
                        TextSpan(text: "."),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedCursor extends StatelessWidget {
  const AnimatedCursor({
    super.key,
    required this.height,
    required this.progress,
    required this.opacity,
  });

  final double height;
  final double progress;
  final double opacity;

  Color get _progressColor {
    return switch (progress) {
      <= 0.35 => Colors.redAccent,
      <= 0.65 => Colors.yellow,
      <= 0.85 => Colors.lightGreen,
      _ => Colors.green,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (progress == 1) {
      return SuccessCheck(height: height);
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 50),
      opacity: opacity,
      child: Stack(
        children: [
          Container(
            height: height,
            width: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.grey.withOpacity(.3),
            ),
          ),
          if (progress > 0)
            Positioned(
              bottom: 0,
              child: AnimatedContainer(
                duration: _kAnimationDuration,
                height: (height * progress).clamp(0, height),
                width: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: _progressColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SuccessCheck extends StatefulWidget {
  const SuccessCheck({
    super.key,
    required this.height,
  });

  final double height;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.bounceInOut,
      ),
    );

    Future.microtask(() => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _kAnimationDuration,
      height: widget.height,
      width: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green,
      ),
      alignment: Alignment.center,
      child: ValueListenableBuilder<double>(
        valueListenable: _animation,
        builder: (context, opacity, _) {
          return Opacity(
            opacity: opacity,
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            ),
          );
        },
      ),
    );
  }
}
