// lib/services/auth_provider.dart

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isApproved => _user?.status == 'approved';

  final ApiService _api = ApiService();

  Future<void> tryAutoLogin() async {
    final savedUser = await _api.getSavedUser();
    final token = await _api.getToken();
    if (savedUser != null && token != null) {
      _user = UserModel.fromJson(savedUser);
      notifyListeners();
      try {
        final fresh = await _api.getMe();
        _user = UserModel.fromJson(fresh);
        await _api.saveUser(fresh);
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.login(email, password);
      _user = UserModel.fromJson(data['user']);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? departmentId,
    String? enrollmentNumber,
    String? employeeId,
    int? year,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.register(
        fullName: fullName,
        email: email,
        password: password,
        role: role,
        departmentId: departmentId,
        enrollmentNumber: enrollmentNumber,
        employeeId: employeeId,
        year: year,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
