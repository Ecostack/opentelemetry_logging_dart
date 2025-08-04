import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:opentelemetry_logging/src/backend/open_telemetry_backend.dart';
import 'package:opentelemetry_logging/src/model/log_entry.dart';

/// An OpenTelemetry backend that sends logs to a specified HTTP endpoint.
class OpenTelemetryHttpBackend implements OpenTelemetryBackend {
  final Uri _endpoint;

  final Map<String, String>? _headers;

  final Map<String, String>? _resourceAttributes;

  final http.Client _client;
  final bool _ownClient;
  final Future<void> Function({
    required int statusCode,
    required String body,
  })? _onPostError;

  /// Creates an OpenTelemetry backend that sends logs to a specified HTTP endpoint.
  /// If a [client] is provided, it will be used for sending requests;
  /// it will NOT be closed automatically upon [dispose].
  OpenTelemetryHttpBackend({
    required Uri endpoint,
    http.Client? client,
    Map<String, String>? headers,
    Map<String, String>? resourceAttributes,
    Future<void> Function({
      required int statusCode,
      required String body,
    })? onPostError,
  })  : _endpoint = endpoint,
        _client = client ?? http.Client(),
        _ownClient = client == null,
        _headers = headers,
        _resourceAttributes = resourceAttributes,
        _onPostError = onPostError;

  @override
  Future<void> dispose() async {
    if (_ownClient) {
      _client.close();
    }
  }

  @override
  Future<void> sendLogs(List<LogEntry> entries) async {
    final attributes =  _resourceAttributes?.entries.map(
          (entry) => {
        'key': entry.key,
        'value': {'stringValue': entry.value},
      },
    ) ?? [];

    final payload = jsonEncode({
      'resourceLogs': [
        {
          'resource': {
            'attributes': attributes,
          },
          'scopeLogs': [
            {
              'logRecords': entries.map((e) => e.toJson()).toList(),
            }
          ]
        }
      ]
    });
    final res = await _client.post(
      _endpoint,
      headers: {
        'Content-Type': 'application/json',
        ...?_headers,
      },
      body: payload,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (_onPostError != null) {
        await _onPostError(
          statusCode: res.statusCode,
          body: res.body,
        );
        return;
      }
    }
  }
}
