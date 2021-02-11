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

class Value {
  int num;
  int label; // help eliminate some duplicate recursions, plus labels stuff in the UI

  Value(this.num, this.label);

  Value add(Value other, int newLabel) {
    return Value(this.num + other.num, newLabel);
  }

  Value sub(Value other, int newLabel) {
    return Value(this.num - other.num, newLabel);
  }

  Value mul(Value other, int newLabel) {
    return Value(this.num * other.num, newLabel);
  }

  Value div(Value other, int newLabel) {
    return Value(this.num ~/ other.num, newLabel);
  }

  String toString() {
    return "$num[$label]";
  }

  bool operator ==(Object other) =>
      other is Value && num == other.num && label == other.label;
}

abstract class Op {
  String symbol();
  Value calc(Value v1, Value v2, int newLabel);

  String toString() {
    return symbol();
  }

  bool operator ==(Object other) => other is Op && symbol() == other.symbol();
}

class Add extends Op {
  symbol() => '+';

  Value calc(v1, v2, int newLabel) {
    if (v1.num > v2.num || (v1.num == v2.num /*&& v1.label < v2.label*/)) {
      // addition is commutative so we can ignore half of the possibilities
      return v1.add(v2, newLabel);
    }
    return null;
  }
}

class Sub extends Op {
  symbol() => '-';

  Value calc(v1, v2, int newLabel) {
    if (v1.num > v2.num) {
      // intermediate results may not be negative
      final result = v1.sub(v2, newLabel);
      /* neither operand is 0 so result can never be v1; if it's v2 then don't bother calling the function since it's a useless operation */
      if (result.num != v2.num) {
        return result;
      }
    }
    return null;
  }
}

class Mul extends Op {
  symbol() => '×';

  Value calc(v1, v2, int newLabel) {
/* ignore any combination where either operand is 1 since the result will be the other operand (so useless operation); also multiplication is commutative so filter out half of the operations */
    if (v1.num > 1 &&
        v2.num > 1 &&
        (v1.num > v2.num || (v1.num == v2.num /* && v1.label < v2.label */))) {
      return v1.mul(v2, newLabel);
    }
    return null;
  }
}

class Div extends Op {
  symbol() => '÷';

  Value calc(v1, v2, int newLabel) {
    /* only integer division allowed, so only when modulus is 0; since neither operand can be zero this also checks that v1>v2; also ignore when v2 is 1 since that's a useless operation */
    if (v1.num % v2.num == 0 && v2.num > 1) {
      return v1.div(v2, newLabel);
    }
    return null;
  }
}

class SolutionStep {
  Op op;
  Value v1, v2, result;

  SolutionStep(this.op, this.v1, this.v2, this.result);

  String toString() {
    return "$v1$op$v2=$result";
  }

  bool operator ==(Object other) =>
      other is SolutionStep &&
      op == other.op &&
      v1 == other.v1 &&
      v2 == other.v2 &&
      result == other.result;
}

class Solution with Comparable {
  List<SolutionStep> steps;
  int result, away, numTotals;

  Solution(int target, List<SolutionStep> solSteps) {
    steps = List.of(solSteps); // clone the list
    result = steps.last.result.num;
    away = (result - target).abs();
    // this is a sort field of last resort, so we can prefer smaller numbers; also stabilizes the sort, we hope?
    numTotals = solSteps.fold(0, (acc, step) => acc + step.v1.num + step.v1.num);
  }

  int compareTo(Object other) {
    assert(other is Solution);
    if (other is Solution) {
      if (this.away == other.away) {
        if (this.steps.length == other.steps.length) {
          return this.numTotals.compareTo(other.numTotals);
        } else {
          return this.steps.length.compareTo(other.steps.length);
        }
      } else {
        return this.away.compareTo(other.away);
      }
    } else {
      return 0; // shrug
    }
  }

  String toString() {
    return "${steps.map((step) => step.toString()).join('; ')} ($away away)";
  }

  bool operator ==(Object other) {
    return this.compareTo(other) == 0;
  }
}
