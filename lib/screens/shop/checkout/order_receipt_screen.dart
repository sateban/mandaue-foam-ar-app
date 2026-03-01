import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../models/order.dart'; // Make sure this path is correct
import '../../../../services/firebase_service.dart';
import '../../../../providers/user_provider.dart';
import '../../../../widgets/authenticated_image.dart';

class OrderReceiptScreen extends StatefulWidget {
  const OrderReceiptScreen({super.key});

  @override
  State<OrderReceiptScreen> createState() => _OrderReceiptScreenState();
}

class _OrderReceiptScreenState extends State<OrderReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  String? _orderId;
  Order? _order;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_orderId == null) {
      _orderId = ModalRoute.of(context)?.settings.arguments as String?;
      if (_orderId != null) {
        _loadOrder();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadOrder() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;

    // In a real app, you might want to fetch directly by ID instead of list
    // But for now, let's reuse getOrders or assume we can fetch by path
    // Since getOrders returns a stream of ALL orders, let's fetch specific order path
    try {
      final orderData = await FirebaseService.readData(
        'users/$userId/orders/$_orderId',
      );

      if (orderData != null) {
        // Fix for readData returning dynamic map
        final typedMap = Map<String, dynamic>.from(orderData);
        // Ensure items list is correctly typed
        if (typedMap['items'] != null) {
          typedMap['items'] = (typedMap['items'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
        if (typedMap['shippingAddress'] != null) {
          typedMap['shippingAddress'] = Map<String, dynamic>.from(
            typedMap['shippingAddress'] as Map,
          );
        }

        if (mounted) {
          setState(() {
            _order = Order.fromMap(typedMap);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading order: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadReceipt() async {
    try {
      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/receipt_${_orderId}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      // Share or save
      // For simplicity/permissions, let's use Share Plus to let user save/share
      await Share.shareXFiles([XFile(imagePath)], text: 'My Order Receipt');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt ready to save/share')),
        );
      }
    } catch (e) {
      print('Error downloading receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving receipt: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'E-Receipt',
          style: TextStyle(color: Color(0xFF1E3A8A)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _order == null ? null : _downloadReceipt,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFDB022)),
            )
          : _order == null
          ? const Center(child: Text('Order not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: RepaintBoundary(
                key: _receiptKey,
                child: Container(
                  color: Colors.white, // Background for screenshot
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Barcode
                      Center(
                        child: BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: _order!.orderNumber,
                          width: 200,
                          height: 60,
                          drawText: false,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _order!.orderNumber,
                          style: const TextStyle(
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Items
                      ..._order!.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AuthenticatedImage(
                                    imageUrl: item.imageUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: Center(
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: Colors.grey[400],
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (item.color != null)
                                      Text(
                                        'Color: ${item.color}  |  Qty: ${item.quantity}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '₱${item.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 32),
                      // Payment Details
                      _buildDetailRow(
                        'Amount',
                        '₱${_order!.subtotal.toStringAsFixed(2)}',
                      ),
                      _buildDetailRow(
                        'Promo',
                        '-₱${_order!.discount.toStringAsFixed(2)}',
                        isDiscount: true,
                      ),
                      _buildDetailRow(
                        'Shipping',
                        '₱${_order!.shippingCharge.toStringAsFixed(2)}',
                      ),
                      _buildDetailRow(
                        'Tax',
                        '₱${_order!.tax.toStringAsFixed(2)}',
                      ),
                      const Divider(height: 32),
                      _buildDetailRow(
                        'Total',
                        '₱${_order!.total.toStringAsFixed(2)}',
                        isTotal: true,
                      ),
                      const SizedBox(height: 32),
                      // QR Code
                      Center(
                        child: QrImageView(
                          data: _order!.id,
                          version: QrVersions.auto,
                          size: 150.0,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Center(
                        child: Text(
                          'Thank you for shopping!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isDiscount
                  ? Colors.green
                  : (isTotal ? const Color(0xFF1E3A8A) : Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
