import 'package:appwrite/appwrite.dart';
import 'package:chat_app/models/chat.dart';
import 'package:chat_app/models/group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

const String kSessionId = 'session_id';

class NavigationHelper {
  NavigationHelper(this.isLoggedIn);

  bool isLoggedIn = false;

  late final router = GoRouter(
    urlPathStrategy: UrlPathStrategy.path,
    routes: <GoRoute>[
      GoRoute(
        path: '/',
        name: 'AuthPage',
        builder: (BuildContext context, GoRouterState state) =>
            const AuthPage(),
        redirect: (state) {
          if (isLoggedIn) {
            return '/groups';
          }
          return null;
        },
      ),
      GoRoute(
          path: '/groups',
          name: 'ListGroupPage',
          builder: (BuildContext context, GoRouterState state) =>
              const ListGroupPage(),
          redirect: (state) {
            if (!isLoggedIn) {
              return '/';
            }
            return null;
          },
          routes: [
            GoRoute(
              path: ':id',
              name: 'ChatsGroupPage',
              builder: (BuildContext context, GoRouterState state) =>
                  ChatsGroupPage(groupId: state.params['id']!),
              redirect: (state) {
                if (!isLoggedIn) {
                  return '/';
                }
                return null;
              },
            ),
          ]),
    ],
  );
}

class NavigationProvider extends InheritedWidget {
  const NavigationProvider({
    Key? key,
    required this.helper,
    required Widget child,
  }) : super(key: key, child: child);

  final NavigationHelper helper;

  static NavigationProvider of(BuildContext context) {
    final NavigationProvider? result =
        context.dependOnInheritedWidgetOfExactType<NavigationProvider>();
    assert(result != null, 'No NavigationProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(NavigationProvider oldWidget) =>
      helper != oldWidget.helper;
}

class AppWriteSdkProvider extends InheritedWidget {
  const AppWriteSdkProvider({
    Key? key,
    required this.sdk,
    required Widget child,
  }) : super(key: key, child: child);

  final Client sdk;

  static AppWriteSdkProvider of(BuildContext context) {
    final AppWriteSdkProvider? result =
        context.dependOnInheritedWidgetOfExactType<AppWriteSdkProvider>();
    assert(result != null, 'No AppWriteSdkProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(AppWriteSdkProvider oldWidget) =>
      sdk != oldWidget.sdk;
}

Future main() async {
  initializeDateFormatting('id_ID');
  WidgetsFlutterBinding.ensureInitialized();

  final sdk = Client();

  sdk
      .setEndpoint('https://api.salingtanya.com/v1')
      .setProject('625a6dd7756f7b94f8fa')
      .setSelfSigned();

  final sessionId = await const FlutterSecureStorage().read(key: kSessionId);

  runApp(
    NavigationProvider(
      helper: NavigationHelper(sessionId != null),
      child: AppWriteSdkProvider(
        sdk: sdk,
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final router = NavigationProvider.of(context).helper.router;

    return MaterialApp.router(
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      title: 'Chat Demo',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFf02e65),
          secondary: Color(0xFFf02e65),
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 280,
            height: 180,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: SvgPicture.asset(
                    'assets/images/appwrite-square-logo-pink.svg',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
                const Positioned(
                  top: 42,
                  right: 0,
                  left: 0,
                  child: Text(
                    'x',
                    style: TextStyle(
                      fontSize: 32,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Positioned(
                  top: 32,
                  right: 0,
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: FlutterLogo(),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                final sdk = AppWriteSdkProvider.of(context).sdk;
                final account = Account(sdk);

                try {
                  final result = await account.createAnonymousSession();
                  await const FlutterSecureStorage().write(
                    key: kSessionId,
                    value: result.$id,
                  );

                  NavigationProvider.of(context).helper.isLoggedIn = true;
                } on AppwriteException catch (e) {
                  if (e.type == 'user_session_already_exists') {
                    final user = await account.get();
                    await const FlutterSecureStorage().write(
                      key: kSessionId,
                      value: user.$id,
                    );

                    NavigationProvider.of(context).helper.isLoggedIn = true;
                  }
                } catch (e) {
                  Logger().i(e.toString());
                }

                final router = NavigationProvider.of(context).helper.router;

                router.goNamed('ListGroupPage');
              },
              child: const Text('Masuk'),
            ),
          ),
        ],
      ),
    );
  }
}

class ListGroupPage extends StatefulWidget {
  const ListGroupPage({Key? key}) : super(key: key);

  @override
  State<ListGroupPage> createState() => _ListGroupPageState();
}

class _ListGroupPageState extends State<ListGroupPage> {
  final groupsId = '625a72585c59cc8ae981';

  Client? sdk;
  late final Realtime realtime;
  late final RealtimeSubscription subscription;

  final List<Group> groups = <Group>[];
  final scrollController = ScrollController();

  _createGroup(String value) async {
    final database = Database(sdk!);
    database.createDocument(
        collectionId: groupsId,
        documentId: 'unique()',
        data: <String, String>{
          'name': value,
        });

    _scrollToBottom();
  }

  _scrollToBottom() {
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    subscription.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    if (sdk == null) {
      sdk = AppWriteSdkProvider.of(context).sdk;

      /// Initiate List Groups
      final database = Database(sdk!);
      database.listDocuments(collectionId: groupsId).then((value) {
        setState(() {
          groups.addAll(
            value.documents.map((e) {
              return Group.fromJson(e.data);
            }),
          );
        });
      });

      /// Initiate Realtime connection
      realtime = Realtime(sdk!);
      subscription = realtime.subscribe(['collections.$groupsId.documents'])
        ..stream.listen((event) {
          setState(() {
            groups.add(Group.fromJson(event.payload));
          });
        });
    }

    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            onPressed: () async {
              await const FlutterSecureStorage().deleteAll();
              NavigationProvider.of(context).helper.isLoggedIn = false;

              final router = NavigationProvider.of(context).helper.router;
              router.goNamed('AuthPage');
            },
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final controller = TextEditingController();
          showDialog(
              context: context,
              builder: (context) {
                return Dialog(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, bottom: 16, top: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Nama Group',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (value) async {
                            if (value.isEmpty) return;
                            _createGroup(value);
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Close'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () {
                                if (controller.text.isEmpty) return;
                                _createGroup(controller.text);
                                Navigator.pop(context);
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              });
        },
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
      body: ListView.builder(
          controller: scrollController,
          itemCount: groups.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(groups[index].name),
              onTap: () {
                final router = NavigationProvider.of(context).helper.router;

                router.goNamed('ChatsGroupPage', params: {
                  'id': groups[index].id,
                });
              },
            );
          }),
    );
  }
}

class ChatsGroupPage extends StatefulWidget {
  const ChatsGroupPage({Key? key, required this.groupId}) : super(key: key);

  final String groupId;

  @override
  State<ChatsGroupPage> createState() => _ChatsGroupPageState();
}

class _ChatsGroupPageState extends State<ChatsGroupPage> {
  final chatsId = '625a710b640050750cf8';

  Client? sdk;
  late final Realtime realtime;
  late final RealtimeSubscription subscription;

  final List<Chat> chats = <Chat>[];
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final focusNode = FocusNode();

  _createChat(String value) async {
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konten tidak boleh kosong...'),
        ),
      );
      return;
    }

