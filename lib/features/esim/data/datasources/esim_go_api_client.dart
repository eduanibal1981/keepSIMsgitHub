import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:keep_sims/features/esim/data/models/esim_go_models.dart';

class EsimGoApiClient {
  static const String _baseUrl = 'https://api.esim-go.com/v2.4';
  final http.Client _client;

  EsimGoApiClient({http.Client? client}) : _client = client ?? http.Client();

  String get _apiKey {
    final key = dotenv.env['ESIM_GO_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('ESIM_GO_API_KEY is not defined in .env');
    }
    return key;
  }

  Map<String, String> get _headers => {
        'X-API-Key': _apiKey,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<List<EsimGoBundleDto>> getCatalogue({String? countryIsoCode}) async {
    final uri = countryIsoCode != null
        ? Uri.parse('$_baseUrl/catalogue?countries=$countryIsoCode')
        : Uri.parse('$_baseUrl/catalogue');
    
    final response = await _client.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonMap = jsonDecode(response.body);
      final List<dynamic> jsonList = jsonMap['bundles'] ?? [];
      
      final sanitizedList = jsonList.map((dynamic item) {
        if (item is Map<String, dynamic>) {
          if (item['countries'] is String) {
            item['countries'] = <dynamic>[];
          }
          if (item['roamingEnabled'] is String) {
            item['roamingEnabled'] = <dynamic>[];
          }
        }
        return item;
      }).toList();

      return sanitizedList.map((json) => EsimGoBundleDto.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load eSIM Go catalogue: ${response.statusCode} - ${response.body}');
    }
  }

  Future<EsimGoOrderResponseDto> createOrder(EsimGoOrderRequestDto request) async {
    final uri = Uri.parse('https://api.esim-go.com/v2.2/orders');
    
    final response = await _client.post(
      uri, 
      headers: _headers,
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonMap = jsonDecode(response.body);
      return EsimGoOrderResponseDto.fromJson(jsonMap as Map<String, dynamic>);
    } else {
      throw Exception('Failed to create eSIM Go order: ${response.statusCode} - ${response.body}');
    }
  }
}
