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
  List<Value> values; // current (puzzle) numbers
  int target; // target value
  List<SolutionStep> steps; // record of the current steps, used when reporting solutions
  List<bool> avail; // which source numbers are current available
  int curLabel;

  Game(this.values, this.target) {
    steps = [];
    avail = List.filled(values.length, true, growable: false);
    curLabel = values.last.label + 1;
  }

  Iterable<Solution> solve(int remaining) sync* {
    //print("remaining $remaining");
    if (steps.length > 0) {
      // first check the end of the steps stack - if it's worth reporting then report it
      final result = steps.last.result;
      final away = (result.num - target).abs();
      if (away <= bestAway) {
        /* note a subtlety here; we are yielding an instance that includes the current steps list, which is not duplicated and
        thus will be repeatedly modified after being yielded; however Game actually runs in an Isolate and when this Solution is
        passed to the main thread it gets implicitly copied
         */
        yield Solution(target, steps);
        if (away < bestAway) {
          bestAway = away;
        }
      }
    }
    if (remaining < 2) {
      return; // if there are less than two numbers remaining then we cannot do any more operations
    }
    // now try every possible combination of numbers and recurse, resetting the state afterwards
    for (var i = 0; i < values.length; ++i) {
      if (avail[i]) {
        for (var j = 0; j < values.length; ++j) {
          if (i != j && avail[j]) {
            //print("checking i $i j $j");
            // at this point we have found one valid combination of numbers; mark the second as unavailable, record the first, increment the label
            avail[j] = false;
            final v1 = values[i];
            final v2 = values[j];
            ++curLabel;
            // now try every possible operator
            for (var op in allowedOps) {
              final result = op.calc(v1, v2, curLabel); // note, fix curlabel stuff later
              //print("op $op v1 $v1 v2 $v2 result $result");
              if (result != null) {
                // the operation was a success ;-)
                steps.add(SolutionStep(op, v1, v2, result)); // push the step so it can be reported
                values[i] = result; // replace the first value with the result so deeper recursion can use it
                yield* solve(remaining - 1); // recurse immediately; if the result is good we report it in the very first step
                steps.removeLast(); // pop the step off the step stack because it was either already reported or no good
              }
            }
            // mark the second as available again, restore the first and the label
            --curLabel;
            values[i] = v1;
            avail[j] = true;
          } // else do nothing
        }
      }
    }
  }
}
