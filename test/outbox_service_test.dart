import 'package:duo_draw/core/utils/result.dart';
import 'package:duo_draw/data/local/pending_drawings_store.dart';
import 'package:duo_draw/domain/repositories/drawing_repository.dart';
import 'package:duo_draw/models/drawing.dart';
import 'package:duo_draw/services/connectivity/connectivity_service.dart';
import 'package:duo_draw/services/sync/outbox_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faux repository : échoue tant que [online] est false, réussit ensuite.
class _FakeDrawingRepository implements DrawingRepository {
  bool online = false;
  final Set<String> rejectIds = {};
  final List<String> sentIds = [];

  @override
  Future<Result<Drawing>> sendDrawing(Drawing drawing) async {
    if (!online) return const Failure('offline');
    if (rejectIds.contains(drawing.id)) {
      return const Failure('refusé', permanent: true);
    }
    sentIds.add(drawing.id);
    return Success(drawing);
  }

  @override
  Future<Result<Drawing>> getDrawing({
    required String coupleId,
    required String drawingId,
  }) async =>
      const Failure('non utilisé');

  @override
  Stream<List<Drawing>> watchHistory(String coupleId) => const Stream.empty();

  @override
  Stream<Drawing?> watchLatestReceived({
    required String coupleId,
    required String uid,
  }) =>
      const Stream.empty();

  @override
  Future<Result<void>> react({
    required String coupleId,
    required String drawingId,
    required String? reaction,
  }) async =>
      const Success(null);

  @override
  Future<void> markViewed({
    required String coupleId,
    required String drawingId,
  }) async {}
}

class _FakeConnectivity extends ConnectivityService {
  bool connected = false;

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onConnectedChanged => const Stream.empty();
}

Drawing _drawing(String id) => Drawing(
      id: id,
      coupleId: 'c1',
      senderId: 'a',
      receiverId: 'b',
      strokes: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PendingDrawingsStore store;
  late _FakeDrawingRepository repo;
  late _FakeConnectivity connectivity;
  late OutboxService outbox;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = PendingDrawingsStore(prefs);
    repo = _FakeDrawingRepository();
    connectivity = _FakeConnectivity();
    outbox = OutboxService(
      store: store,
      drawingRepository: repo,
      connectivity: connectivity,
    );
  });

  test('hors-ligne : le dessin est conservé dans l\'outbox', () async {
    connectivity.connected = false;
    final outcome = await outbox.enqueueAndSend(_drawing('d1'));

    expect(outcome, SendOutcome.queued);
    expect(outbox.pendingCount, 1);
    expect(repo.sentIds, isEmpty);
  });

  test('en ligne : le dessin part immédiatement et quitte l\'outbox', () async {
    connectivity.connected = true;
    repo.online = true;
    final outcome = await outbox.enqueueAndSend(_drawing('d2'));

    expect(outcome, SendOutcome.sent);
    expect(outbox.pendingCount, 0);
    expect(repo.sentIds, ['d2']);
  });

  test('retour du réseau : flush envoie les dessins en attente une seule fois',
      () async {
    // Empilés hors-ligne.
    await outbox.enqueueAndSend(_drawing('d3'));
    await outbox.enqueueAndSend(_drawing('d4'));
    expect(outbox.pendingCount, 2);

    // Le réseau revient.
    connectivity.connected = true;
    repo.online = true;
    await outbox.flush();

    expect(outbox.pendingCount, 0);
    expect(repo.sentIds, ['d3', 'd4']);

    // Idempotence : un flush supplémentaire ne renvoie rien.
    await outbox.flush();
    expect(repo.sentIds, ['d3', 'd4']);
  });

  test('un dessin refusé définitivement ne bloque pas les suivants', () async {
    await outbox.enqueueAndSend(_drawing('bad'));
    await outbox.enqueueAndSend(_drawing('ok'));

    connectivity.connected = true;
    repo.online = true;
    repo.rejectIds.add('bad');
    await outbox.flush();

    expect(outbox.pendingCount, 0);
    expect(repo.sentIds, ['ok']);
  });

  test('envoi refusé : enqueueAndSend le signale', () async {
    connectivity.connected = true;
    repo.online = true;
    repo.rejectIds.add('bad');

    expect(await outbox.enqueueAndSend(_drawing('bad')), SendOutcome.rejected);
    expect(outbox.pendingCount, 0);
  });

  test("flush concurrents : chaque dessin n'est envoyé qu'une fois",
      () async {
    await outbox.enqueueAndSend(_drawing('c1'));
    await outbox.enqueueAndSend(_drawing('c2'));
    connectivity.connected = true;
    repo.online = true;

    await Future.wait([outbox.flush(), outbox.flush(), outbox.flush()]);

    expect(repo.sentIds, ['c1', 'c2']);
  });
}
