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
  List<int> numbers;
  static const sourceRequired = 6;
  static const maxTargetLength = 3;
  static const maxSolutions = 20; // plenty of options
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
              height: 5,
              color: solutions.length > 0 ? Colors.black : Colors.transparent,
              thickness: 1,
            ),
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

  Function solveButtonAction() {
    if (running) {
      return killSolver;
    } else {
      final readyToSolve = countSelected() == sourceRequired && targetNumber >= 100;
      final sourcesIncludeTarget = sourceNumbers.any((n) => n == targetNumber);
      if (readyToSolve && !sourcesIncludeTarget) {
        return initSolver;
      } else {
        return null;
      }
    }
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
    if (!running) {
      setState(() {
        if (sourceSelected[n]) {
          // it is currently selected, deselect it
          sourceSelected[n] = false;
        } else {
          // not selected, select it only if we don't already have 6 selected
          if (countSelected() < sourceRequired) {
            sourceSelected[n] = true;
          }
        }
        numbers =
            Iterable.generate(sourceNumbers.length, (i) => i).where((i) => sourceSelected[i]).map((i) => sourceNumbers[i]).toList();
      });
    }
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

  void killSolver() {
    setState(() {
      solver?.kill(priority: Isolate.immediate);
      solver = null;
      running = false;
    });
  }

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
  void addSolution(data) {
    assert(data is Map);
    if (solutions.length > 0) {
      if ((data["away"] as int) < (solutions.first["away"] as int)) {
        solutions.clear(); // this solution is better than the ones we have, dump everything
      }
    }
    solutions.add(data);
    // we sort only by the shortest solution since we've already eliminated any that are further away
    solutions.sort((a, b) => a["steps"].length.compareTo(b["steps"].length));
    while (solutions.length > maxSolutions) {
      solutions.removeLast();
    }
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

  void initSolver() async {
    setState(() {
      FocusScope.of(context).unfocus(); // dismiss the keyboard if possible
    });
    solutions.clear();
    sendToSolver = await startSolverListener();
    // we now have a running isolate and a port to send it the game
    sendToSolver.send({'numbers': numbers, 'target': targetNumber});
    setState(() {
      running = true;
    });
  }
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
    toMain.send(null); // signal end of run
  });
}
