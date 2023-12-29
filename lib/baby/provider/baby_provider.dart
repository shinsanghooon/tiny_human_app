import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiny_human_app/baby/model/baby_model.dart';

import '../model/baby_model_with_presigned.dart';
import '../repository/baby_repository.dart';

final babyProvider =
    StateNotifierProvider<BabyNotifier, List<BabyModel>>((ref) {
  final repository = ref.watch(babyRepositoryProvider);
  return BabyNotifier(repository: repository);
});

class BabyNotifier extends StateNotifier<List<BabyModel>> {
  final BabyRepository repository;

  BabyNotifier({
    required this.repository,
  }) : super([]) {
    getMyBabies();
  }

  Future<void> getMyBabies() async {
    final response = await repository.getMyBabies();
    state = response;
  }

  void addBaby(BabyModel baby) {
    state = [...state, baby];
  }

  Future<BabyModel> updateBaby(
      {required int babyId, required Map<String, dynamic> body}) async {
    final response = await repository.updateBaby(id: babyId, body: body);
    getMyBabies();
    return response;
  }

  Future<BabyModelWithPreSigned> updateBabyProfile(
      {required int babyId, required Map<String, dynamic> body}) async {
    return await repository.updateBabyProfile(id: babyId, body: body);
  }

  Future<void> delete(int id) async {
    await repository.deleteBaby(id: id);
    final response = await repository.getMyBabies();
    state = response;
  }
}
