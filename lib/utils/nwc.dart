import 'package:flutter_data/flutter_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ndk/domain_layer/usecases/nwc/consts/nwc_method.dart';
import 'package:ndk/ndk.dart';
import 'package:zapstore/main.data.dart';
import 'package:zapstore/models/user.dart';

const kNwcSecretKey = 'nwc_secret';

class NwcConnectionNotifier extends StateNotifier<AsyncValue<NwcConnection?>> {
  Ref ref;
  late Ndk ndk;

  final _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  NwcConnectionNotifier(this.ref) : super(AsyncLoading()) {
    ndk = ref.users.nostrAdapter.socialRelays.ndk!;
    // Attempt to load from local storage on initialization
    _storage
        .read(key: kNwcSecretKey)
        .then(connectWallet)
        .catchError((e, stack) {
      state = AsyncError(e, stack);
    });
  }

  Future<void> connectWallet([String? nwcSecret]) async {
    if (nwcSecret == null) {
      // We get here when storage has no secret, do nothing
      state = AsyncData(null);
      return;
    }

    state = AsyncValue.loading();

    // If secret is supplied and a connection is still active,
    // it means it is a new connection string so disconnect NWC
    if (state.value != null) {
      await ndk.nwc.disconnect(state.value!);
    }

    // Write secret to storage and connect
    await _storage.write(key: kNwcSecretKey, value: nwcSecret);

    try {
      final connection = await ndk.nwc.connect(
        nwcSecret,
        doGetInfoMethod: false,
      );
      if (connection.permissions.contains(NwcMethod.PAY_INVOICE.name)) {
        state = AsyncValue.data(connection);
      } else {
        state = AsyncError('No permission to zap', StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> disconnectWallet() async {
    await _storage.delete(key: kNwcSecretKey);
    state = AsyncData(null);
  }
}

final nwcConnectionProvider =
    StateNotifierProvider<NwcConnectionNotifier, AsyncValue<NwcConnection?>>(
        (ref) => NwcConnectionNotifier(ref));

extension NwcExt on AsyncValue<NwcConnection?> {
  bool get isPresent {
    return hasValue && value != null && !hasError;
  }
}
