import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:intl/date_symbol_data_local.dart';

import 'dart:async';
import 'package:flutter_sound/flutter_sound.dart';

void main() {
  runApp(new MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isRecording = false;
  String _path;
  // bool _isPlaying = false;
  StreamSubscription _recorderSubscription;
  StreamSubscription _dbPeakSubscription;
  StreamSubscription _playerSubscription;
  FlutterSound flutterSound;


  String _recorderTxt = '00:00:00';
  String _playerTxt = '00:00:00';
  double _dbLevel;
  List<double> _recordingOverviewPeaks = List();

  ThemeMode _themeMode = ThemeMode.dark;

  double sliderCurrentPosition = 0.0;
  double maxDuration = 1.0;


  @override
  void initState() {
    super.initState();
    flutterSound = new FlutterSound();
    flutterSound.setDbPeakLevelUpdate(0.2);
    flutterSound.setDbLevelEnabled(true);
    initializeDateFormatting();
  }

  void startRecorder() async {
    try {
      String path = await flutterSound.startRecorder(Platform.isIOS ? 'ios.m4a' : 'android.mp4');
      print('startRecorder: $path');

      _recorderSubscription = flutterSound.onRecorderStateChanged.listen((e) {
        DateTime date = new DateTime.fromMillisecondsSinceEpoch(
            e.currentPosition.toInt(),
            isUtc: true);
        String txt = DateFormat('mm:ss:SS', 'en_GB').format(date);

        this.setState(() {
          this._recorderTxt = txt.substring(0, 8);
        });
      });
      _dbPeakSubscription =
          flutterSound.onRecorderDbPeakChanged.listen((value) {
            print('new peak value: $value');
            if (Platform.isIOS) {
              value = 100.0 / 160.0 * (value ?? 1) / 100;  // normalize
            } else {
              value = 100.0 / 160.0 * (value ?? 1) / 100;  // normalize
            }
            setState(() {
              _dbLevel = value;
              _recordingOverviewPeaks.insert(0, value);
            });
          });

      this.setState(() {
        this._isRecording = true;
        this._path = path;
      });
    } catch (err) {
      print('startRecorder error: $err');
    }
  }

  void stopRecorder() async{
    try {
      String result = await flutterSound.stopRecorder();
      print('stopRecorder: $result');

      if (_recorderSubscription != null) {
        _recorderSubscription.cancel();
        _recorderSubscription = null;
      }
      if (_dbPeakSubscription != null) {
        _dbPeakSubscription.cancel();
        _dbPeakSubscription = null;
      }

      this.setState(() {
        this._isRecording = false;
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  void startPlayer() async{
    try {
      String path = await flutterSound.startPlayer(this._path);
      await flutterSound.setVolume(1.0);
      print('startPlayer: $path');

      _playerSubscription = flutterSound.onPlayerStateChanged.listen((e) {
        if (e != null) {
          sliderCurrentPosition = e.currentPosition;
          maxDuration = e.duration;


          DateTime date = new DateTime.fromMillisecondsSinceEpoch(
              e.currentPosition.toInt(),
              isUtc: true);
          String txt = DateFormat('mm:ss:SS', 'en_GB').format(date);
          this.setState(() {
            //this._isPlaying = true;
            this._playerTxt = txt.substring(0, 8);
          });
        }
      });
    } catch (err) {
      print('error: $err');
    }
  }

  void stopPlayer() async{
    try {
      String result = await flutterSound.stopPlayer();
      print('stopPlayer: $result');
      if (_playerSubscription != null) {
        _playerSubscription.cancel();
        _playerSubscription = null;
      }

      this.setState(() {
        //this._isPlaying = false;
      });
    } catch (err) {
      print('error: $err');
    }
  }

  void pausePlayer() async{
    String result = await flutterSound.pausePlayer();
    print('pausePlayer: $result');
  }

  void resumePlayer() async{
    String result = await flutterSound.resumePlayer();
    print('resumePlayer: $result');
  }

  void seekToPlayer(int milliSecs) async{
    String result = await flutterSound.seekToPlayer(milliSecs);
    print('seekToPlayer: $result');
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeData(
            brightness: Brightness.light,
            appBarTheme: AppBarTheme(color: Colors.white)
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,

        ),
        home: Scaffold(
          appBar: AppBar(
            title: FlatButton(
                onPressed: () => this.setState(() {
                  _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                }),
                child: Text('Audio Recorder', style: TextStyle(fontSize: 18),)
            ),
          ),
          body: Column(
              children: <Widget>[
                Expanded(
                    flex: 2,
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      itemCount: _recordingOverviewPeaks.length,
                      itemBuilder: (context, index) {
                        double peak = _recordingOverviewPeaks[index];
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          constraints: BoxConstraints.expand(width: 2),
                          alignment: Alignment(0.0, 0.0),
                          child: FractionallySizedBox(
                            heightFactor: peak,
                            child: Container(color: Colors.red,),
                          ),
                        );
                      },
                    )
                ),
                Expanded(
                    flex: 1,
                    child: Center(child:
                    Text(
                      this._recorderTxt,
                      style: TextStyle(
                        fontSize: 40.0,
                      ),
                    ),
                    )
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    width: 100,
                    height: 100,
                    child: new RawMaterialButton(
                      shape: new CircleBorder(),
                      elevation: 1.0,
                      onPressed: () {
                        if (!this._isRecording) {
                          return this.startRecorder();
                        }
                        this.stopRecorder();
                      },
                      fillColor: Colors.red,
                      child: this._isRecording ? Icon(Icons.stop, size: 32) : Icon(Icons.mic, size: 32,),
                    ),
                  ),
                )
              ]
          ),
        )
    );
  }
}

