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

import 'game_classes.dart';

class Game {
  static const maxAway = 999; // furthest away we can be before reporting a result
  static final allowedOps = [Add(), Sub(), Mul(), Div()];
  int bestAway = maxAway + 1; // one more than the furthest away so we can tell if we got any solution
  List<int> numbers; // the raw numbers that came from the caller
  List<Value> values; // source (puzzle) numbers
  int target; // target value
  List<Value> stack; // expression stack
  List<SolutionStep> steps; // record of the current steps, used when reporting solutions
  List<bool> avail; // which source numbers are current available

  Game(this.numbers, this.target) {
    var letter = 'a'.codeUnitAt(0);
    values = numbers.map((n) => Value(n, String.fromCharCode(letter++))).toList();
    stack = [];
    steps = [];
    avail = List.filled(values.length, true);
  }

  // try something with the top two numbers
  Iterable<Solution> _tryOp(int depth, Op op) sync* {
    final v2 = stack.removeLast();
    final v1 = stack.removeLast();
    final result = op.calc(v1, v2);
    if (result != null) {
      /* we push the step onto the stack *before* checking whether we got the
           target, that way we can output the step immediately
         */
      steps.add(SolutionStep(op, v1, v2, result));
      final away = (result.num - target).abs();
      if (away <= bestAway) {
          yield Solution(target, steps);
          // sleep(Duration(milliseconds: 500));
        // we only want to report equivalent or better results, never worse results than the previous best
        if (away < bestAway) {
          bestAway = away;
        }
      }
      stack.add(result);
      yield* solveDepth(depth);
      stack.removeLast();
      steps.removeLast();
    }
    stack.add(v1);
    stack.add(v2);
  }

  // depth-wise solve
  Iterable<Solution> solveDepth(int depth) sync* {
    // if depth > 0 then we can continue to try pushing numbers onto the expression stack
    // bleugh we have to use a loop, there's no equivalent of each_with_index
    if (depth > 0) {
      for (var i = 0; i < values.length; i++) {
        if (avail[i]) {
          avail[i] = false;
          stack.add(values[i]);
          yield* solveDepth(depth - 1);
          stack.removeLast();
          avail[i] = true;
        }
      }
    }
    // if we have at least 2 numbers on the stack then we can try applying operations to them
    if (stack.length >= 2) {
      for (var op in allowedOps) {
        yield* _tryOp(depth, op);
      }
    }
    // for (var i = 0; i < 10; ++i) {
    //   yield null;
    //   sleep(Duration(seconds: 1));
    // }
  }

}
