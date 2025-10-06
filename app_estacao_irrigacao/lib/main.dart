import 'package:app_estacao_irrigacao/pages/login_page.dart';
import 'package:app_estacao_irrigacao/pages/home_page.dart';
import 'package:app_estacao_irrigacao/models/user.dart';
import 'package:app_estacao_irrigacao/config/flavor_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Configura emuladores apenas em desenvolvimento
  if (FlavorConfig.isDevelopment) {
    await FirebaseAuth.instance.useAuthEmulator(
      FlavorConfig.authEmulatorHost, 
      FlavorConfig.authEmulatorPort
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      FlavorConfig.firestoreEmulatorHost, 
      FlavorConfig.firestoreEmulatorPort
    );
  }
  
  try {
    await FirebaseFirestore.instance.enablePersistence(
      const PersistenceSettings(synchronizeTabs: true),
    );
  } catch (e) {
    // Ignorar erro se a persistência já estiver habilitada
  }
  
  FirebaseFirestore.instance.settings = const Settings(
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    persistenceEnabled: true,
  );
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: FlavorConfig.appName,
      home: const AuthChecker()
    );
  }
}

class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

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
        
        if (snapshot.hasData && snapshot.data != null) {
          return _buildHomePage(snapshot.data!);
        }
        
        return const LoginPage();
      },
    );
  }

  Widget _buildHomePage(User user) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          if (data != null) {
            Client client = Client.fromMap(data as Map<String, dynamic>);
            return HomePage(client: client);
          }
        }
        
        return const LoginPage();
      },
    );
  }
}
