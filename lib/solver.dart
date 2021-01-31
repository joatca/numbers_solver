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
  String tag;

  Value(this.num, this.tag);

  String combineTag(Value other) => this.tag + other.tag;

  Value operator +(Value other) {
    return Value(this.num + other.num, combineTag(other));
  }

  Value operator -(Value other) {
    return Value(this.num - other.num, combineTag(other));
  }

  Value operator *(Value other) {
    return Value(this.num * other.num, combineTag(other));
  }

  Value operator ~/(Value other) {
    return Value(this.num ~/ other.num, combineTag(other));
  }

  String toString() {
    return "$num[$tag]";
  }
}

abstract class Op {
  String symbol();
  calc(Value v1, Value v2, void f(Value v));

  String toString() {
    return symbol();
  }
}

class Add extends Op {
  symbol() => '+';

  calc(v1, v2, f) {
    if (v1.num >= v2.num) {
      // addition is commutative so we can ignore half of the possibilities
      f(v1 + v2);
    }
  }
}

class Sub extends Op {
  symbol() => '-';

  calc(v1, v2, f) {
    if (v1.num > v2.num) {
      // intermediate results may not be negative
      final result = v1 - v2;
      /* neither operand is 0 so result can never be v1; if it's v2 then don't bother calling the function since it's a useless operation */
      if (result.num != v2.num) {
        f(result);
      }
    }
  }
}

class Mul extends Op {
  symbol() => '×';

  calc(v1, v2, f) {
    if (v1.num > v2.num) {
      // intermediate results may not be negative
      final result = v1 - v2;
/* ignore any combination where either operand is 1 since the result will be the other operand (so useless operation); also multiplication is commutative so filter out half of the operations */
      if (v1.num > 1 && v2.num > 1 && v1.num > v2.num) {
        f(result);
      }
    }
  }
}

class Div extends Op {
  symbol() => '÷';

  calc(v1, v2, f) {
    /* only integer division allowed, so only when modulus is 0; since neither operand can be zero this also checks that v1>v2; also ignore when v2 is 1 since that's a useless operation */
    if (v1.num > v2.num) {
      if (v1.num % v2.num == 0 && v2.num > 1) {
        f(v1 ~/ v2);
      }
    }
  }
}

class Step {
  Op op;
  Value v1, v2, result;

  Step(this.op, this.v1, this.v2, this.result);

  String toString() {
    return "$v1$op$v2=$result";
  }
}

class Game {
  static const maxAway = 9; // furthest away we can be before reporting a result
  static final allowedOps = [Add(), Sub(), Mul(), Div()];
  int bestAway = maxAway +
      1; // one more than the furthest away so we can tell if we got any solution
  List<int> numbers; // the raw numbers that came from the caller
  List<Value> values; // source (puzzle) numbers
  int target; // target value
  List<Value> stack; // expression stack
  List<Step>
      steps; // record of the current steps, used when reporting solutions
  List<bool> avail; // which source numbers are current available

  Game(this.numbers, this.target) {
    var letter = 'a'.codeUnitAt(0);
    values = numbers.map((n) => Value(n, String.fromCharCode(letter++))).toList();
    print(values);
    stack = [];
    steps = [];
    avail = List.filled(values.length, true);
  }
  
  /* there follow three abstraction functions that make the core code both
     simpler and more confusing (if you haven't used a lot of Ruby); each
     one performs an operation on a stack, calls a function (passed anonymously
     when used further down) then reverses that stack operation. They avoid
     littering the code with stack operations */

  // abstract away the push-a-result, do-something, pop-the-result action
  void with_step(Step step, void f()) {
    // print("steps $steps add_step $step");
    steps.add(step);
    // print("steps during $steps");
    f();
    steps.removeLast();
    // print("steps after $steps");
  }

  // abstract away the push-a-result, do-something, pop-the-result action
  void with_value_on_stack(Value v, void f()) {
    stack.add(v);
    f();
    stack.removeLast();
  }

  // and finally abstract away popping two values, doing something with them then pushing them back again
  void with_top_values(void f(Value a, b)) {
    final v2 = stack.removeLast();
    final v1 = stack.removeLast(); // note the reverse order
    f(v1, v2);
    stack.add(v1);
    stack.add(v2);
  }

  // try something with the top two numbers
  void try_op(int depth, Op op) {
    with_top_values((v1, v2) {
      op.calc(v1, v2, (result) {
        /* we push the step onto the stack *before* checking whether we got the
           target, that way we can output the step immediately
         */
        with_step(Step(op, v1, v2, result), () {
          final away = (result.num - target).abs();
          if (away <= bestAway) {
            // for now just report the result to the console, we'll worry about async reporting to the screen later
            showSteps();
          }
          // we only want to report equivalent or better results, never worse results than the previous best
          if (away < bestAway) {
            bestAway = away;
          }
          with_value_on_stack(result, () { solve_depth(depth); });
        });
      });
    });
  }

  // depth-wise solve
  void solve_depth(int depth) {
    // if depth > 0 then we can continue to try pushing numbers onto the expression stack
    // bleugh we have to use a loop, there's no equivalent of each_with_index
    for (var i = 0; i < values.length; ++i) {
      if (avail[i]) {
        avail[i] = false;
        with_value_on_stack(values[i], () { solve_depth(depth - 1); });
        avail[i] = true;
      }
    }
    // if we have at least 2 numbers on the stack then we can try applying operations to them
    if (stack.length >= 2) {
      allowedOps.forEach((op) { try_op(depth, op); });
    }
  }

  // TMP: show the current steps
  void showSteps() {
    // print(steps);
    print("${steps.map((step) => step.toString()).join('; ')}");
  }
}
