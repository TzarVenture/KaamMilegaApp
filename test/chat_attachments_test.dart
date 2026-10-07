import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/chat/models/chat_block_status.dart';
import 'package:kaam_milega/features/chat/models/chat_message.dart';
import 'package:kaam_milega/features/chat/models/conversation.dart';
import 'package:kaam_milega/features/chat/presentation/chat_detail_screen.dart';
import 'package:kaam_milega/features/chat/presentation/widgets/chat_attachments.dart';
import 'package:kaam_milega/features/chat/presentation/widgets/chat_emoji_sheet.dart';
import 'package:kaam_milega/features/chat/providers/chat_access_provider.dart';
import 'package:kaam_milega/features/chat/repositories/chat_repository.dart';
import 'package:kaam_milega/features/chat/services/chat_websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _msg(
  String id, {
  String sender = 'me',
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'conversation_id': 'c1',
  'sender_id': sender,
  'content': '',
  'created_at': '2026-10-05T09:00:00Z',
  ...extra,
};

/// Chat repository without a network: records uploads and sends.
class _Chats extends ChatRepository {
  _Chats(this.history) : super(ApiClient());

  final List<ChatMessage> history;
  bool failUpload = false;
  final uploads = <String>[];
  final sent = <({String content, ChatAttachment? attachment})>[];

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async => before == null
      ? history
            .skip(history.length > limit ? history.length - limit : 0)
            .toList()
      : const <ChatMessage>[];

  @override
  Future<ChatBlockStatus> getBlockStatus(String otherUserId) async =>
      ChatBlockStatus.none;

  @override
  Future<List<ConversationItem>> getConversations() async => const [];

  @override
  Future<void> markConversationRead(
    String conversationId, {
    String otherUserId = '',
  }) async {}

  @override
  Future<ChatAttachment> uploadAttachment(
    List<int> bytes,
    String filename,
  ) async {
    uploads.add(filename);
    if (failUpload) throw Exception('upload failed');
    return ChatAttachment(
      url: '/uploads/1_$filename',
      type: ChatRepository.mimeTypeFor(filename),
      name: filename,
      size: bytes.length,
    );
  }

