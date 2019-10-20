import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_colorpicker/material_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/android_encoder.dart';
import 'package:flutter_sound/ios_quality.dart';
import 'package:path_provider/path_provider.dart';
import 'timer.dart';

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
  bool _isPlaying = false;
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

  Color currentColor;
  PageController pageController;

  int _page = 0;

  List<String> fileNames = List();
  String audioFileEnding = Platform.isIOS ? '.m4a' : '.mp4';

  @override
  void initState() {
    super.initState();
    Future<Directory> promise = Platform.isIOS ? getTemporaryDirectory() : getExternalStorageDirectory();
    promise.then((directory) {
      List<FileSystemEntity> files = directory.listSync();
      files.sort((a, b) => a.statSync().changed.compareTo(b.statSync().changed));
      setState(() {
        files.forEach((file) {
          if (file.path.endsWith(audioFileEnding)) {
            fileNames.insert(0, file.path);
          }
        });
        _path = fileNames.isNotEmpty ? fileNames.first : null;
      });
    });

    pageController = PageController();
    flutterSound = new FlutterSound();
    flutterSound.setDbPeakLevelUpdate(0.2);
    flutterSound.setDbLevelEnabled(true);
    currentColor = Colors.red;
    initializeDateFormatting();
  }

  void navigationTapped(int page) {
    //Animating Page
    pageController.jumpToPage(page);
  }

  void onPageChanged(int page) {
    setState(() {
      this._page = page;
    });
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
  }

  void startRecorder() async {
    try {
      String fileName = DateTime.now().toString().split('.')[0] + audioFileEnding;
      String path = await flutterSound.startRecorder(
        fileName,
        numChannels: 2,
        bitRate: 128000,
        androidEncoder: AndroidEncoder.AMR_NB,
        androidAudioSource: AndroidAudioSource.MIC,
        androidOutputFormat: AndroidOutputFormat.MPEG_4,
        iosQuality: IosQuality.MEDIUM,
      );


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
            value = 100.0 / 160.0 * (value ?? 1) / 100;  // normalize
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

  void stopRecorder() async {
    try {
      String result = await flutterSound.stopRecorder();

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
        this.fileNames.insert(0, Uri.decodeFull(result));
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  void startPlayer(String path) async {
    try {
      if (_isPlaying) {
        await this.stopPlayer();
        setState(() {
          _isPlaying = false;
        });
      }
      String result = await flutterSound.startPlayer(Uri.encodeFull(path));
      await flutterSound.setVolume(1.0);

      _playerSubscription = flutterSound.onPlayerStateChanged.listen((e) {
        if (e != null) {
          sliderCurrentPosition = e.currentPosition;
          maxDuration = e.duration;

          DateTime date = new DateTime.fromMillisecondsSinceEpoch(
              e.currentPosition.toInt(),
              isUtc: true);
          String txt = DateFormat('mm:ss:SS', 'en_GB').format(date);
          this.setState(() {
            this._isPlaying = true;
            this._playerTxt = txt.substring(0, 8);
          });
        }
      });
    } catch (err) {
      print('error: $err');
    }
  }

  Future<void> stopPlayer() async {
    try {
      String result = await flutterSound.stopPlayer();
      if (_playerSubscription != null) {
        _playerSubscription.cancel();
        _playerSubscription = null;
      }

      this.setState(() {
        this._isPlaying = false;
        this.sliderCurrentPosition = 0.0;
      });
    } catch (err) {
      print('error: $err');
    }
  }

  void pausePlayer() async {
    if (_isPlaying) {
      String result = await flutterSound.pausePlayer();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void resumePlayer() async {
    if (!_isPlaying) {
      String result = await flutterSound.resumePlayer();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void seekToPlayer(int milliSecs) async {
    String result = await flutterSound.seekToPlayer(milliSecs);
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
              title: GestureDetector(
                onLongPress: () => this.setState(() {
                  _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                }),
                child: Builder(builder: (context) => FlatButton(
                  child: Text('Audio Recorder', style: TextStyle(fontSize: 18),),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          titlePadding: const EdgeInsets.all(0.0),
                          contentPadding: const EdgeInsets.all(0.0),
                          content: SingleChildScrollView(
                            child: MaterialPicker(
                              pickerColor: currentColor,
                              onColorChanged: (Color color) => setState(() => currentColor = color),
                              enableLabel: true,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                ),
              )
          ),
          body: PageView(
            controller: pageController,
            onPageChanged: onPageChanged,
            physics: ClampingScrollPhysics(),
            children: [
              Container(
                child: Column(
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
                                  child: Container(color: currentColor,),
                                ),
                              );
                            },
                          )
                      ),
                      Expanded(
                          flex: 1,
                          child: Timer(this._recorderTxt)
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
                            fillColor: currentColor,
                            child: this._isRecording ? Icon(Icons.stop, size: 32) : Icon(Icons.mic, size: 32,),
                          ),
                        ),
                      )
                    ]
                ),
              ),
              Container(
                child: Column(
                    children: <Widget>[
                      Expanded(
                        flex: 1,
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: <Widget>[
                                  Container(
                                    width: 56.0,
                                    height: 56.0,
                                    child: ClipOval(
                                      child: FlatButton(
                                          onPressed: () {
                                            if (!_isPlaying) {
                                              startPlayer(_path);
                                            }
                                          },
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(Icons.play_arrow)
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 56.0,
                                    height: 56.0,
                                    child: ClipOval(
                                      child: FlatButton(
                                          onPressed: () {
                                            pausePlayer();
                                          },
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(Icons.pause)
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 56.0,
                                    height: 56.0,
                                    child: ClipOval(
                                      child: FlatButton(
                                          onPressed: () {
                                            stopPlayer();
                                          },
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(Icons.stop)
                                      ),
                                    ),
                                  ),
                                ],
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                              ),
                              Container(
                                  height: 56.0,
                                  child: Slider(
                                      activeColor: currentColor,
                                      inactiveColor: currentColor.withOpacity(.24),
                                      value: sliderCurrentPosition,
                                      min: 0.0,
                                      max: maxDuration,
                                      onChanged: (double value) async{
                                        await flutterSound.seekToPlayer(value.toInt());
                                      },
                                      divisions: maxDuration.toInt()
                                  )
                              )
                            ]
                        ),
                      ),
                      Expanded(
                          flex: 1,
                          child: Container(
                            color: Colors.white10,
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              itemCount: fileNames.length,
                              itemBuilder: (context, index) {
                                String path = fileNames[index];
                                String fileName = path.split('/').last.split('.').first;
                                return GestureDetector(
                                    onTap: () => startPlayer(path),
                                    child: Container(
                                        constraints: BoxConstraints.expand(height: 80),
                                        alignment: Alignment(-1.0, 0.0),
                                        child: Text(fileName,
                                          style: TextStyle(fontSize: 16),)
                                    )
                                );
                              },
                            ),)
                      )
                    ]
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.record_voice_over),
                  title: Text('Record'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.headset),
                  title: Text('Listen'),
                )
              ],
              currentIndex: _page,
              selectedItemColor: currentColor,
              onTap: navigationTapped
          ),
        )
    );
  }
}

