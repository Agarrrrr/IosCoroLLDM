import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      timeout: const Duration(minutes: 25),
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        final output = Directory(Platform.environment['AUDIT_OUTPUT_DIR'] ??
            'output/performance_audit_2026-09-29');
        await output.create(recursive: true);
        final screenshots =
            data?.remove('screenshots') as Map<String, dynamic>?;
        for (final entry in (screenshots ?? <String, dynamic>{}).entries) {
          await File('${output.path}/${entry.key}.png')
              .writeAsBytes(base64Decode(entry.value as String));
        }
        final filename = Platform.environment['AUDIT_RESULT_NAME'] ?? 'results';
        await File('${output.path}/$filename.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
        if (data?['scenarios'] is! Map || (data!['scenarios'] as Map).isEmpty) {
          throw StateError('La prueba no devolvió escenarios medidos.');
        }
      },
    );
