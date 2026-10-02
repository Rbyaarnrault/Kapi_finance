import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

// API Yahoo Finance pour récupérer les données financières et graphiques

class YahooSearchResult {
  final String symbol;
  final String shortname;
  final String longname;
  final String exchange;
  final String quoteType;
  final String currency;

  YahooSearchResult({
    required this.symbol,
    required this.shortname,
    required this.longname,
    required this.exchange,
    required this.quoteType,
    required this.currency,
  });

  factory YahooSearchResult.fromJson(Map<String, dynamic> json) {
    return YahooSearchResult(
      symbol: json['symbol'] ?? '',
      shortname: json['shortname'] ?? json['longname'] ?? json['symbol'] ?? '',
      longname: json['longname'] ?? json['shortname'] ?? '',
      exchange: json['exchange'] ?? '',
      quoteType: json['quoteType'] ?? 'ETF',
      currency: json['currency'] ?? 'EUR',
    );
  }
}

class YahooFinanceService {
  static final YahooFinanceService _instance = YahooFinanceService._internal();
  factory YahooFinanceService() => _instance;
  YahooFinanceService._internal();

  final Map<String, double> _priceCache = {};
  final Map<String, List<FlSpot>> _historyCache = {};

  String _buildUrl(String targetUrl) {
    if (kIsWeb) {
      return 'https://corsproxy.io/?' + Uri.encodeComponent(targetUrl);
    }
    return targetUrl;
  }

  Future<List<YahooSearchResult>> searchAssets(String query) async {
    if (query.trim().isEmpty) return [];
    final rawUrl =
        'https://query2.finance.yahoo.com/v1/finance/search?q=${Uri.encodeComponent(query.trim())}&quotesCount=15&newsCount=0';
    final url = Uri.parse(_buildUrl(rawUrl));

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List quotes = data['quotes'] ?? [];
        return quotes
            .map((item) => YahooSearchResult.fromJson(item))
            .where((item) => item.symbol.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('Erreur recherche Yahoo: $e');
    }
    return [];
  }

  Future<List<FlSpot>> getHistoricalPoints(String ticker,
      {String range = '1y', String interval = '1d', bool forceRefresh = false}) async {
    final cacheKey = '$ticker-$range';

    if (!forceRefresh && _historyCache.containsKey(cacheKey)) {
      return _historyCache[cacheKey]!;
    }

    final rawUrl =
        'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(ticker)}?range=$range&interval=$interval';
    final url = Uri.parse(_buildUrl(rawUrl));

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']['result'][0];
        final List timestamps = result['timestamp'] ?? [];
        final List closes = result['indicators']['quote'][0]['close'] ?? [];

        List<FlSpot> spots = [];
        for (int i = 0; i < timestamps.length; i++) {
          if (closes[i] != null && timestamps[i] != null) {
            double price = (closes[i] as num).toDouble();
            double timeInMs = (timestamps[i] as num).toDouble() * 1000;
            spots.add(FlSpot(timeInMs, price));
          }
        }

        if (spots.isNotEmpty) {
          _historyCache[cacheKey] = spots;
          _priceCache[ticker] = spots.last.y;
          return spots;
        }
      }
    } catch (e) {
      debugPrint('Erreur graphique Yahoo ($ticker): $e');
    }

    return _historyCache[cacheKey] ?? [];
  }
}