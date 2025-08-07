import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:xml/xml.dart';

import '../providers/svg_provider.dart';

// Main SVG Editor Screen
class SvgEditorScreen extends StatefulWidget {
  const SvgEditorScreen({super.key});

  @override
  State<SvgEditorScreen> createState() => _SvgEditorScreenState();
}

class _SvgEditorScreenState extends State<SvgEditorScreen> {
  final SvgProvider _svgProvider = SvgProvider();

  Future<void> pickSvgFile() async {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.svg';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      final file = files.first;
      final reader = html.FileReader();
      reader.readAsText(file);

      reader.onLoadEnd.listen((e) {
        final result = reader.result;
        if (result is String) {
          _svgProvider.loadSvg(result);
        }
      });
    });
  }

  void _showColorPicker(SvgLayer layer) async {
    Color currentColor = _parseColor(layer.color);
    Color pickedColor = currentColor;

    final result = await showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Change color for ${layer.elementName}'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) => pickedColor = color,
              enableAlpha: false,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Apply'),
              onPressed: () => Navigator.of(context).pop(pickedColor),
            ),
          ],
        );
      },
    );

    if (result != null) {
      String hexColor =
          '#${result.value.toRadixString(16).substring(2).padLeft(6, '0')}';
      _svgProvider.updateColor(layer.id, hexColor);
    }
  }

  Color _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      try {
        String hex = colorString.replaceFirst('#', '');
        if (hex.length == 3) {
          hex = hex.split('').map((c) => '$c$c').join();
        }
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {
        return Colors.black;
      }
    }
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SVG Editor")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // File picker button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: pickSvgFile,
                icon: const Icon(Icons.upload_file),
                label: const Text("Pick SVG File"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Main content
            Expanded(
              child: ListenableBuilder(
                listenable: _svgProvider,
                builder: (context, _) {
                  final svgBytes = _svgProvider.getSvgBytes();
                  final layers = _svgProvider.layers;

                  if (svgBytes == null) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No SVG file loaded',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Click "Pick SVG File" to get started',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return Row(
                    children: [
                      // SVG Preview
                      Expanded(
                        flex: 2,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SVG Preview',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SvgPicture.memory(
                                          svgBytes,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Layers Panel
                      Expanded(
                        flex: 1,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Layers (${layers.length})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: layers.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No editable layers found',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: layers.length,
                                          separatorBuilder: (context, index) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final layer = layers[index];
                                            return ListTile(
                                              dense: true,
                                              title: Text(
                                                layer.elementName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              leading: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: _parseColor(
                                                    layer.color,
                                                  ),
                                                  border: Border.all(
                                                    color: Colors.grey.shade400,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                              subtitle: Text(
                                                layer.color,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              onTap: () =>
                                                  _showColorPicker(layer),
                                              trailing: const Icon(
                                                Icons.palette,
                                                size: 18,
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
