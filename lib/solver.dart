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
  static const String symbol = '?';
  calc(Value v1, Value v2, void f(Value v));

  String toString() {
    return symbol;
  }
}

class Add extends Op {
  static const String symbol = '+';

  calc(v1, v2, f) {
    if (v1.num >= v2.num) {
      // addition is commutative so we can ignore half of the possibilities
      f(v1 + v2);
    }
  }
}

class Sub extends Op {
  static const String symbol = '-';

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
  static const String symbol = '×';

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
  static const String symbol = '÷';

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