  @override
  Future<ChatMessage> sendMessage({
    required String receiverId,
    required String content,
    ChatAttachment? attachment,
  }) async {
    sent.add((content: content, attachment: attachment));
    return ChatMessage(
      id: 'new${sent.length}',
      conversationId: 'c1',
      senderId: 'me',
      content: content,
      attachment: attachment,
    );
  }
}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'me', mobile: '9000000000', isRegistered: true),
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Chats chats, {
  PickedChatFile? picked,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ChatDetailScreen(
          conversationId: 'c1',
          receiverId: 'u2',
          title: 'Anwar Khan',
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_SignedIn.new),
        chatRepositoryProvider.overrideWithValue(chats),
        // Allowed to message (connection rules: chat_access_test).
        chatAccessProvider.overrideWith((ref, id) async => ChatAccess.allowed),
        chatFilePickerProvider.overrideWithValue((source) async => picked),
        chatWebSocketServiceProvider.overrideWith((ref) {
          final s = ChatWebSocketService(
            isOnline: () => false,
            networkStatus: const Stream.empty(),
          );
          ref.onDispose(s.dispose);
          return s;
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pickDocument(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Attach photo or file'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Document (PDF, DOC, DOCX, TXT)'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'jwt'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Attachment data', () {
    test('message reads the attachment fields', () {
      final m = ChatMessage.fromJson(
        _msg(
          'm1',
          extra: {
            'attachment_url': '/uploads/1_cv.pdf',
            'attachment_type': 'application/pdf',
            'attachment_name': 'cv.pdf',
            'attachment_size': 250000,
          },
        ),
      );
      expect(m.attachment!.name, 'cv.pdf');
      expect(m.attachment!.isImage, isFalse);
      expect(m.attachment!.sizeLabel, '244 KB');
      expect(ChatMessage.fromJson(_msg('m2')).attachment, isNull);
    });

    test('image by type or by file extension', () {
      expect(
        const ChatAttachment(url: '/u/a', type: 'image/png').isImage,
        isTrue,
      );
      expect(const ChatAttachment(url: '/u/photo.JPG').isImage, isTrue);
      expect(const ChatAttachment(url: '/u/notes.txt').isImage, isFalse);
      expect(formatFileSize(0), '');
      expect(formatFileSize(1572864), '1.5 MB');
    });

    test('upload sends the file with its type; send carries it', () async {
      final sent = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, handler) {
            sent.add(o);
            handler.resolve(
              Response<dynamic>(
                requestOptions: o,
                statusCode: 201,
                data: o.path == '/files/upload'
                    ? {
                        'url': '/uploads/9_cv.pdf',
                        'original_filename': 'cv.pdf',
                        'size': 3,
                        'mime_type': 'application/pdf',
                      }
                    : _msg('m1'),
              ),
            );
          },
        ),
      );
      final repo = ChatRepository(ApiClient(dio: dio));
      final attachment = await repo.uploadAttachment([1, 2, 3], 'cv.pdf');
      final form = sent.single.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.contentType?.mimeType, 'application/pdf');
      expect(attachment.url, '/uploads/9_cv.pdf');
      expect(attachment.type, 'application/pdf');

      await repo.sendMessage(
        receiverId: 'u2',
        content: '',
        attachment: attachment,
      );
      expect(sent.last.path, '/chats/messages');
      expect(sent.last.data, {
        'receiver_id': 'u2',
        'content': '',
        'attachment_url': '/uploads/9_cv.pdf',
        'attachment_type': 'application/pdf',
        'attachment_name': 'cv.pdf',
        'attachment_size': 3,
      });
    });
  });

  group('Chat screen', () {
    testWidgets('pick a document, see it, send it', (tester) async {
      final chats = _Chats([]);
      await _pump(
        tester,
        chats,
        picked: const PickedChatFile(name: 'cv.pdf', bytes: [1, 2, 3, 4]),
      );
      await _pickDocument(tester);
      expect(find.text('cv.pdf'), findsOneWidget); // preview
      expect(find.byTooltip('Remove attachment'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'My CV');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(chats.uploads, ['cv.pdf']);
      expect(chats.sent.single.content, 'My CV');
      expect(chats.sent.single.attachment!.url, '/uploads/1_cv.pdf');
      // Shown in the chat as a file with the text; preview gone.
      expect(find.text('cv.pdf'), findsOneWidget);
      expect(find.text('My CV'), findsOneWidget);
      expect(find.byTooltip('Remove attachment'), findsNothing);
    });

    testWidgets('a file alone (no text) can be sent', (tester) async {
      final chats = _Chats([]);
      await _pump(
        tester,
        chats,
        picked: const PickedChatFile(name: 'notes.txt', bytes: [1]),
      );
      await _pickDocument(tester);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(chats.sent.single.content, '');
      expect(chats.sent.single.attachment!.name, 'notes.txt');
    });

    testWidgets('upload failure keeps the file and the text', (tester) async {
      final chats = _Chats([])..failUpload = true;
      await _pump(
        tester,
        chats,
        picked: const PickedChatFile(name: 'cv.pdf', bytes: [1]),
      );
      await _pickDocument(tester);
      await tester.enterText(find.byType(TextField), 'My CV');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(chats.sent, isEmpty);
      expect(
        find.text('Could not upload the file. Please try again.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Remove attachment'), findsOneWidget);
      expect(find.text('My CV'), findsOneWidget);
    });

    testWidgets('files over 10 MB are refused', (tester) async {
      final chats = _Chats([]);
      await _pump(
        tester,
        chats,
        picked: PickedChatFile(
          name: 'big.pdf',
          bytes: List<int>.filled(ChatRepository.maxAttachmentBytes + 1, 0),
        ),
      );
      await _pickDocument(tester);
      expect(find.text('Files must be 10 MB or smaller.'), findsOneWidget);
      expect(find.byTooltip('Remove attachment'), findsNothing);
    });

    testWidgets('emoji button inserts the emoji at the cursor', (tester) async {
      await _pump(tester, _Chats([]));
      expect(find.text('Type a message...'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Thanks ');
      await tester.tap(find.byTooltip('Add emoji'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hands'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('\u{1F44D}'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Thanks \u{1F44D}');
    });

    test('emoji search finds by simple words', () {
      expect(searchEmoji('thumbs'), contains('\u{1F44D}'));
      expect(searchEmoji('than'), containsAll(['\u{1F917}', '\u{1F64F}']));
      expect(searchEmoji('heart green'), ['\u{1F49A}']);
      expect(searchEmoji('zzzz'), isEmpty);
      expect(searchEmoji('  '), isEmpty);
    });

    testWidgets('emoji sheet: search, then Recent remembers it', (
      tester,
    ) async {
      await _pump(tester, _Chats([]));
      await tester.tap(find.byTooltip('Add emoji'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'call');
      await tester.pumpAndSettle();
      expect(find.text('Smileys'), findsNothing); // results instead of tabs
      await tester.tap(find.bySemanticsLabel('\u{1F4DE}'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '\u{1F4DE}');

      await tester.tap(find.byTooltip('Add emoji'));
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'nothing-like-this');
      await tester.pumpAndSettle();
      expect(find.textContaining('No emoji found'), findsOneWidget);
    });

    testWidgets('received photo and file show in the bubbles', (tester) async {
      final chats = _Chats([
        ChatMessage.fromJson(
          _msg(
            'm1',
            sender: 'u2',
            extra: {
              'attachment_url': '/uploads/1_photo.jpg',
              'attachment_type': 'image/jpeg',
              'attachment_name': 'photo.jpg',
            },
          ),
        ),
        ChatMessage.fromJson(
          _msg(
            'm2',
            sender: 'u2',
            extra: {
              'attachment_url': '/uploads/2_offer.pdf',
              'attachment_type': 'application/pdf',
              'attachment_name': 'offer.pdf',
              'attachment_size': 2048,
            },
          ),
        ),
      ]);
      await _pump(tester, chats);
      final views = find.byType(MessageAttachmentView, skipOffstage: false);
      expect(views, findsNWidgets(2));
      Finder labelled(String label) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
        skipOffstage: false,
      );
      expect(labelled('photo.jpg'), findsOneWidget);
      expect(labelled('Open offer.pdf'), findsOneWidget);
      expect(find.text('offer.pdf', skipOffstage: false), findsOneWidget);
      expect(find.text('2 KB', skipOffstage: false), findsOneWidget);

      // Tapping the photo opens it full screen; Close returns.
      await tester.ensureVisible(labelled('photo.jpg'));
      await tester.pumpAndSettle();
      await tester.tap(labelled('photo.jpg'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
