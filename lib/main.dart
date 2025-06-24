import 'dart:isolate';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

// Função pesada (simula cálculo)
int heavyTask(int count) {
  int sum = 0;
  for (int i = 0; i < count; i++) {
    sum += i;
  }
  return sum;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PerformanceDemo(),
    );
  }
}

class PerformanceDemo extends StatefulWidget {
  const PerformanceDemo({super.key});

  @override
  State<PerformanceDemo> createState() => _PerformanceDemoState();
}

class _PerformanceDemoState extends State<PerformanceDemo> {
  String _resultAsync = '⏳';
  String _resultIsolate = '⏳';
  int _counter = 0;

  Isolate? isolate;

  void _runWithAsync() async {
    setState(() {
      _resultAsync = 'Calculando... (UI vai travar)';
    });

    final start = DateTime.now();
    final result = heavyTask(1000000000);
    final duration = DateTime.now().difference(start).inMilliseconds / 1000;

    setState(() {
      _resultAsync = 'Resultado: $result';
    });
    setState(() {
      _resultAsync =
          'Resultado: $result\nTempo: ${duration.toStringAsFixed(2)}s';
    });
  }

  void _runWithIsolate() async {
    setState(() {
      _resultIsolate = 'Calculando... (UI fluida)';
    });
    print('Isolate iniciado');

    final start = DateTime.now();

    final receivePort = ReceivePort();

    isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);

    final sendPort = await receivePort.first as SendPort;
    print('SendPort recebido');

    final answerPort = ReceivePort();
    sendPort.send([1000000000, answerPort.sendPort]);
    print('Mensagem enviada para o isolate');

    final result = await answerPort.first;
    print('Resultado recebido do isolate: $result');
    final duration = DateTime.now().difference(start).inMilliseconds / 1000;

    // isolate!.kill(priority: Isolate.immediate); // encerra aqui ✅
    receivePort.close(); // fecha porta
    answerPort.close();

    setState(() {
      _resultIsolate =
          'Resultado: $result\nTempo: ${duration.toStringAsFixed(2)}s';
    });
  }

  void _stopIsolate() {
    if (isolate != null) {
      isolate!.kill(priority: Isolate.immediate);
      isolate = null;

      setState(() {
        _resultIsolate = '⛔ Isolate finalizado';
      });
    }
  }

  // Função que roda dentro do Isolate
  static void _isolateEntry(SendPort initialSendPort) {
    final port = ReceivePort();

    // Envia de volta o SendPort para comunicação
    initialSendPort.send(port.sendPort);

    port.listen((message) {
      final count = message[0] as int;
      final SendPort replyTo = message[1] as SendPort;

      final result = heavyTask(count);
      replyTo.send(result);
    });
  }

  // Contador visual para mostrar que a UI está fluida
  void _startCounter() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _counter++;
      });
      return true; // continua rodando para sempre
    });
  }

  @override
  void initState() {
    super.initState();
    _startCounter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Async vs Isolate')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Contador: $_counter', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _runWithAsync,
                  child: const Text('Rodar com async'),
                ),
                ElevatedButton(
                  onPressed: _runWithIsolate,
                  child: const Text('Rodar com isolate'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: Column(
                    children: [
                      const Text('Resultado async:'),
                      Text(_resultAsync, textAlign: TextAlign.center),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    children: [
                      const Text('Resultado isolate:'),
                      Text(_resultIsolate, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 36.0),
                child: ElevatedButton(
                  onPressed: _stopIsolate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: const Text(
                    'Kill Isolate',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
