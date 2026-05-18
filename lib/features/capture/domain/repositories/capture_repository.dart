import '../entities/capture.dart';
import '../entities/label.dart';

abstract interface class ICaptureRepository {
  Future<Capture> saveLocalCapture(String localPath, List<Label> labels);

  Future<List<Capture>> getLocalCaptures();

  Future<void> syncPendingCaptures();

  Future<String> uploadImageToStorage(String localPath, String path);

  Future<void> createRemoteCapture(Capture capture);
}
