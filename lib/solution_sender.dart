import 'dart:isolate';
import 'solver.dart';

void solutionSender(SendPort toMain) {
  ReceivePort toSolver = ReceivePort();
  toMain.send(toSolver.sendPort);
  toSolver.listen((data) {
    // here we receive a map of the game
    final numbers = data["numbers"] as List<int>;
    final target = data["target"] as int;
    final game = Game(numbers, target);
    for (var solution in game.solveDepth(6)) {
      toMain.send(solution.toMsg());
    }
    toMain.send(null); // signal end of run
  });
}
