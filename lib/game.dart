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
  static const _maxAway = 999; // furthest away we can be before reporting a result
  static final _allowedOps = [Add(), Sub(), Mul(), Div()];
  int bestAway = _maxAway + 1; // one more than the furthest away so we can tell if we got any solution
  List<Value> _values; // current (puzzle) numbers
  int _target; // target value
  List<SolutionStep> _steps; // record of the current steps, used when reporting solutions
  List<bool> _avail; // which source numbers are current available
  int _curLabel;

  Game(this._values, this._target) {
    _steps = [];
    _avail = List.filled(_values.length, true, growable: false);
    _curLabel = _values.last.label;
  }

  Iterable<Solution> _solve(int remaining) sync* {
    //print("remaining $remaining");
    if (_steps.length > 0) {
      // first check the end of the steps stack - if it's worth reporting then report it
      final result = _steps.last.result;
      final away = (result.num - _target).abs();
      if (away <= bestAway) {
        /* note a subtlety here; we are yielding an instance that includes the current steps list, which is not duplicated and
        thus will be repeatedly modified after being yielded; however Game actually runs in an Isolate and when this Solution is
        passed to the main thread it gets implicitly copied
         */
        yield Solution(_target, _steps);
        if (away < bestAway) {
          bestAway = away;
        }
      }
    }
    if (remaining < 2) {
      return; // if there are less than two numbers remaining then we cannot do any more operations
    }
    // now try every possible combination of numbers and recurse, resetting the state afterwards
    for (var i = 0; i < _values.length; ++i) {
      if (_avail[i]) {
        for (var j = 0; j < _values.length; ++j) {
          if (i != j && _avail[j]) {
            //print("checking i $i j $j");
            // at this point we have found one valid combination of numbers; mark the second as unavailable, record the first, increment the label
            _avail[j] = false;
            final v1 = _values[i];
            final v2 = _values[j];
            ++_curLabel;
            // now try every possible operator
            for (var op in _allowedOps) {
              final result = op.calc(v1, v2, _curLabel); // note, fix curlabel stuff later
              //print("op $op v1 $v1 v2 $v2 result $result");
              if (result != null) {
                // the operation was a success ;-)
                _steps.add(SolutionStep(op, v1, v2, result)); // push the step so it can be reported
                _values[i] = result; // replace the first value with the result so deeper recursion can use it
                yield* _solve(remaining - 1); // recurse immediately; if the result is good we report it in the very first step
                _steps.removeLast(); // pop the step off the step stack because it was either already reported or no good
              }
            }
            // mark the second as available again, restore the first and the label
            --_curLabel;
            _values[i] = v1;
            _avail[j] = true;
          } // else do nothing
        }
      }
    }
  }

  Iterable<Solution> solve() sync* {
    yield* _solve(_values.length);
  }
}
