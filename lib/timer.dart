import 'package:flutter/material.dart';

class Timer extends StatefulWidget {
//  Hack fix for centered text jitter on iOS
//  Wraps the timer in a stateful widget to keep track of widget width and position the element accordingly
  String time;

  Timer(time) : this.time = time;

  @override
  _TimerState createState() => _TimerState();
}

class _TimerState extends State<Timer> {
  GlobalKey _timerKey = GlobalKey();
  Size size;

  _getSizes() {
    final RenderBox renderBox = _timerKey.currentContext.findRenderObject();
    this.size = renderBox.size;
  }

  _afterLayout(_) {
    _getSizes();
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    Text text = Text(
      this.widget.time,
      key: _timerKey,
      style: TextStyle(
        fontSize: 40.0,
      ),
    );

    if (this.size != null) {
      return Stack(
          children: [
            Positioned(
                left: width/2 - size.width/2,
                top: height/10,
                child: Container(child: text)
            )
          ]
      );
    } else {
      return Center(child: text);
    }
  }
}

