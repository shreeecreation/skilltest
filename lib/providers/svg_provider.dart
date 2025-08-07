import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:xml/xml.dart';

// SVG Layer Model

// SVG Layer Model
class SvgLayer {
  final String id;
  final String elementName;
  String color;
  final XmlElement element;

  SvgLayer({
    required this.id,
    required this.elementName,
    required this.color,
    required this.element,
  });
}

// SVG Provider for state management
class SvgProvider with ChangeNotifier {
  List<SvgLayer> _layers = [];
  String? _rawSvg;
  XmlDocument? _xmlDocument;

  List<SvgLayer> get layers => _layers;
  String? get rawSvg => _rawSvg;
  XmlDocument? get xmlDocument => _xmlDocument;

  void loadSvg(String svgString) {
    try {
      _rawSvg = svgString;
      _xmlDocument = XmlDocument.parse(svgString);
      _parseLayers();
      notifyListeners();
    } catch (e) {
      print('Error parsing SVG: $e');
    }
  }

  void _parseLayers() {
    if (_xmlDocument == null) return;

    _layers = [];
    final drawableElements = _xmlDocument!
        .findAllElements('*')
        .where(
          (element) => [
            'path',
            'rect',
            'circle',
            'ellipse',
            'polygon',
            'polyline',
            'line',
            'g',
          ].contains(element.name.local.toLowerCase()),
        );

    int index = 1;
    for (final element in drawableElements) {
      // Skip if it's just a container group without drawable content
      if (element.name.local.toLowerCase() == 'g') {
        final hasDrawableChildren = element
            .findAllElements('*')
            .any(
              (child) => [
                'path',
                'rect',
                'circle',
                'ellipse',
                'polygon',
                'polyline',
                'line',
              ].contains(child.name.local.toLowerCase()),
            );
        if (!hasDrawableChildren) continue;
      }

      String color = _extractColor(element);
      String displayName = _generateDisplayName(element, index);

      _layers.add(
        SvgLayer(
          id: 'layer_$index',
          elementName: displayName,
          color: color,
          element: element,
        ),
      );
      index++;
    }

    // Update the raw SVG string with the modified XML
    _rawSvg = _xmlDocument!.toXmlString(pretty: false);
  }

  String _extractColor(XmlElement element) {
    // Check for fill attribute
    String? fill = element.getAttribute('fill');
    if (fill != null && fill != 'none' && fill.startsWith('#')) {
      return fill;
    }

    // Check for stroke attribute
    String? stroke = element.getAttribute('stroke');
    if (stroke != null && stroke != 'none' && stroke.startsWith('#')) {
      return stroke;
    }

    // Check style attribute
    String? style = element.getAttribute('style');
    if (style != null) {
      final fillMatch = RegExp(
        r'fill:\s*(#[0-9a-fA-F]{3,6})',
      ).firstMatch(style);
      if (fillMatch != null) {
        return fillMatch.group(1)!;
      }
      final strokeMatch = RegExp(
        r'stroke:\s*(#[0-9a-fA-F]{3,6})',
      ).firstMatch(style);
      if (strokeMatch != null) {
        return strokeMatch.group(1)!;
      }
    }

    // If no explicit color, add a default fill and return it
    element.setAttribute('fill', '#000000');
    return '#000000';
  }

  String _generateDisplayName(XmlElement element, int index) {
    String elementType = element.name.local;

    // Try to get id or class for better naming
    String? id = element.getAttribute('id');
    if (id != null && id.isNotEmpty) {
      return '$elementType ($id)';
    }

    String? className = element.getAttribute('class');
    if (className != null && className.isNotEmpty) {
      return '$elementType (.$className)';
    }

    return '$elementType $index';
  }

  void updateColor(String layerId, String newColor) {
    final layerIndex = _layers.indexWhere((layer) => layer.id == layerId);
    if (layerIndex == -1) return;

    final layer = _layers[layerIndex];
    final element = layer.element;

    // Update the color in the XML element
    _updateElementColor(element, newColor);

    // Update the layer's color
    _layers[layerIndex] = SvgLayer(
      id: layerId,
      elementName: layer.elementName,
      color: newColor,
      element: element,
    );

    // Update the raw SVG string
    _rawSvg = _xmlDocument!.toXmlString(pretty: false);

    notifyListeners();
  }

  void _updateElementColor(XmlElement element, String newColor) {
    // Check if element has fill attribute or fill in style
    String? currentFill = element.getAttribute('fill');
    String? style = element.getAttribute('style');

    if (currentFill != null) {
      // Update fill attribute
      element.setAttribute('fill', newColor);
    } else if (style != null && style.contains('fill:')) {
      // Update fill in style attribute
      String updatedStyle = style.replaceAll(
        RegExp(r'fill:\s*[^;]+'),
        'fill: $newColor',
      );
      element.setAttribute('style', updatedStyle);
    } else {
      // Add fill attribute if none exists
      element.setAttribute('fill', newColor);
    }
  }

  Uint8List? getSvgBytes() {
    if (_rawSvg == null) return null;
    return Uint8List.fromList(_rawSvg!.codeUnits);
  }
}
