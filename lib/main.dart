import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:messaging/firebase_options.dart';
import 'package:messaging/pages/chat_list.dart';
import 'package:messaging/pages/friend_list.dart';
import 'package:messaging/services/database.dart';
import 'package:messaging/services/pool_manager.dart';
import 'package:messaging/utils/utils.dart';

import 'storage/database_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await DatabaseManager.initLocalDatabase(false);

  // await LocalStorage.init("TzWi21xBmrL8VpstcZud");
  // LocalStorage.clear(onlyGlobal: false);
  // await LocalStorage.init("Y8C4TmFks3cWjzzOsTkK");
  // LocalStorage.clear(onlyGlobal: false);

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

  final List<Widget> pages = const [ChatList(), FriendList()];

  final ValueNotifier<int> _currentIndex = ValueNotifier(0);

  @override
  void dispose() {
    _controller.dispose();
    _currentIndex.dispose();

    PoolManager.closePools().then((value) {
      // LocalStorage.clear(onlyGlobal: false);
    });
    DatabaseManager.closeLocalDatabase();
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // context.showDialog(
          //   child: const Material(
          //     child: AddFriend(),
          //   ),
          // );
        },
        child: const Icon(Icons.add),
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
                icon: Icon(Icons.chat_bubble),
              ),
              BottomNavigationBarItem(
                label: "Friends",
                icon: Icon(Icons.contact_mail),
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

  void _login() async {
    final query = firestore
        .collection(Collection.user)
        .where("email", isEqualTo: _controller.text)
        .limit(1);

    context.loading(
      removeOnceFutureComplete: false,
      future: query.get().then(
        (snapshot) {
          if (snapshot.size > 0) {
            return snapshot.docs.first.data();
          } else {
            return null;
          }
        },
      ),
      onSuccess: (data) async {
        if (data != null) {
          print("found user: $data");

          await LocalStorage.init(data["id"]);
          await LocalStorage.write(
            "user",
            json.encode(data),
            useGlobal: true,
          );

          await PoolManager.initPools();

          if (mounted) {
            context.pushReplacement(
              page: const MyHomePage(),
            );
          }
        } else {
          print("No user found for ${_controller.text}");
        }
      },
    );
  }
}
