import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const AtivadorApp());
}

class AtivadorApp extends StatelessWidget {
  const AtivadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ativador',
      theme: ThemeData.dark(),
      home: const TelaAtivacao(),
    );
  }
}

class TelaAtivacao extends StatefulWidget {
  const TelaAtivacao({super.key});

  @override
  State<TelaAtivacao> createState() => _TelaAtivacaoState();
}

class _TelaAtivacaoState extends State<TelaAtivacao> {
  final TextEditingController _licencaController = TextEditingController();
  bool _processando = false;
  String _status = '';

  Future<void> _ativarEInstalar() async {
    final codigo = _licencaController.text.trim();
    if (codigo.isEmpty) {
      setState(() => _status = 'Por favor, digite a licença!');
      return;
    }

    setState(() {
      _processando = true;
      _status = 'Solicitando permissões...';
    });

    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
    await Permission.requestInstallPackages.request();

    try {
      setState(() => _status = 'Validando licença no servidor...');
      final urlValidacao = 'https://app-key-master.lovable.app/api/validar?codigo=$codigo';
      final responseValidacao = await http.get(Uri.parse(urlValidacao));

      if (responseValidacao.statusCode != 200) {
        setState(() => _status = 'Licença inválida ou erro no painel.');
        _processando = false;
        return;
      }

      final conteudoConfig = responseValidacao.body;

      setState(() => _status = 'Gravando arquivo .config...');
      final configFile = File('/sdcard/Android/.config');
      await configFile.writeAsString(conteudoConfig);

      setState(() => _status = 'Baixando aplicativo UniTV...');
      final urlApk = 'https://app-key-master.lovable.app/downloads/unitv.apk';
      final responseApk = await http.get(Uri.parse(urlApk));

      final apkFile = File('/sdcard/Download/unitv.apk');
      await apkFile.writeAsBytes(responseApk.bodyBytes);

      setState(() => _status = 'Ativado com sucesso! Iniciando instalação...');

      await Process.run('am', ['start', '-a', 'android.intent.action.VIEW', '-d', 'file://${apkFile.path}', '-t', 'application/vnd.android.package-archive']);

    } catch (e) {
      setState(() => _status = 'Erro: $e');
    } finally {
      setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ativador Express'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.vpn_key, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            TextField(
              controller: _licencaController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Digite sua Licença',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _processando ? null : _ativarEInstalar,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(55),
                backgroundColor: Colors.blueAccent,
              ),
              child: _processando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ATIVAR E INSTALAR', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.amber)),
          ],
        ),
      ),
    );
  }
}
