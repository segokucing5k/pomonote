import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  List<Map<String, dynamic>> savedSessions = []; // Riwayat sesi yang tersimpan

  @override
  void initState() {
    super.initState();
    secondsRemaining = workDuration * 60;
    _loadSavedSessions(); // Load riwayat sesi saat inisialisasi
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

  Future<void> _loadSavedSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString('saved_sessions');
    if (sessionsJson != null) {
      final List<dynamic> sessionsList = json.decode(sessionsJson);
      setState(() {
        savedSessions = sessionsList.cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_sessions', json.encode(savedSessions));
  }

  void _endWorkSession() async {
    if (sessionLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada sesi yang perlu disimpan')),
      );
      return;
    }

    // Tampilkan dialog konfirmasi dan ringkasan
    bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Akhiri Sesi Kerja'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Judul: $sessionTitle'),
              const SizedBox(height: 8),
              Text('Total sesi selesai: ${sessionLogs.length}'),
              const SizedBox(height: 8),
              const Text('Progres yang dicatat:'),
              const SizedBox(height: 4),
              ...sessionLogs.asMap().entries.map((entry) => 
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                  child: Text('${entry.key + 1}. ${entry.value}'),
                )
              ),
              const SizedBox(height: 16),
              const Text('Simpan sesi ini ke riwayat?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Simpan & Akhiri'),
            ),
          ],
        );
      },
    );

    if (shouldSave == true) {
      // Simpan sesi ke riwayat
      final sessionData = {
        'title': sessionTitle,
        'date': DateTime.now().toIso8601String(),
        'logs': List<String>.from(sessionLogs),
        'totalSessions': sessionLogs.length,
      };

      setState(() {
        savedSessions.add(sessionData);
        // Reset sesi saat ini
        sessionLogs.clear();
        sessionTitle = 'belajar bang';
        isTimerStarted = false;
        isPaused = false;
        isWorking = true;
        secondsRemaining = workDuration * 60;
      });

      await _saveSessions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi berhasil disimpan ke riwayat')),
        );
      }
    }
  }

  void _showSessionHistory() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Riwayat Sesi'),
          content: savedSessions.isEmpty 
            ? const Text('Belum ada riwayat sesi')
            : SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: savedSessions.length,
                  itemBuilder: (context, index) {
                    final session = savedSessions[index];
                    final date = DateTime.parse(session['date']);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ExpansionTile(
                        title: Text(session['title']),
                        subtitle: Text(
                          '${date.day}/${date.month}/${date.year} - ${session['totalSessions']} sesi'
                        ),
                        children: [
                          ...((session['logs'] as List).asMap().entries.map((entry) =>
                            ListTile(
                              dense: true,
                              title: Text('Sesi ${entry.key + 1}: ${entry.value}'),
                            )
                          )),
                        ],
                      ),
                    );
                  },
                ),
              ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
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
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _showSettingsDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text(
                        'Pengaturan',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: sessionLogs.isNotEmpty ? _endWorkSession : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text(
                        'Akhiri Kerja',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _showSessionHistory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text(
                        'Riwayat',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                  ],
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
