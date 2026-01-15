import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/promo_code_model.dart';

class PromoCodeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all promo codes (Admin only)
  Future<List<PromoCode>> getAllPromoCodes() async {
    try {
      final response = await _supabase
          .from('promo_codes')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PromoCode.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch promo codes: $e');
    }
  }

  /// Get active promo codes only
  Future<List<PromoCode>> getActivePromoCodes() async {
    try {
      final response = await _supabase
          .from('promo_codes')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PromoCode.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch active promo codes: $e');
    }
  }

  /// Create a new promo code (Admin only)
  Future<PromoCode> createPromoCode({
    required String code,
    required int discountPercentage,
    bool isActive = true,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from('promo_codes')
          .insert({
        'code': code.toUpperCase(),
        'discount_percentage': discountPercentage,
        'is_active': isActive,
        'created_by': userId,
      })
          .select()
          .single();

      return PromoCode.fromJson(response);
    } catch (e) {
      if (e.toString().contains('duplicate key value')) {
        throw Exception('Promo code already exists');
      }
      throw Exception('Failed to create promo code: $e');
    }
  }

  /// Update an existing promo code (Admin only)
  Future<PromoCode> updatePromoCode({
    required String id,
    String? code,
    int? discountPercentage,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (code != null) updates['code'] = code.toUpperCase();
      if (discountPercentage != null) updates['discount_percentage'] = discountPercentage;
      if (isActive != null) updates['is_active'] = isActive;

      final response = await _supabase
          .from('promo_codes')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return PromoCode.fromJson(response);
    } catch (e) {
      if (e.toString().contains('duplicate key value')) {
        throw Exception('Promo code already exists');
      }
      throw Exception('Failed to update promo code: $e');
    }
  }

  /// Delete a promo code (Admin only)
  Future<void> deletePromoCode(String id) async {
    try {
      await _supabase
          .from('promo_codes')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete promo code: $e');
    }
  }

  /// Toggle promo code active status
  Future<PromoCode> togglePromoCodeStatus(String id, bool currentStatus) async {
    try {
      final response = await _supabase
          .from('promo_codes')
          .update({'is_active': !currentStatus})
          .eq('id', id)
          .select()
          .single();

      return PromoCode.fromJson(response);
    } catch (e) {
      throw Exception('Failed to toggle promo code status: $e');
    }
  }

  /// Validate a promo code (for use during checkout)
  Future<PromoCodeValidation> validatePromoCode(String code) async {
    try {
      final response = await _supabase
          .rpc('validate_promo_code', params: {'promo_code_text': code});

      if (response == null || response.isEmpty) {
        return PromoCodeValidation(
          isValid: false,
          discountPercentage: 0,
          message: 'Invalid promo code',
        );
      }

      final result = response[0];
      return PromoCodeValidation(
        isValid: result['valid'] ?? false,
        discountPercentage: result['discount_percentage'] ?? 0,
        message: result['message'] ?? '',
      );
    } catch (e) {
      // If RPC function doesn't exist, fallback to manual check
      try {
        final response = await _supabase
            .from('promo_codes')
            .select()
            .eq('code', code.toUpperCase())
            .eq('is_active', true)
            .maybeSingle();

        if (response == null) {
          return PromoCodeValidation(
            isValid: false,
            discountPercentage: 0,
            message: 'Invalid or inactive promo code',
          );
        }

        return PromoCodeValidation(
          isValid: true,
          discountPercentage: response['discount_percentage'],
          message: 'Promo code applied successfully',
        );
      } catch (e2) {
        throw Exception('Failed to validate promo code: $e2');
      }
    }
  }

  /// Record promo code usage
  Future<void> recordPromoCodeUsage({
    required String promoCodeId,
    required String userId,
    String? orderId,
    required double discountAmount,
  }) async {
    try {
      await _supabase.from('promo_code_usage').insert({
        'promo_code_id': promoCodeId,
        'user_id': userId,
        'order_id': orderId,
        'discount_amount': discountAmount,
      });
    } catch (e) {
      throw Exception('Failed to record promo code usage: $e');
    }
  }

  /// Get promo code usage statistics (Admin only)
  Future<List<PromoCodeUsage>> getPromoCodeUsage(String promoCodeId) async {
    try {
      final response = await _supabase
          .from('promo_code_usage')
          .select('''
            *,
            users:user_id (
              username,
              full_name,
              email
            )
          ''')
          .eq('promo_code_id', promoCodeId)
          .order('used_at', ascending: false);

      return (response as List)
          .map((json) => PromoCodeUsage.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch promo code usage: $e');
    }
  }

  /// Get promo code statistics
  Future<PromoCodeStats> getPromoCodeStats() async {
    try {
      final response = await _supabase.from('promo_codes').select();

      final allCodes = (response as List)
          .map((json) => PromoCode.fromJson(json))
          .toList();

      final activeCodes = allCodes.where((code) => code.isActive).length;
      final inactiveCodes = allCodes.where((code) => !code.isActive).length;

      return PromoCodeStats(
        totalCodes: allCodes.length,
        activeCodes: activeCodes,
        inactiveCodes: inactiveCodes,
      );
    } catch (e) {
      throw Exception('Failed to fetch promo code stats: $e');
    }
  }
}

