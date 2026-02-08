import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/filebase_service.dart';

/// Authenticated image loader with Firebase/Filebase caching and MinIO support
class AuthenticatedImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AuthenticatedImage({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    super.key,
  });

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  late Future<Uint8List?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = FilebaseService().getImageBytes(widget.imageUrl);
  }

  @override
  void didUpdateWidget(AuthenticatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _imageFuture = FilebaseService().getImageBytes(widget.imageUrl);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return widget.errorWidget ??
          Center(
            child: Icon(Icons.image_outlined, color: Colors.grey, size: 48),
          );
    }

    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholder ??
              Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFFFDB022),
                  strokeWidth: 2,
                ),
              );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return widget.errorWidget ??
              Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey,
                  size: 48,
                ),
              );
        }

        return Image.memory(
          snapshot.data!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
        );
      },
    );
  }
}
