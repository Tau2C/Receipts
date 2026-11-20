import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pds_flutter/pds_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pds client connectivity test', (WidgetTester tester) async {
    final PdsClient client = PdsClient();
    final bool connected = await client.isConnected();
    expect(connected, false);
  });
}