    final database = Database(sdk!);
    database.createDocument(
        collectionId: chatsId,
        documentId: 'unique()',
        data: <String, dynamic>{
          'group_id': widget.groupId,
          'content': value,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

    _scrollToBottom();
    controller.clear();
    focusNode.requestFocus();
  }

  _scrollToBottom() {
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    subscription.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    if (sdk == null) {
      sdk = AppWriteSdkProvider.of(context).sdk;

      /// Initiate List Groups
      final database = Database(sdk!);
      database.listDocuments(collectionId: chatsId, queries: [
        Query.equal('group_id', widget.groupId),
      ]).then((value) {
        setState(() {
          chats.addAll(
            value.documents.map((e) {
              return Chat.fromJson(e.data);
            }),
          );
        });
      });

      /// Initiate Realtime connection
      realtime = Realtime(sdk!);
      subscription = realtime.subscribe(['collections.$chatsId.documents'])
        ..stream.listen((event) {
          setState(() {
            chats.add(Chat.fromJson(event.payload));
          });
        });
    }

    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMMM, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats Group'),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Row(
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  focusNode: focusNode,
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Say something...',
                  ),
                  onSubmitted: (value) async {
                    _createChat(value);
                  },
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _createChat(controller.text);
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
      body: ListView.builder(
          controller: scrollController,
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final createdBy = chats[index].write.first;
            final avatarSeed = createdBy.substring(0, 5) +
                createdBy.substring(createdBy.length - 4);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.white,
                child: Image.network(
                  'https://avatars.dicebear.com/api/adventurer/$avatarSeed.png',
                ),
              ),
              trailing: Text(
                formatter
                    .format(
                      DateTime.fromMillisecondsSinceEpoch(
                        chat.createdAt,
                      ),
                    )
                    .toString(),
              ),
              title: SelectableText(chat.content),
            );
          }),
    );
  }
}
