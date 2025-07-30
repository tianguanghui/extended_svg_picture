import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:extended_image/extended_image.dart';

/// 借助ExtendedImage的本地缓存和SvgPicture加载网络的SVG
class ExtendedSvgPicture extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final Color? color;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool cache;
  final Duration retryDelay;
  final int maxRetries;

  const ExtendedSvgPicture({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.color,
    this.placeholder,
    this.errorWidget,
    this.cache = true,
    this.retryDelay = const Duration(milliseconds: 300),
    this.maxRetries = 3,
  }) : super(key: key);

  @override
  State<ExtendedSvgPicture> createState() => _ExtendedSvgPictureState();
}

class _ExtendedSvgPictureState extends State<ExtendedSvgPicture> {
  late String _imageUrl;
  late double _width;
  late double _height;
  late Color _color;

  Uint8List? _svgData;
  int _retryCount = 0;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _imageUrl = widget.imageUrl;
    _width = widget.width ?? 30;
    _height = widget.height ?? 30;
    _color = widget.color ?? Theme.of(context).primaryColor;

    _tryLoadCachedSvg();
  }

  Future<void> _tryLoadCachedSvg() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    if (!_isUrl(_imageUrl)) {
      _handleLoadError();
      return;
    }

    try {
      // 尝试磁盘缓存
      final file = await getCachedImageFile(_imageUrl);
      if (file != null && file.existsSync()) {
        final data = await file.readAsBytes();
        _handleSvgData(data);
        return;
      }

      // 无缓存时触发网络请求
      _loadNetworkSvg();
    } catch (e) {
      _handleLoadError(error: e);
    }
  }

  void _handleSvgData(Uint8List data) {
    if (!mounted) return;

    setState(() {
      _svgData = data;
      _isLoading = false;
      _hasError = false;
    });
  }

  void _handleLoadError({dynamic error}) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _hasError = true;
    });

    if (!_isUrl(_imageUrl)) {
      return;
    }

    if (_retryCount < widget.maxRetries) {
      Future.delayed(widget.retryDelay, () {
        if (mounted) {
          setState(() => _retryCount++);
          _tryLoadCachedSvg();
        }
      });
    }
  }

  void _loadNetworkSvg() {
    if (!mounted) return;

    // 使用ExtendedImage触发网络请求
    ExtendedNetworkImageProvider(
      _imageUrl,
      cache: widget.cache,
      cacheRawData: true,
    ).resolve(ImageConfiguration.empty).addListener(
          ImageStreamListener((info, _) {
            _tryLoadCachedSvg();
          }, onError: (e, stackTrace) {
            _handleLoadError(error: e);
          }),
        );
  }

  @override
  Widget build(BuildContext context) {
    // 错误状态显示
    if (_hasError) {
      return widget.errorWidget ?? _buildErrorWidget();
    }

    // 加载完成显示SVG
    if (_svgData != null) {
      return SvgPicture.memory(
        _svgData!,
        width: _width,
        height: _height,
        color: _color,
        placeholderBuilder: (_) => _buildPlaceholder(),
      );
    }

    // 加载中显示占位符
    return _buildPlaceholder();
  }

  Widget _buildErrorWidget() {
    return Icon(Icons.error, color: Colors.red, size: _width);
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          width: _width,
          height: _height,
          color: Colors.grey[200],
          child: Center(
            child: _isLoading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
  }

  bool _isUrl(String? value) {
    if (value == null) {
      return false;
    }
    return RegExp(r"^((https|http|ftp|rtsp|mms)?:\/\/)[^\s]+").hasMatch(value);
  }
}
