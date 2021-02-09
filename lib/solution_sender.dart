/*
This file is part of Numbers Solver - solve the Numbers game used in several
long-running European game shows

Copyright (C) 2021 Fraser McCrossan

flax is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import 'dart:isolate';
import 'game.dart';
import 'game_classes.dart';

void solutionSender(SendPort toMain) {
  ReceivePort toSolver = ReceivePort();
  toMain.send(toSolver.sendPort);
  toSolver.listen((data) {
    // here we receive a map of the game
    final numbers = data["numbers"] as List<Value>;
    final target = data["target"] as int;
    final game = Game(numbers, target);
    for (var solution in game.solveDepth(6)) {
      toMain.send(solution); // doing this instead of the old toMsg() methods means it only works in Dart Native - not web
    }
    toMain.send(null); // signal end of run
  });
}
