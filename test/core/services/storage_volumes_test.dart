import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediabox/core/services/storage_volumes.dart';

void main() {
  tearDown(() {
    StorageVolumes.externalDirsProvider = () async => null;
  });

  group('StorageVolumes', () {
    group('detect', () {
      test('derives volume roots and marks the first as primary', () async {
        StorageVolumes.externalDirsProvider = () async => <Directory>[
              Directory('/storage/emulated/0/Android/data/pkg/files'),
              Directory('/storage/ABCD-1234/Android/data/pkg/files'),
            ];

        final List<StorageVolume> volumes = await StorageVolumes.detect();

        expect(volumes, hasLength(2));
        expect(volumes[0].path, '/storage/emulated/0');
        expect(volumes[0].isPrimary, isTrue);
        expect(volumes[1].path, '/storage/ABCD-1234');
        expect(volumes[1].isPrimary, isFalse);
      });

      test('dedupes repeated volume roots', () async {
        StorageVolumes.externalDirsProvider = () async => <Directory>[
              Directory('/storage/emulated/0/Android/data/pkg/files'),
              Directory('/storage/emulated/0/Android/data/pkg/cache'),
            ];

        final List<StorageVolume> volumes = await StorageVolumes.detect();

        expect(volumes, hasLength(1));
        expect(volumes.single.path, '/storage/emulated/0');
      });

      test('skips entries without an Android segment', () async {
        StorageVolumes.externalDirsProvider = () async => <Directory>[
              Directory('/weird/path/files'),
            ];

        final List<StorageVolume> volumes = await StorageVolumes.detect();

        expect(volumes, isEmpty);
      });

      test('returns empty when the query yields null', () async {
        StorageVolumes.externalDirsProvider = () async => null;

        expect(await StorageVolumes.detect(), isEmpty);
      });

      test('survives a failing query', () async {
        StorageVolumes.externalDirsProvider =
            () async => throw const FileSystemException('boom');

        expect(await StorageVolumes.detect(), isEmpty);
      });
    });
  });
}
