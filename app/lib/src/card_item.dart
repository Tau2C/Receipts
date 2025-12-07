import 'package:barcode_widget/barcode_widget.dart';

class CardItem {
  final int? id;
  final String storeName;
  final String logoAsset;
  final String? comment;
  final String barcodeData;
  final BarcodeType barcodeType;

  const CardItem({
    this.id,
    required this.storeName,
    required this.logoAsset,
    this.comment,
    required this.barcodeData,
    required this.barcodeType,
  });

  CardItem copy({
    int? id,
    String? storeName,
    String? logoAsset,
    String? comment,
    String? barcodeData,
    BarcodeType? barcodeType,
  }) => CardItem(
    id: id ?? this.id,
    storeName: storeName ?? this.storeName,
    logoAsset: logoAsset ?? this.logoAsset,
    comment: comment ?? this.comment,
    barcodeData: barcodeData ?? this.barcodeData,
    barcodeType: barcodeType ?? this.barcodeType,
  );

  static CardItem fromMap(Map<String, Object?> json) => CardItem(
    id: json['id'] as int?,
    storeName: json['storeName'] as String,
    logoAsset: json['logoAsset'] as String,
    comment: json['comment'] as String,
    barcodeData: json['barcodeData'] as String,
    barcodeType: BarcodeType.values.firstWhere(
      (e) => e.toString() == json['barcodeType'],
    ),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'storeName': storeName,
    'logoAsset': logoAsset,
    'comment': comment,
    'barcodeData': barcodeData,
    'barcodeType': barcodeType.toString(),
  };
}
