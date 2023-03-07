import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart' as wv;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geo_monitor/library/api/prefs_og.dart';
import 'package:geo_monitor/library/bloc/geo_uploader.dart';
import 'package:geo_monitor/library/cache_manager.dart';
import 'package:geo_monitor/ui/audio/recording_controls.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:uuid/uuid.dart';

import '../../device_location/device_location_bloc.dart';
import '../../library/bloc/audio_for_upload.dart';
import '../../library/data/position.dart';
import '../../library/data/project.dart';
import '../../library/data/settings_model.dart';
import '../../library/data/user.dart';
import '../../library/functions.dart';
import '../../library/generic_functions.dart';

class AudioHandler extends StatefulWidget {
  const AudioHandler({Key? key, required this.project, required this.onClose}) : super(key: key);

  final Project project;
  final Function onClose;
  @override
  AudioHandlerState createState() => AudioHandlerState();
}

class AudioHandlerState extends State<AudioHandler>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  final mm = '🔆🔆🔆🔆🔆🔆 AudioHandlerMobile: 🔆 ';
  Timer? _timer;
  final _audioRecorder = Record();
  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _amplitudeSub;
  final wv.RecorderController _recorderController = wv.RecorderController(); //
  late StreamSubscription<String> killSubscription;

  AudioPlayer player = AudioPlayer();
  List<StreamSubscription> streams = []; // Initialise
  bool isAudioPlaying = false;
  bool isUploading = false;
  User? user;
  static const int bufferSize = 2048;
  static const int sampleRate = 44100;
  bool isRecording = false;
  bool isPaused = false;
  bool isStopped = false;
  String? mTotalByteCount;
  String? mBytesTransferred;
  bool fileUploadComplete = false;

  late Stream<Uint8List> audioStream;
  late StreamController<List<double>> audioFFT;
  File? _recordedFile;
  int fileSize = 0;
  int seconds = 0;

  @override
  void initState() {
    _animationController = AnimationController(vsync: this);
    super.initState();
    _getSettings();
    _getUser();
    player.playerStateStream.listen((event) {
      if (event.playing) {
        pp('$mm AudioPlayer is playing');
        if (mounted) {
          setState(() {
            isAudioPlaying = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isAudioPlaying = false;
          });
        }
      }
    });
  }

  void _getSettings() async {
    settingsModel = await prefsOGx.getSettings();
    var m = settingsModel?.maxAudioLengthInMinutes;
    limitInSeconds = m! * 60;
    setState(() {});
  }

  void _getUser() async {
    user = await prefsOGx.getUser();
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    _recorderController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      seconds = t.tick;
      if (mounted) {
        setState(() {});
      }
    });
  }

  SettingsModel? settingsModel;
  int limitInSeconds = 60;
  _onRecord() async {
    pp('$mm start recording ...');

    try {
      setState(() {
        _recordedFile = null;
        mTotalByteCount = null;
        mBytesTransferred = null;
      });
      final Directory directory = await getApplicationDocumentsDirectory();
      final File mFile = File(
          '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.mp4');

      _recorderController.refresh();
      if (await _recorderController.checkPermission()) {
        await _recorderController.record(path: mFile.path);
        _startTimer();
        _recorderController.addListener(() {
          if (_recorderController.recorderState.name == 'recording') {
            //ignore
          } else {
            pp('$mm _waveController.recorderState.name: 🔆 ${_recorderController.recorderState.name}');
          }
          switch (_recorderController.recorderState.name) {
            case 'recording':
              if (mounted) {
                setState(() {
                  isRecording = true;
                  isPaused = false;
                  isStopped = false;
                });
              }
              break;
            case 'paused':
              if (mounted) {
                setState(() {
                  isRecording = false;
                  isPaused = true;
                  isStopped = false;
                });
              }
              break;
            case 'stopped':
              if (mounted) {
                setState(() {
                  isRecording = false;
                  isPaused = false;
                  isStopped = true;
                });
              }
              break;
          }
        });
      }
    } catch (e) {
      pp(e);
    }
  }

  _onPlay() async {
    if (_recordedFile == null) {
      return;
    }
    pp('$mm ......... start playing ...');

    player.setFilePath(_recordedFile!.path);
    await player.play();
  }

  _onPause() async {
    pp('$mm pause recording ...');
    _timer?.cancel();
    await _recorderController.pause();
    setState(() {
      isPaused = true;
      isRecording = false;
      isStopped = false;
    });
  }

  _onStop() async {
    pp('$mm ........... stop recording NOW! ...');
    _timer?.cancel();
    try {
      final path = await _recorderController.stop();
      if (path != null) {
        _recordedFile = File(path);
        fileSize = (await _recordedFile?.length())!;
        pp('$mm _waveController stopped : 🍎🍎🍎 path: $path');
        pp('$mm _waveController stopped : 🍎🍎🍎 size: $fileSize bytes');
      }
    } catch (e) {
      pp('$mm problem with stop ... falling down: $e');
      showToast(
          backgroundColor: Theme.of(context).primaryColor,
          message: 'Recording is a little bit off ...',
          context: context);
    }
    if (_timer != null) {
      _timer?.cancel();
    }
    setState(() {
      isPaused = false;
      isRecording = false;
      isStopped = true;
    });
  }

  Future<void> _uploadFile() async {
    if (isUploading) {
      return;
    }
    pp('\n\n$mm Start file upload .....................');
    setState(() {
      isUploading = true;
    });
    try {
      Position? position;
      var loc = await locationBloc.getLocation();
      if (loc != null) {
        position =
            Position(coordinates: [loc.longitude, loc.latitude], type: 'Point');
      }
      AudioPlayer audioPlayer = AudioPlayer();
      var dur = await audioPlayer.setFilePath(_recordedFile!.path);
      // var bytes = await _recordedFile!.readAsBytes();
      var audioForUpload = AudioForUpload(
          fileBytes: null,
          userName: user!.name,
          userThumbnailUrl: user!.thumbnailUrl,
          userId: user!.userId,
          organizationId: user!.organizationId,
          filePath: _recordedFile!.path,
          project: widget.project,
          position: position,
          durationInSeconds: dur == null ? 0 : dur.inSeconds,
          audioId: const Uuid().v4(),
          date: DateTime.now().toUtc().toIso8601String());

      await cacheManager.addAudioForUpload(audio: audioForUpload);
      geoUploader.manageMediaUploads();

      _recordedFile = null;
    } catch (e) {
      pp(e);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }

    setState(() {
      isUploading = false;
    });
  }

  void _reset(int totalByteCount, int bytesTransferred) {
    isRecording = false;
    isPaused = false;
    isStopped = false;
    fileUploadComplete = true;
    _recordedFile = null;
    seconds = 0;
    isAudioPlaying = false;
    totalByteCount = 0;
    bytesTransferred = 0;
    mTotalByteCount = null;
    mBytesTransferred = null;
    fileSize = 0;
  }

  Future<void> _test() async {
    // Catching errors at load time
    try {
      await player.setUrl("https://s3.amazonaws.com/404-file.mp3");
    } on PlayerException catch (e) {
      pp("Error code: ${e.code}");
      pp("Error message: ${e.message}");
    } on PlayerInterruptedException catch (e) {
      pp("Connection aborted: ${e.message}");
    } catch (e) {
      pp('An error occured: $e');
    }
// Catching errors during playback (e.g. lost network connection)
    player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace st) {
      if (e is PlayerException) {
        pp('Error code: ${e.code}');
        pp('Error message: ${e.message}');
      } else {
        pp('An error occurred: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
          strokeWidth: 4, backgroundColor: Colors.pink,
        ),),
      );
    } else {
      return ScreenTypeLayout(
        mobile: SafeArea(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Project Audio'),
            ),
            body: AudioCardAnyone(
              title: widget.project.name!,
              user: user!,
              seconds: seconds,
              recorderController: _recorderController,
              isUploading: isUploading,
              onUploadFile: _uploadFile,
              fileSize: fileSize.toDouble(),
              onPlay: _onPlay,
              onPause: _onPause,
              onRecord: _onRecord,
              onStop: _onStop,
              isStopped: isStopped,
              isRecording: isRecording,
              isPlaying: isAudioPlaying,
              isPaused: isPaused,
              recordedFile: _recordedFile,
              onClose: (){
               widget.onClose();
            },
            ),
          ),
        ),
        tablet: AudioCardAnyone(
          title: widget.project.name!,
          user: user!,
          seconds: seconds,
          recorderController: _recorderController,
          isStopped: isStopped,
          onUploadFile: _uploadFile,
          isUploading: isUploading,
          onPlay: _onPlay,
          onPause: _onPause,
          onRecord: _onRecord,
          onStop: _onStop,
          isRecording: isRecording,
          isPlaying: isAudioPlaying,
          isPaused: isPaused,
          fileSize: fileSize.toDouble(),
          recordedFile: _recordedFile,
          onClose: (){
            widget.onClose();
          },
        ),
      );
    }
  }
}

