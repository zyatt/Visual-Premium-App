import 'package:flutter/foundation.dart';
import 'package:visualpremium/data/materials_repository.dart';
import 'package:visualpremium/data/products_repository.dart';
import 'package:visualpremium/data/orcamentos_repository.dart';
import 'package:visualpremium/models/material_item.dart';
import 'package:visualpremium/models/product_item.dart';
import 'package:visualpremium/models/orcamento_item.dart';
import 'package:visualpremium/models/pedido_item.dart';

class DataProvider extends ChangeNotifier {
  final _materialsApi = MaterialsApiRepository();
  final _productsApi = ProductsApiRepository();
  final _orcamentosApi = OrcamentosApiRepository();
  final _pedidosApi = OrcamentosApiRepository();

  List<MaterialItem> _materials = [];
  List<ProductItem> _products = [];
  List<OrcamentoItem> _orcamentos = [];
  List<PedidoItem> _pedidos = [];

  bool _isLoaded = false;
  bool _isLoading = false;
  String? _error;

  List<MaterialItem> get materials => _materials;
  List<ProductItem> get products => _products;
  List<OrcamentoItem> get orcamentos => _orcamentos;
  List<PedidoItem> get pedidos => _pedidos; // ADICIONAR
  
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
        _pedidosApi.fetchPedidos(), // ADICIONAR
      ]);

      _materials = results[0] as List<MaterialItem>;
      _products = results[1] as List<ProductItem>;
      _orcamentos = results[2] as List<OrcamentoItem>;
      _pedidos = results[3] as List<PedidoItem>; // ADICIONAR

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
    _isLoaded = false;
    _isLoading = false;
    notifyListeners();
    
    await Future.delayed(Duration.zero);
    
    await loadAllData();
  }

  void clearData() {
    _materials = [];
    _products = [];
    _orcamentos = [];
    _pedidos = []; // ADICIONAR
    _isLoaded = false;
    _error = null;
    notifyListeners();
  }
}