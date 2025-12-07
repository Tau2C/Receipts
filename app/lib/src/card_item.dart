import 'package:barcode_widget/barcode_widget.dart';

class CardItem {
  final String storeName;
  final String logoAsset;
  final String comment;
  final String barcodeData;
  final BarcodeType barcodeType;

  const CardItem({
    required this.storeName,
    required this.logoAsset,
    required this.comment,
    required this.barcodeData,
    required this.barcodeType,
  });
}
