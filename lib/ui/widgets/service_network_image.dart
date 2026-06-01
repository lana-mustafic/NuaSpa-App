import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/media_url_resolver.dart';

final Map<String, Uint8List> _serviceImageCache = {};

bool _isAppHostedServiceImage(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed == null) {
    return false;
  }
  return parsed.path.contains('/api/files/usluge') ||
      parsed.path.contains('/uploads/usluge');
}

/// Učitava slike usluga preko Dio (JWT) ili javnog URL-a; keš u memoriji.
class ServiceNetworkImage extends StatefulWidget {
  const ServiceNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.error,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? error;

  @override
  State<ServiceNetworkImage> createState() => _ServiceNetworkImageState();
}

class _ServiceNetworkImageState extends State<ServiceNetworkImage> {
  Uint8List? _bytes;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ServiceNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    final resolved = resolveMediaUrl(widget.imageUrl);
    if (resolved.isEmpty) {
      if (mounted) {
        setState(() {
          _bytes = null;
          _loadError = StateError('empty');
        });
      }
      return;
    }

    final cached = _serviceImageCache[resolved];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _bytes = cached;
          _loadError = null;
        });
      }
      return;
    }

    if (!_isAppHostedServiceImage(resolved)) {
      if (mounted) {
        setState(() {
          _bytes = null;
          _loadError = null;
        });
      }
      return;
    }

    try {
      final response = await ApiClient().dio.get<List<int>>(
        resolved,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = Uint8List.fromList(response.data ?? []);
      if (data.isEmpty) {
        throw StateError('empty body');
      }
      _serviceImageCache[resolved] = data;
      if (mounted) {
        setState(() {
          _bytes = data;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bytes = null;
          _loadError = e;
        });
      }
    }
  }

  Widget _defaultPlaceholder() {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.06),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _defaultError() {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.04),
      child: Center(
        child: Icon(
          Icons.spa_outlined,
          size: 40,
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(widget.imageUrl);

    if (resolved.isEmpty || _loadError != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.error ?? _defaultError(),
      );
    }

    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.error ?? _defaultError(),
      );
    }

    if (!_isAppHostedServiceImage(resolved)) {
      return Image.network(
        resolved,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return widget.placeholder ?? _defaultPlaceholder();
        },
        errorBuilder: (_, _, _) => widget.error ?? _defaultError(),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: widget.placeholder ?? _defaultPlaceholder(),
    );
  }
}
