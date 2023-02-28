import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:messaging/firebase_options.dart';
import 'package:messaging/pages/chat_list.dart';
import 'package:messaging/pages/contact_list.dart';
import 'package:messaging/services/pool_manager.dart';
import 'package:messaging/utils/utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PageController _controller = PageController();

  final List<Widget> pages = const [ChatList(), ContactList()];

  final ValueNotifier<int> _currentIndex = ValueNotifier(0);

  @override
  void dispose() {
    _controller.dispose();
    _currentIndex.dispose();

    PoolManager.instance.closePools().then((value) {
      LocalStorage.clear(onlyGlobal: false);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Chat Demo"),
      ),
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (value) {
          _currentIndex.value = value;
        },
        children: pages,
      ),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: _currentIndex,
        builder: (_, index, __) {
          return BottomNavigationBar(
            currentIndex: index,
            selectedItemColor: Colors.red,
            unselectedItemColor: Colors.blue,
            onTap: (value) {
              _controller.jumpToPage(value);
              _currentIndex.value = value;
            },
            items: const [
              BottomNavigationBarItem(
                label: "Chat",
                icon: Icon(Icons.home),
              ),
              BottomNavigationBarItem(
                label: "Contact",
                icon: Icon(Icons.home),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _controller =
      TextEditingController(text: "dengpan9610.wang@gmail.com");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: 300,
          child: Column(
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              OutlinedButton(
                onPressed: _login,
                child: const Text("Login"),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _login() {
    context.loading(
      future: _auth().then(
        (_) => PoolManager.instance.initPools(),
      ),
      onSuccess: (_) {
        context.push(
          page: const MyHomePage(),
        );
      },
      onException: (e) {
        print("exception on login: $e");
      },
    );
  }

  final map = {
    "dengpan9610.wang@gmail.com": "Y8C4TmFks3cWjzzOsTkK",
    "dengpan1002.wang@gmail.com": "TzWi21xBmrL8VpstcZud",
  };

  Future<void> _auth() async {
    final email = _controller.text;
    final userId = map[email]!;

    await LocalStorage.init(userId);
    await LocalStorage.write("userEmail", email);
  }
}
