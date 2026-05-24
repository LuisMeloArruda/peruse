abstract interface class IStudyRepository {
  Future<void> completeSession({
    required String sessionId,
    required String userId,
  });
}
