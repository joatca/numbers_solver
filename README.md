# numbers_solver

Solver for the Numbers game

The Numbers Solver finds solutions for the "Numbers" game (as played on long-running game shows in the UK, France and Australia). Note that it doesn't let you *play* the numbers game, it just finds the best solutions.

Brief rules for the Numbers game:

* Six "source" numbers are chosen from a pool of twenty-four. The pool contains two each of all the integers from 1 to 10, plus one each of 25, 50, 75 and 100.
* A three-digit "target" number is randomly selected (between 100 and 999)
* The target number must be reached using the source numbers and the basic numerical operations of addition, subtraction, multiplication and division.
* Each source number may only be used in one operation, and each intermediate result can also only be used in one later operation but it is *not* necessary to use all of the source numbers.
* No intermediate result may be negative
* All intermediate results must be integers
* Maximum points are scored for getting the exact target. Lower points are scored for getting up to nine away. If the closest number attainable is ten or more away, nothing is scored and there is considered to be no solution.
  
For example, with the source numbers 1 3 7 6 8 3 and target number 250 one possible solution is 8×3=24; 24+1=25; 7+3=10; 25×10=250. Note that here we had two 3's in the source list so 3 could be used twice. The app won't let you deviate from the standard rules (you can't select source numbers outside of the restrictions above, and the app starts solving the puzzle as soon as you select six source numbers and a valid target number), so it doesn't yet support "scary numbers" rounds. The app only shows the best solutions (those closest to the target number) and *will* show solutions that would score no points if those are the best solutions. For example, if the source numbers are 1 2 3 4 5 6 then no solution is possible for any target number above 960, since that's the highest possible with those numbers (3+1=4; 4×2=8; 8×4=32; 32×5=160; 160×6=960), so for a target of 999 it will show that solution as the best.

The algorithm is basically exhaustive search with some simple trimming of the expression space for useless or disallowed operations. (A useless operation is, for example, 6÷1 since the result is one of the operands so doesn't accomplish anything.)
It was written as a simple first [Flutter](https://flutter.dev/) app; I already had a [Crystal version](https://github.com/joatca/numbers) so it was easy to port the algorithm to Dart then focus on playing with the framework.

Also see the [app page](https://apps.joat.me/page/numbers/).
