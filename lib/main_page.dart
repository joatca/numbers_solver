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
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:numbers_solver/game_classes.dart';
import 'solution_sender.dart';

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // how many of each source number are allowed
  static final Map<int, int> sourcesMax = {
    1: 2,
    2: 2,
    3: 2,
    4: 2,
    5: 2,
    6: 2,
    7: 2,
    8: 2,
    9: 2,
    10: 2,
    25: 1,
    50: 1,
    75: 1,
    100: 1,
  };
  // all possible source numbers
  static final distinctSources = sourcesMax.keys.toList();
  // number of sources required before allowing a solve
  static const numSourcesRequired = 6;
  // which sources have been selected
  List<int> sourcesSelected = [];
  // maximum length of the target word, used for the textfield
  static const maxTargetLength = 3;
  // maximum number of solutions to store
  static const maxSolutions = 20; // plenty of options
  // the actual target number
  var targetNumber = 0;

  // static final smallNumbers = List.generate(10, (i) => i + 1);
  // static final bigNumbers = [25, 50, 75, 100];
  // static final sourceNumbers = smallNumbers + smallNumbers + bigNumbers;
  // var sourceSelected = sourceNumbers.map((e) => false).toList(growable: false);

  TextEditingController targetTextController = TextEditingController();

  // UI options
  static const targetWidth = 120.0;
  static const dividerColor = Colors.black12;
  static const dividerThickness = 2.0;
  static const stepSeparation = 6.0;
  static const verticalStepSeparation = 3.0;
  static final numberStyle = TextStyle(
    fontSize: 16,
  );
  static final tagStyle = TextStyle(
    fontSize: 8,
    fontStyle: FontStyle.italic,
  );
  static final dropDownStyle = TextStyle(
    fontSize: 12,
    color: Colors.black,
  );
  static final targetStyle = TextStyle(
    fontSize: 20,
  );
  static final buttonStyle = TextStyle(
    fontSize: 24,
  );
  List<Solution> solutions = [];
  Isolate solver;
  SendPort sendToSolver;
  bool running = false;

  @override
  Widget build(BuildContext context) {
    final clearable = sourcesSelected.any((src) => src != null) || targetNumber > 0;
    final sourcesDropdowns = distinctSources.map<DropdownMenuItem<int>>((sourceNumber) {
      return DropdownMenuItem<int>(
        value: sourceNumber,
        child: Text(sourceNumber.toString(), style: dropDownStyle),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Wrap(
              children: distinctSources.map<Widget>((srcNum) {
                return TextButton(
                    onPressed: buttonActive(srcNum)
                        ? (() {
                            processButton(srcNum);
                          })
                        : null,
                    child: Text(
                      srcNum.toString(),
                      style: numberStyle,
                    ));
              }).toList(),
            ),
            Text(
              sourcesSelected.toString(),
            ),
            // numberRow(0, smallNumbers.length),
            // numberRow(smallNumbers.length, smallNumbers.length),
            // numberRow(smallNumbers.length * 2, bigNumbers.length),
            Container(
                width: targetWidth,
                child: TextField(
                    maxLength: maxTargetLength,
                    style: targetStyle,
                    maxLines: 1,
                    showCursor: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    controller: targetTextController,
                    decoration: InputDecoration(
                      hintText: 'Target',
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(1.0),
                      counterText: '', // don't show the counter'
                    ),
                    onChanged: (String val) async {
                      setState(() {
                        if (val.length > 0) {
                          targetNumber = int.parse(val);
                        } else {
                          targetNumber = 0;
                        }
                      });
                    })),
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: clearable && !running ? resetPuzzle : null,
                  child: Text(
                    'Clear',
                    style: buttonStyle,
                  ),
                ),
                TextButton(
                  onPressed: solveButtonAction(),
                  child: Text(running ? 'Cancel' : 'Solve', style: buttonStyle),
                ),
              ],
            ),
            Divider(
              color: solutions.length > 0 ? dividerColor : Colors.transparent,
              thickness: dividerThickness,
            ),
            Expanded(
              // don't understand yet how this works, but needed to stop squishing everything else
              child: ListView.separated(
                itemCount: solutions.length,
                separatorBuilder: (BuildContext context, int index) => Divider(
                  thickness: dividerThickness,
                  color: dividerColor,
                ),
                itemBuilder: (BuildContext context, int index) => resultTile(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // composite widget functions

  // returns a row of source number chips given by the offset and length
  // Widget numberRow(int offset, int length) {
  //   return Center(
  //       child: Row(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: Iterable.generate(length, (i) => i + offset)
  //               .map((n) => ActionChip(
  //                     label: Text(
  //                       chipFormat.format(sourceNumbers[n]),
  //                       style: numberStyle,
  //                     ),
  //                     onPressed: () => toggleNumber(n),
  //                     backgroundColor: sourceSelected[n] ? Colors.blueAccent : Colors.white,
  //                   ))
  //               .toList()));
  // }

  // returns each result in a ListTile
  List<Widget> resultTiles() => solutions.map((solution) => solutionTile(solution)).toList();

  Widget resultTile(int index) => solutionTile(solutions[index]);

  // returns a value (number plus tag)
  Widget valueTile(Value v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          v.num.toString(),
          style: numberStyle,
        ),
        Text(
          v.tag,
          style: tagStyle,
        ),
      ],
    );
  }

  Widget stepTile(SolutionStep step) {
    return Container(
        margin: EdgeInsets.fromLTRB(0.0, 0.0, stepSeparation, verticalStepSeparation),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            valueTile(step.v1),
            Text(
              step.op.toString(),
              style: numberStyle,
            ),
            valueTile(step.v2),
            Text(
              '=',
              style: numberStyle,
            ),
            valueTile(step.result),
          ],
        ));
  }

  Widget solutionTile(Solution solution) {
    final solutionWidgets = solution.steps.map<Widget>((step) => stepTile(step)).toList();
    solutionWidgets.add(Text(
      "(${solution.away} away)",
      style: numberStyle,
    ));
    return Wrap(
      children: solutionWidgets,
    );
  }

  // is a particular button active?
  bool buttonActive(int srcNum) {
    if (sourcesSelected.length >= numSourcesRequired) {
      return false;
    }
    if (sourcesSelected.where((s) => s == srcNum).length >= sourcesMax[srcNum]) {
      return false;
    }
    return true;
  }

  // action to take when the button labelled srcNum is pressed
  void processButton(int srcNum) {
    setState(() {
      sourcesSelected.add(srcNum);
    });
  }

  // return that function that the solve/cancel button executes when tapped
  Function solveButtonAction() {
    if (running) {
      return killSolver;
    } else {
      final readyToSolve = sourcesSelected.every((src) => src != null) && targetNumber >= 100;
      final sourcesIncludeTarget = sourcesSelected.any((n) => n == targetNumber);
      if (readyToSolve && !sourcesIncludeTarget) {
        return initSolver;
      } else {
        return null;
      }
    }
  }

  // reset everything - remove any solutions, reset the target to zero and clear all the selected source numbers
  void resetPuzzle() {
    setState(() {
      sourcesSelected.clear();
      targetNumber = 0;
      solutions.clear();
      targetTextController.clear();
    });
  }

  // solutionSender sends a null once the search is complete; if so then kill it, otherwise add the solution it just found
  void receiveSolution(data) {
    if (data == null) {
      killSolver();
    } else {
      setState(() {
        addSolution(data);
      });
    }
  }

  // add the latest solution then trim everything down to the "best" - prefer closer to the target and shorter solutions
  void addSolution(solution) {
    assert(solution is Solution);
    if (solution is Solution) {
      // this makes it typesafe inside the if block
      if (solutions.length > 0) {
        if (solution.away < solutions.first.away) {
          solutions.clear(); // this solution is better than the ones we have, dump everything
        }
      }
      solutions.add(solution);
      // we sort only by the shortest solution since we've already eliminated any that are further away
      solutions.sort((a, b) => a.steps.length.compareTo(b.steps.length));
      while (solutions.length > maxSolutions) {
        solutions.removeLast();
      }
    }
  }

  // this sets up all the ports to and from the solver isolate, registers a callback to listen, then starts up the isolate
  Future<SendPort> startSolverListener() async {
    Completer completer = new Completer<SendPort>();
    ReceivePort fromSolver = ReceivePort();

    fromSolver.listen((data) {
      if (data is SendPort) {
        completer.complete(data); // this is how we'll send games to the solver Isolate
      } else {
        receiveSolution(data); // otherwise this is how we receive solutions
      }
    });

    solver = await Isolate.spawn(solutionSender, fromSolver.sendPort);
    return completer.future;
  }

  // called when the Solve button is pressed; clear the onscreen kb if possible, clear the solutions then start up the solver isolate
  void initSolver() async {
    setState(() {
      FocusScope.of(context).unfocus(); // dismiss the keyboard if possible
    });
    solutions.clear();
    sendToSolver = await startSolverListener();
    // we now have a running isolate and a port to send it the game
    sendToSolver.send({'numbers': sourcesSelected, 'target': targetNumber});
    setState(() {
      running = true;
    });
  }

  // kill the solver isolate if it's running then reset the running state
  void killSolver() {
    setState(() {
      solver?.kill(priority: Isolate.immediate);
      solver = null;
      running = false;
    });
  }
}
