import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const EscolaJujutsuApp());
}

class EscolaJujutsuApp extends StatelessWidget {
  const EscolaJujutsuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Escola Jujutsu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const RoteadorAutenticacao(),
    );
  }
}

// Roteador: Decide se mostra Login ou Central Jujutsu
class RoteadorAutenticacao extends StatelessWidget {
  const RoteadorAutenticacao({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return CentralJujutsuScreen(user: snapshot.data!);
        }
        return const LoginScreen();
      },
    );
  }
}

// ================= TELA DE LOGIN =================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _carregando = false;

  Future<void> _fazerLoginGoogle() async {
  setState(() => _carregando = true);
  try {
    if (kIsWeb) {
      // No navegador Web, utiliza a janela pop-up direta do Firebase
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } else {
      // Em dispositivos móveis (Android / iOS)
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao realizar login: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _carregando = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, size: 80, color: Colors.purpleAccent),
              const SizedBox(height: 24),
              const Text(
                'ESCOLA JUJUTSU',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Acesso restrito para feiticeiros',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              _carregando
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.login, color: Colors.black),
                      label: const Text('ENTRAR COM GOOGLE'),
                      onPressed: _fazerLoginGoogle,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= CENTRAL JUJUTSU =================
class CentralJujutsuScreen extends StatelessWidget {
  final User user;

  const CentralJujutsuScreen({super.key, required this.user});

  void _abrirModalNovaMissao(BuildContext context) {
    final tituloController = TextEditingController();
    final grauController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Missão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloController,
              decoration: const InputDecoration(labelText: 'Título da Missão'),
            ),
            TextField(
              controller: grauController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Grau (ex: 1, 2, 3 ou Especial)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tituloController.text.isNotEmpty &&
                  grauController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('missoes').add({
                  'titulo': tituloController.text,
                  'grau': grauController.text,
                  'concluida': false,
                  'usuarioId': FirebaseAuth.instance.currentUser!.uid,
                  'criadoEm': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Cadastrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central Jujutsu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair da conta',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Perfil do Feiticeiro
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[900],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bem-vindo,', style: TextStyle(color: Colors.grey)),
                      Text(
                        user.displayName ?? 'Feiticeiro Anônimo',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user.email ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista de Missões (Filtrada estritamente pelo usuarioId)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('missoes')
                  .where('usuarioId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma missão cadastrada ainda.'),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final String titulo = data['titulo'] ?? '';
                    final String grau = data['grau']?.toString() ?? '';
                    final bool concluida = data['concluida'] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Checkbox(
                          value: concluida,
                          onChanged: (novoValor) {
                            FirebaseFirestore.instance
                                .collection('missoes')
                                .doc(doc.id)
                                .update({'concluida': novoValor ?? false});
                          },
                        ),
                        title: Text(
                          titulo,
                          style: TextStyle(
                            decoration: concluida
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text('Grau: $grau'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () {
                            FirebaseFirestore.instance
                                .collection('missoes')
                                .doc(doc.id)
                                .delete();
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirModalNovaMissao(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova Missão'),
      ),
    );
  }
}