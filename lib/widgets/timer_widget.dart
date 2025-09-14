import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Session types - moved outside the class
enum SessionType { focus, shortBreak, longBreak }

class TimerWidget extends StatefulWidget {
  const TimerWidget({super.key});

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> with TickerProviderStateMixin {
  int workDuration = 25; // Default waktu kerja (menit)
  int breakDuration = 5; // Default waktu istirahat (menit)
  int longBreakDuration = 15; // Default waktu istirahat panjang (menit)
  bool isWorking = true;
  int secondsRemaining = 0;
  List<String> sessionLogs = [];
  String sessionTitle = 'belajar bang'; // Default judul sesi
  bool isPaused = false; // Status apakah timer sedang dijeda
  bool isTimerStarted = false; // Status apakah timer sudah dimulai
  List<Map<String, dynamic>> savedSessions = []; // Riwayat sesi yang tersimpan
  late TabController _tabController;

  SessionType currentSessionType = SessionType.focus;

  @override
  void initState() {
    super.initState();
    secondsRemaining = workDuration * 60;
    _loadSavedSessions();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // Hanya izinkan perubahan tab jika timer tidak sedang berjalan
    if (!isTimerStarted && !isPaused) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            currentSessionType = SessionType.focus;
            isWorking = true;
            secondsRemaining = workDuration * 60;
            break;
          case 1:
            currentSessionType = SessionType.shortBreak;
            isWorking = false;
            secondsRemaining = breakDuration * 60;
            break;
          case 2:
            currentSessionType = SessionType.longBreak;
            isWorking = false;
            secondsRemaining = longBreakDuration * 60;
            break;
        }
      });
    } else {
      // Jika timer sedang berjalan, kembalikan ke tab yang sesuai dengan session saat ini
      _updateTabController();
    }
  }

  void _updateTabController() {
    // Update tanpa trigger listener
    _tabController.removeListener(_onTabChanged);
    switch (currentSessionType) {
      case SessionType.focus:
        _tabController.animateTo(0);
        break;
      case SessionType.shortBreak:
        _tabController.animateTo(1);
        break;
      case SessionType.longBreak:
        _tabController.animateTo(2);
        break;
    }
    _tabController.addListener(_onTabChanged);
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
      
      if (currentSessionType == SessionType.focus) {
        // Setelah fokus, tentukan istirahat pendek atau panjang
        if (sessionLogs.length > 0 && (sessionLogs.length + 1) % 4 == 0) {
          currentSessionType = SessionType.longBreak;
          secondsRemaining = longBreakDuration * 60;
        } else {
          currentSessionType = SessionType.shortBreak;
          secondsRemaining = breakDuration * 60;
        }
        isWorking = false;
      } else {
        // Setelah istirahat, kembali ke fokus
        currentSessionType = SessionType.focus;
        isWorking = true;
        secondsRemaining = workDuration * 60;
      }
    });
    _updateTabController();
  }

  void _showProgressDialog() async {
    if (!isTimerStarted) return; // Jangan tampilkan dialog jika timer dihentikan
    String? progress = await showDialog<String>(
      context: context,
      builder: (context) {
        String tempProgress = '';
        return AlertDialog(
          backgroundColor: const Color(0xFF34495E),
          title: const Text(
            'Catat Progres',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            onChanged: (value) => tempProgress = value,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Apa yang sudah Anda kerjakan?',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF5DADE2)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF5DADE2)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(tempProgress),
              child: const Text(
                'Simpan',
                style: TextStyle(color: Color(0xFF5DADE2)),
              ),
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
    int tempLongBreakDuration = longBreakDuration;
    String tempSessionTitle = sessionTitle;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF34495E),
          title: const Text(
            'Pengaturan Sesi',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Judul Sesi',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5DADE2)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5DADE2)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) => tempSessionTitle = value,
                controller: TextEditingController(text: sessionTitle),
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Durasi Fokus (menit)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5DADE2)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5DADE2)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                onChanged: (value) => tempWorkDuration = int.tryParse(value) ?? workDuration,
                controller: TextEditingController(text: workDuration.toString()),
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Durasi Istirahat Pendek (menit)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5DADE2)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5DADE2)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                onChanged: (value) => tempBreakDuration = int.tryParse(value) ?? breakDuration,
                controller: TextEditingController(text: breakDuration.toString()),
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Durasi Istirahat Panjang (menit)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5DADE2)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5DADE2)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                onChanged: (value) => tempLongBreakDuration = int.tryParse(value) ?? longBreakDuration,
                controller: TextEditingController(text: longBreakDuration.toString()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  sessionTitle = tempSessionTitle;
                  workDuration = tempWorkDuration;
                  breakDuration = tempBreakDuration;
                  longBreakDuration = tempLongBreakDuration;
                  
                  // Update current session time based on current type
                  switch (currentSessionType) {
                    case SessionType.focus:
                      secondsRemaining = workDuration * 60;
                      break;
                    case SessionType.shortBreak:
                      secondsRemaining = breakDuration * 60;
                      break;
                    case SessionType.longBreak:
                      secondsRemaining = longBreakDuration * 60;
                      break;
                  }
                });
                Navigator.of(context).pop();
              },
              child: const Text(
                'Simpan',
                style: TextStyle(color: Color(0xFF5DADE2)),
              ),
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
          backgroundColor: const Color(0xFF34495E),
          title: const Text(
            'Akhiri Sesi Kerja',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Judul: $sessionTitle',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Total sesi selesai: ${sessionLogs.length}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Progres yang dicatat:',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 4),
              ...sessionLogs.asMap().entries.map((entry) => 
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                  child: Text(
                    '${entry.key + 1}. ${entry.value}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              ),
              const SizedBox(height: 16),
              const Text(
                'Simpan sesi ini ke riwayat?',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Simpan & Akhiri',
                style: TextStyle(color: Color(0xFF5DADE2)),
              ),
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
          backgroundColor: const Color(0xFF34495E),
          title: const Text(
            'Riwayat Sesi',
            style: TextStyle(color: Colors.white),
          ),
          content: savedSessions.isEmpty 
            ? const Text(
                'Belum ada riwayat sesi',
                style: TextStyle(color: Colors.grey),
              )
            : SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: savedSessions.length,
                  itemBuilder: (context, index) {
                    final session = savedSessions[index];
                    final date = DateTime.parse(session['date']);
                    return Card(
                      color: const Color(0xFF2C3E50),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ExpansionTile(
                        title: Text(
                          session['title'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${date.day}/${date.month}/${date.year} - ${session['totalSessions']} sesi',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        iconColor: const Color(0xFF5DADE2),
                        children: [
                          ...((session['logs'] as List).asMap().entries.map((entry) =>
                            ListTile(
                              dense: true,
                              title: Text(
                                'Sesi ${entry.key + 1}: ${entry.value}',
                                style: const TextStyle(color: Colors.grey),
                              ),
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
              child: const Text(
                'Tutup',
                style: TextStyle(color: Color(0xFF5DADE2)),
              ),
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
    
    int totalSeconds;
    switch (currentSessionType) {
      case SessionType.focus:
        totalSeconds = workDuration * 60;
        break;
      case SessionType.shortBreak:
        totalSeconds = breakDuration * 60;
        break;
      case SessionType.longBreak:
        totalSeconds = longBreakDuration * 60;
        break;
    }
    
    final progress = (totalSeconds - secondsRemaining) / totalSeconds;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                          MediaQuery.of(context).padding.top - 
                          MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Title
                      Text(
                        sessionTitle,
                        style: const TextStyle(
                          color: Color(0xFF5DADE2),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Tab Bar
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF34495E),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: AbsorbPointer(
                          absorbing: isTimerStarted || isPaused, // Disable tab switching saat timer berjalan
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: const Color(0xFF5DADE2),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: Colors.white,
                            unselectedLabelColor: (isTimerStarted || isPaused) 
                              ? Colors.grey[600] // Warna lebih gelap saat disabled
                              : Colors.grey[400],
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: (isTimerStarted || isPaused) 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            ),
                            tabs: [
                              Tab(
                                child: Text(
                                  'Fokus',
                                  style: TextStyle(
                                    color: (isTimerStarted || isPaused) && currentSessionType == SessionType.focus
                                      ? Colors.white
                                      : null,
                                  ),
                                ),
                              ),
                              Tab(
                                child: Text(
                                  'Istirahat Pendek',
                                  style: TextStyle(
                                    color: (isTimerStarted || isPaused) && currentSessionType == SessionType.shortBreak
                                      ? Colors.white
                                      : null,
                                  ),
                                ),
                              ),
                              Tab(
                                child: Text(
                                  'Istirahat Panjang',
                                  style: TextStyle(
                                    color: (isTimerStarted || isPaused) && currentSessionType == SessionType.longBreak
                                      ? Colors.white
                                      : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Circular Timer
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: Stack(
                          children: [
                            // Background circle
                            Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF34495E),
                                  width: 8,
                                ),
                              ),
                            ),
                            // Progress circle
                            SizedBox(
                              width: 250,
                              height: 250,
                              child: CircularProgressIndicator(
                                value: isTimerStarted ? progress : 0,
                                strokeWidth: 8,
                                backgroundColor: Colors.transparent,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF5DADE2),
                                ),
                              ),
                            ),
                            // Timer text
                            Center(
                              child: Text(
                                '$minutes:$seconds',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Start/Control Button
                      if (!isTimerStarted)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            onPressed: startTimer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5DADE2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'MULAI',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: pauseOrResumeTimer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Text(isPaused ? 'Lanjutkan' : 'Jeda'),
                            ),
                            ElevatedButton(
                              onPressed: stopTimer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: const Text('Berhenti'),
                            ),
                          ],
                        ),
                      
                      const Spacer(),
                      
                      // Bottom buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          TextButton(
                            onPressed: _showSettingsDialog,
                            child: const Text(
                              'Pengaturan',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _showSessionHistory,
                            child: const Text(
                              'Riwayat',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // End Work button (only show if there are sessions)
                      if (sessionLogs.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: TextButton(
                            onPressed: _endWorkSession,
                            child: const Text(
                              'Akhiri Kerja',
                              style: TextStyle(
                                color: Colors.purple,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
