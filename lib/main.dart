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
import 'package:flutter/cupertino.dart';
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
  StreamSubscription solutions;


  @override
  Widget build(BuildContext context) {
    final readyToSolve =
        countSelected() == sourceRequired && targetNumber >= 100;
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
                  onPressed: readyToSolve ? () { startSolve(); } : null,
                  child: Text(solutions == null ? 'Solve' : 'Stop', style: buttonStyle),
                ),
              ],
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

  void resetPuzzle() {
    setState(() {
      sourceSelected.fillRange(0, sourceSelected.length, false);
      targetNumber = 0;
      targetTextController.clear();
    });
  }

  // this will eventually be some Stream thing but for now we just call the game solver so it prints to the console
  void startSolve() {
    final numbers = Iterable.generate(sourceNumbers.length, (i) => i).where((i) => sourceSelected[i]).map((i) => sourceNumbers[i]).toList();
    print(numbers);
    final game = Game(numbers, targetNumber);
    final solutionStream = game.solutions();
    for (var solution in solutionStream) {
      setState(() {
        print("${solution.map((step) => step.toString()).join('; ')}");
      });
    }
    print("game over");
  }

  void killSolve() async {
    solutions.cancel();
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

  int countSelected() {
    return sourceSelected.fold(
        0,
        (previousValue, element) =>
            element ? previousValue + 1 : previousValue);
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
                      backgroundColor:
                          sourceSelected[n] ? Colors.blueAccent : Colors.white,
                    ))
                .toList()));
  }

  List<Widget> resultTiles() {
    return <Widget>[];
  }
}
