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

import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'solver.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static const title = "Numbers Game Solver";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainPage(title: title),
    );
  }
}

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static final smallNumbers = List.generate(10, (i) => i + 1);
  static final bigNumbers = [25, 50, 75, 100];
  static final sourceNumbers = smallNumbers + smallNumbers + bigNumbers;
  var sourceSelected = sourceNumbers.map((e) => false).toList(growable: false);
  static const sourceRequired = 6;
  static const maxTargetLength = 3;
  var targetNumber = 0;
  TextEditingController targetTextController = TextEditingController();
  static const targetWidth = 120.0;
  static final sourceStyle = TextStyle(
    fontSize: 16,
  );
  static final targetStyle = TextStyle(
    fontSize: 20,
  );
  static final buttonStyle = TextStyle(
    fontSize: 24,
  );
  List<Map> solutions = [];
  Isolate solver;
  SendPort sendToSolver;
  bool running = false;

  @override
  Widget build(BuildContext context) {
    final readyToSolve = countSelected() == sourceRequired && targetNumber >= 100;
    final clearable = countSelected() > 0 || targetNumber > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            numberRow(0, smallNumbers.length),
            numberRow(smallNumbers.length, smallNumbers.length),
            numberRow(smallNumbers.length * 2, bigNumbers.length),
            Container(
                width: targetWidth,
                child: TextField(
                    maxLength: maxTargetLength,
                    style: targetStyle,
                    maxLines: 1,
                    showCursor: false,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    controller: targetTextController,
                    decoration: InputDecoration(
                      hintText: 'Target',
                      border: const OutlineInputBorder(),
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
                  onPressed: clearable ? resetPuzzle : null,
                  child: Text(
                    'Reset',
                    style: buttonStyle,
                  ),
                ),
                TextButton(
                  onPressed: readyToSolve
                      ? () {
                          initSolver();
                        }
                      : null,
                  child: Text(running ? 'Stop' : 'Solve', style: buttonStyle),
                ),
              ],
            ),
            Text(solutions.length.toString()),
            Expanded(
              // don't understand yet how this works, but needed to stop squishing everything else
              child: ListView(
                children: resultTiles(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // returns a row of source number chips given by the offset and length
  Widget numberRow(int offset, int length) {
    return Center(
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: Iterable.generate(length, (i) => i + offset)
                .map((n) => ActionChip(
                      label: Text(
                        sourceNumbers[n].toString(),
                        style: sourceStyle,
                      ),
                      onPressed: () => toggleNumber(n),
                      backgroundColor: sourceSelected[n] ? Colors.blueAccent : Colors.white,
                    ))
                .toList()));
  }

  List<Widget> resultTiles() {
    return solutions.map((solution) {
      return ListTile(
        title: Text(solution.toString()),
      );
    }).toList();
  }

  void toggleNumber(int n) {
    setState(() {
      if (sourceSelected[n]) {
        // it is currently select, deselect it
        sourceSelected[n] = false;
      } else {
        // not selected, select it only if we don't already have 6 selected
        if (countSelected() < sourceRequired) {
          sourceSelected[n] = true;
        }
      }
    });
  }

  void resetPuzzle() {
    setState(() {
      sourceSelected.fillRange(0, sourceSelected.length, false);
      targetNumber = 0;
      solutions.clear();
      targetTextController.clear();
    });
  }

  int countSelected() {
    return sourceSelected.fold(0, (previousValue, element) => element ? previousValue + 1 : previousValue);
  }

  void initSolver() async {
    solutions.clear();
    sendToSolver = await startSolverListener();
    // we now have a running isolate and a port to send it the game
    final numbers =  Iterable.generate(sourceNumbers.length, (i) => i).where((i) => sourceSelected[i]).map((i) => sourceNumbers[i]).toList();
    sendToSolver.send({ 'numbers': numbers, 'target': targetNumber });
    setState(() {
      running = true;
    });
  }

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

    solver = await Isolate.spawn(sendSolutions, fromSolver.sendPort);
    return completer.future;
  }

  void receiveSolution(data) {
    setState(() {
      if (solutions.length > 0) {
        if ((data["away"] as int) < (solutions.first["away"] as int)) {
          solutions.clear(); // this solution is better than the ones we have, dump everything we have
        }
      }
      solutions.add(data);
    });
  }

  // void toggleSolve() {
  //   setState(() {
  //     if (solver == null) {
  //       final numbers =
  //           Iterable.generate(sourceNumbers.length, (i) => i).where((i) => sourceSelected[i]).map((i) => sourceNumbers[i]).toList();
  //       final game = Game(numbers, targetNumber);
  //       final solverStream = game.solveDepth(numbers.length);
  //       solutions.clear();
  //       print("about to listen");
  //       solver = solverStream.listen(
  //         (Solution s) {
  //           setState(() {
  //             if (s != null) {
  //               print("received $s");
  //               if (solutions.length > 0) {
  //                 if (s.away < solutions.first.away) {
  //                   // this solution is better than the previous ones, dump the old ones
  //                   solutions.clear();
  //                 } // the solver never returns worse solutions
  //               }
  //               solutions.add(s);
  //             }
  //           });
  //         },
  //         onDone: () {
  //           setState(() {
  //             print("onDone");
  //             solver = null;
  //           });
  //         },
  //       );
  //     } else {
  //       print("about to cancel");
  //       solver.cancel();
  //       solver = null;
  //     }
  //   });
  // }
}

void sendSolutions(SendPort toMain) {
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
  });
}