class AudioCardAnyone extends StatelessWidget {
  const AudioCardAnyone(
      {Key? key,
      required this.title,
      required this.user,
      required this.seconds,
      required this.recorderController,
      required this.isStopped,
      required this.onUploadFile,
      this.recordedFile,
      required this.isUploading,
      required this.fileSize,
      required this.onPlay,
      required this.onPause,
      required this.onStop,
      required this.onRecord,
      required this.isRecording,
      required this.isPlaying,
      required this.isPaused, required this.onClose})
      : super(key: key);

  final String title;
  final User user;
  final int seconds;
  final wv.RecorderController recorderController;
  final bool isStopped, isUploading, isRecording, isPlaying, isPaused;
  final Function onUploadFile;
  final File? recordedFile;
  final double fileSize;
  final Function onPlay, onPause, onStop, onRecord, onClose;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          elevation: 1,
          shape: getRoundedBorder(radius: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(onPressed: (){
                      onClose();
                    }, icon: const Icon(Icons.close)),
                  ],
                ),

                Text(
                  title,
                  style: myTextStyleMediumPrimaryColor(context),
                ),
                const SizedBox(
                  height: 24,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    user!.thumbnailUrl == null
                        ? const SizedBox()
                        : CircleAvatar(
                            backgroundImage: NetworkImage(user!.thumbnailUrl!),
                            radius: 20,
                          ),
                    const SizedBox(
                      width: 16,
                    ),
                    Text(
                      '${user!.name}',
                      style: myTextStyleSmall(context),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 24,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TimerCard(seconds: seconds),
                  ],
                ),
                const SizedBox(
                  height: 24,
                ),
                isStopped
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          shape: getRoundedBorder(radius: 12),
                          elevation: 8,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: wv.AudioWaveforms(
                              size: const Size(300.0, 80.0),
                              recorderController: recorderController,
                              enableGesture: true,
                              waveStyle: wv.WaveStyle(
                                waveColor: Theme.of(context).primaryColor,
                                durationStyle: myTextStyleSmall(context),
                                showDurationLabel: true,
                                waveThickness: 6.0,
                                spacing: 8.0,
                                showBottom: false,
                                extendWaveform: true,
                                showMiddleLine: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                recordedFile == null
                    ? const SizedBox()
                    : SizedBox(
                        height: 240,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Card(
                            elevation: 4,
                            shape: getRoundedBorder(radius: 16),
                            child: Column(
                              children: [
                                const SizedBox(
                                  height: 20,
                                ),
                                const SizedBox(
                                  height: 16,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'File upload size',
                                      style: myTextStyleSmall(context),
                                    ),
                                    const SizedBox(
                                      width: 8,
                                    ),
                                    Text((fileSize / 1024 / 1024)
                                        .toStringAsFixed(2)),
                                    const SizedBox(
                                      width: 8,
                                    ),
                                    const Text('MB'),
                                  ],
                                ),
                                const SizedBox(
                                  height: 48,
                                ),
                                isUploading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 4,
                                          backgroundColor: Theme.of(context)
                                              .primaryColorDark,
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: () {
                                          onUploadFile();
                                        },
                                        child: SizedBox(
                                          width: 200.0,
                                          child: Center(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(12.0),
                                              child: Text(
                                                'Upload Audio Clip',
                                                style: myTextStyleMediumBold(
                                                    context),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                const SizedBox(
                  height: 16,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: RecordingControls(
                      onPlay: () {
                        onPlay();
                      },
                      onPause: onPause,
                      onStop: onStop,
                      onRecord: onRecord,
                      isRecording: isRecording,
                      isPaused: isPaused,
                      isStopped: isStopped),
                ),
                const SizedBox(
                  height: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
