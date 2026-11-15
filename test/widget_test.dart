import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:emsi_skill_graph/main.dart';
import 'package:emsi_skill_graph/core/constants/env.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: '.env');

    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  });

  testWidgets('EMSI Skill Graph app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const EmsiSkillGraphApp());

    await tester.pump();

    expect(find.text('EMSI Skill Graph'), findsOneWidget);
  });
}
