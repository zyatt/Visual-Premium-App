import 'package:flutter/foundation.dart';
import 'package:visualpremium/data/materials_repository.dart';
import 'package:visualpremium/data/products_repository.dart';
import 'package:visualpremium/data/orcamentos_repository.dart';
import 'package:visualpremium/models/material_item.dart';
import 'package:visualpremium/models/product_item.dart';
import 'package:visualpremium/models/orcamento_item.dart';

class DataProvider extends ChangeNotifier {
  final _materialsApi = MaterialsApiRepository();
  final _productsApi = ProductsApiRepository();
  final _orcamentosApi = OrcamentosApiRepository();

  List<MaterialItem> _materials = [];
  List<ProductItem> _products = [];
  List<OrcamentoItem> _orcamentos = [];

  bool _isLoaded = false;
  bool _isLoading = false;
  String? _error;

  List<MaterialItem> get materials => _materials;
  List<ProductItem> get products => _products;
  List<OrcamentoItem> get orcamentos => _orcamentos;
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAllData() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Carrega todos os dados em paralelo
      final results = await Future.wait([
        _materialsApi.fetchMaterials(),
        _productsApi.fetchProducts(),
        _orcamentosApi.fetchOrcamentos(),
      ]);

      _materials = results[0] as List<MaterialItem>;
      _products = results[1] as List<ProductItem>;
      _orcamentos = results[2] as List<OrcamentoItem>;

      _isLoaded = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _isLoaded = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    // Reseta os flags para permitir nova carga
    _isLoaded = false;
    _isLoading = false;
    notifyListeners();
    
    // Aguarda um frame para garantir que a UI atualize
    await Future.delayed(Duration.zero);
    
    // Carrega os dados novamente
    await loadAllData();
  }

  void clearData() {
    _materials = [];
    _products = [];
    _orcamentos = [];
    _isLoaded = false;
    _error = null;
    notifyListeners();
  }
}