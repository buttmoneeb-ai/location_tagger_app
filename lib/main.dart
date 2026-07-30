import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const LocationTaggerApp());

class LocationTaggerApp extends StatelessWidget {
  const LocationTaggerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tagger',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  String? _locationText;
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final GlobalKey _boundaryKey = GlobalKey();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _useManualCoordinates() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      _showMessage('Please enter valid Latitude and Longitude');
      return;
    }
    await _reverseGeocode(lat, lng);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.locality, p.administrativeArea, p.country]
            .where((e) => e != null && e.isNotEmpty)
            .join(', ');
        setState(() => _locationText = parts.isEmpty ? '$lat, $lng' : parts);
      }
    } catch (e) {
      setState(() => _locationText = '$lat, $lng');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveAndShare() async {
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tagged_photo.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      _showMessage('Save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Tagger')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                color: Colors.black,
                child: Column(
                  children: [
                    _image == null
                        ? Container(
                            height: 300,
                            alignment: Alignment.center,
                            child: const Text('No image selected',
                                style: TextStyle(color: Colors.white)),
                          )
                        : Image.file(_image!, fit: BoxFit.cover),
                    if (_locationText != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        color: Colors.black87,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(_locationText!,
                                  style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Align(alignment: Alignment.centerRight, child: Text('Enter coordinates manually:')),
            TextField(
              controller: _latController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lngController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _useManualCoordinates, child: const Text('Add Tag')),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: (_image != null && _locationText != null) ? _saveAndShare : null,
              icon: const Icon(Icons.save),
              label: const Text('Save / Share'),
            ),
          ],
        ),
      ),
    );
  }
}
