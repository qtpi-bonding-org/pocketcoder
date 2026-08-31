import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for ProDataApi
void main() {
  final instance = PocketcoderApi().getProDataApi();

  group(ProDataApi, () {
    // Purges this user's PocketCoder-Pro-hosted data (push-relay's Supabase rows and the RevenueCat customer record). Pure pass-through to push-relay -- never touches this deployment's own local PocketBase data, which the user already owns and controls on their own server.
    //
    //Future deleteProData() async
    test('test deleteProData', () async {
      // TODO
    });

  });
}
