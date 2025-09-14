import 'package:flutter/material.dart';

class TimerWidget extends StatefulWidget {
  const TimerWidget({super.key});

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  int workDuration = 25; // Default waktu kerja (menit)
  int breakDuration = 5; // Default waktu istirahat (menit)
  bool isWorking = true;
  int secondsRemaining = 0;
  List<String> sessionLogs = [];
  String sessionTitle = 'belajar bang'; // Default judul sesi
  bool isPaused = false; // Status apakah timer sedang dijeda
  bool isTimerStarted = false; // Status apakah timer sudah dimulai

  @override
  void initState() {
    super.initState();
    secondsRemaining = workDuration * 60;
  }

  void startTimer() {
    setState(() {
      isTimerStarted = true; // Pastikan status timer diatur ke "dimulai"
      isPaused = false; // Pastikan timer tidak dalam keadaan dijeda
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (secondsRemaining > 0 && isTimerStarted && !isPaused) {
        setState(() {
          secondsRemaining--; // Kurangi waktu yang tersisa
        });
        startTimer(); // Panggil kembali untuk melanjutkan timer
      } else if (secondsRemaining == 0 && isTimerStarted) {
        _onTimerComplete(); // Panggil _onTimerComplete() jika waktu habis
      }
    });
  }

  void pauseOrResumeTimer() {
    setState(() {
      isPaused = !isPaused;
    });
    if (!isPaused) {
      startTimer(); // Lanjutkan timer jika tidak dijeda
    }
  }

  void stopTimer() {
    setState(() {
      isTimerStarted = false; // Set status timer menjadi berhenti
      isPaused = false; // Reset status jeda
      secondsRemaining = isWorking ? workDuration * 60 : breakDuration * 60; // Reset waktu
    });
  }

  void _onTimerComplete() {
    if (!isWorking) {
      // Jika sesi istirahat selesai
      _resetToNextSession();
      return;
    }

    // Jika sesi kerja selesai, tampilkan dialog progres
    _showProgressDialog();
  }

  void _resetToNextSession() {
    setState(() {
      isTimerStarted = false;
      isPaused = false;
      isWorking = !isWorking;
      secondsRemaining = (isWorking ? workDuration : breakDuration) * 60;
    });
  }

  void _showProgressDialog() async {
    if (!isTimerStarted) return; // Jangan tampilkan dialog jika timer dihentikan
    String? progress = await showDialog<String>(
      context: context,
      builder: (context) {
        String tempProgress = '';
        return AlertDialog(
          title: const Text('Catat Progres'),
          content: TextField(
            onChanged: (value) => tempProgress = value,
            decoration: const InputDecoration(hintText: 'Apa yang sudah Anda kerjakan?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(tempProgress),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (progress != null && progress.isNotEmpty && isTimerStarted) {
      setState(() {
        sessionLogs.add(progress);
        _resetToNextSession();
      });
    }
  }

  void _showSettingsDialog() async {
    int tempWorkDuration = workDuration;
    int tempBreakDuration = breakDuration;
    String tempSessionTitle = sessionTitle;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pengaturan Sesi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Judul Sesi'),
                onChanged: (value) => tempSessionTitle = value,
                controller: TextEditingController(text: sessionTitle),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Durasi Kerja (menit)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => tempWorkDuration = int.tryParse(value) ?? workDuration,
                controller: TextEditingController(text: workDuration.toString()),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Durasi Istirahat (menit)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => tempBreakDuration = int.tryParse(value) ?? breakDuration,
                controller: TextEditingController(text: breakDuration.toString()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  sessionTitle = tempSessionTitle;
                  workDuration = tempWorkDuration;
                  breakDuration = tempBreakDuration;
                  secondsRemaining = workDuration * 60;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsRemaining % 60).toString().padLeft(2, '0');

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  sessionTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: Text(
                  isWorking ? 'Waktu Kerja' : 'Waktu Istirahat',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: isWorking ? Colors.green : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: Container(
                  width: constraints.maxWidth * 0.6, // Sesuaikan ukuran dengan layar
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: isWorking ? Colors.green[100] : Colors.blue[100],
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Text(
                    '$minutes:$seconds',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: isWorking ? Colors.green[800] : Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (!isTimerStarted)
                Flexible(
                  child: ElevatedButton(
                    onPressed: startTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text(
                      'Mulai',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                )
              else
                Flexible(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: pauseOrResumeTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          isPaused ? 'Lanjutkan' : 'Jeda',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: stopTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text(
                          'Berhenti',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Flexible(
                child: ElevatedButton(
                  onPressed: _showSettingsDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text(
                    'Pengaturan',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (sessionLogs.isNotEmpty)
                Flexible(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: sessionLogs.length,
                    itemBuilder: (context, index) => Card(
                      color: Colors.green[50],
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        title: Text(
                          'Sesi ${index + 1}',
                          style: TextStyle(color: Colors.green[800]),
                        ),
                        subtitle: Text(sessionLogs[index]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
