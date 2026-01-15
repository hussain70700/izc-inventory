// Models
class PromoCode {
  final String id;
  final String code;
  final int discountPercentage;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromoCode({
    required this.id,
    required this.code,
    required this.discountPercentage,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromoCode.fromJson(Map<String, dynamic> json) {
    return PromoCode(
      id: json['id'],
      code: json['code'],
      discountPercentage: json['discount_percentage'],
      isActive: json['is_active'] ?? true,
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'discount_percentage': discountPercentage,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PromoCode copyWith({
    String? id,
    String? code,
    int? discountPercentage,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromoCode(
      id: id ?? this.id,
      code: code ?? this.code,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PromoCodeValidation {
  final bool isValid;
  final int discountPercentage;
  final String message;

  PromoCodeValidation({
    required this.isValid,
    required this.discountPercentage,
    required this.message,
  });
}

class PromoCodeUsage {
  final String id;
  final String promoCodeId;
  final String? userId;
  final String? orderId;
  final double discountAmount;
  final DateTime usedAt;
  final Map<String, dynamic>? user;

  PromoCodeUsage({
    required this.id,
    required this.promoCodeId,
    this.userId,
    this.orderId,
    required this.discountAmount,
    required this.usedAt,
    this.user,
  });

  factory PromoCodeUsage.fromJson(Map<String, dynamic> json) {
    return PromoCodeUsage(
      id: json['id'],
      promoCodeId: json['promo_code_id'],
      userId: json['user_id'],
      orderId: json['order_id'],
      discountAmount: (json['discount_amount'] as num).toDouble(),
      usedAt: DateTime.parse(json['used_at']),
      user: json['users'],
    );
  }
}

class PromoCodeStats {
  final int totalCodes;
  final int activeCodes;
  final int inactiveCodes;

  PromoCodeStats({
    required this.totalCodes,
    required this.activeCodes,
    required this.inactiveCodes,
  });
}