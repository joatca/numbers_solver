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
  static final _distinctSources = sourcesMax.keys.toList();
  // number of sources required before allowing a solve
  static const _numSourcesRequired = 6;
  // which sources have been selected
  List<int> _sourcesSelected = [];
  // maximum length of the target word, used for the textfield
  static const _maxTargetLength = 3;
  // maximum number of solutions to store
  static const _maxSolutions = 20; // plenty of options
  // the actual target number
  var _targetNumber = 0;

  TextEditingController targetTextController = TextEditingController();

  // UI options
  static const _targetWidth = 120.0;
  static const _dividerColor = Colors.black12;
  static const _dividerThickness = 2.0;
  static const _stepSeparation = 6.0;
  static const _verticalStepSeparation = 3.0;
  static final _numberStyle = TextStyle(
    fontSize: 16,
  );
  static final _tagStyle = TextStyle(
    fontSize: 8,
    fontStyle: FontStyle.italic,
  );
  static final _targetStyle = TextStyle(
    fontSize: 20,
  );
  static final _sourceButtonStyle = TextStyle(
    fontSize: 20,
  );
  static final _actionButtonStyle = TextStyle(
    fontSize: 24,
  );
  List<Solution> _solutions = [];
  Isolate _solver;
  SendPort _sendToSolver;
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            sourceButtons(0, 5),
            sourceButtons(5, 10),
            sourceButtons(10, 14),
            standardDivider(_dividerColor),
            Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  selectedDisplay(),
                  targetField(),
                ]),
            actionButtonBar(),
            standardDivider(_solutions.length > 0 ? _dividerColor : Colors.transparent),
            solutionList(),
          ],
        ),
      ),
    );
  }

  Divider standardDivider(Color color) => Divider(
        thickness: _dividerThickness,
        color: _dividerColor,
        height: 2.0,
      );

  // shows which numbers are currently selected
  Widget selectedDisplay() {
    return Expanded(
        child: Text(
      _sourcesSelected.length > 0 ? _sourcesSelected.map((s) => s.toString()).join(' ') : '-',
      style: _sourceButtonStyle,
      textAlign: TextAlign.center,
    ));
  }

  Widget targetField() {
    return Container(
        padding: EdgeInsets.fromLTRB(8.0, 8.0, 36.0, 8.0),
        width: _targetWidth,
        child: TextField(
            maxLength: _maxTargetLength,
            style: _targetStyle,
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
                  _targetNumber = int.parse(val);
                } else {
                  _targetNumber = 0;
                }
                _solutions.clear();
              });
            }));
  }

  Widget actionButtonBar() {
    final clearable = _sourcesSelected.any((src) => src != null) || _targetNumber > 0;

    return ButtonBar(
      alignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: clearable && !_running ? removeLast : null,
          onLongPress: clearable && !_running ? resetPuzzle : null,
          label: Text(
            'Back',
            style: _actionButtonStyle,
          ),
          icon: Icon(Icons.undo),
        ),
        TextButton.icon(
          onPressed: solveButtonAction(),
          label: Text(_running ? 'Cancel' : 'Solve', style: _actionButtonStyle),
          icon: Icon(Icons.play_arrow),
        ),
      ],
    );
  }

  Widget solutionList() {
    return Expanded(
      // don't understand yet how this works, but needed to stop squishing everything else
      child: ListView.separated(
        itemCount: _solutions.length,
        separatorBuilder: (BuildContext context, int index) => standardDivider(_dividerColor),
        itemBuilder: (BuildContext context, int index) => resultTile(index),
      ),
    );
  }

  Widget sourceButtons(int start, int end) {
    return ButtonBar(
        alignment: MainAxisAlignment.center,
        children: _distinctSources.getRange(start, end).map<Widget>((srcNum) {
          return ElevatedButton(
              onPressed: () {
                processButton(srcNum);
              },
              child: Text(
                srcNum.toString(),
                style: _sourceButtonStyle,
              ));
        }).toList());
  }

  // returns each result in a ListTile
  List<Widget> resultTiles() => _solutions.map((solution) => solutionTile(solution)).toList();

  Widget resultTile(int index) => solutionTile(_solutions[index]);

  // returns a value (number plus tag)
  Widget valueTile(Value v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          v.num.toString(),
          style: _numberStyle,
        ),
        Text(
          v.tag,
          style: _tagStyle,
        ),
      ],
    );
  }

  Widget stepTile(SolutionStep step) {
    return Container(
        margin: EdgeInsets.fromLTRB(0.0, 0.0, _stepSeparation, _verticalStepSeparation),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            valueTile(step.v1),
            Text(
              step.op.toString(),
              style: _numberStyle,
            ),
            valueTile(step.v2),
            Text(
              '=',
              style: _numberStyle,
            ),
            valueTile(step.result),
          ],
        ));
  }

  Widget solutionTile(Solution solution) {
    final solutionWidgets = solution.steps.map<Widget>((step) => stepTile(step)).toList();
    solutionWidgets.add(Text(
      "(${solution.away} away)",
      style: _numberStyle,
    ));
    return Wrap(
      children: solutionWidgets,
    );
  }

  // is a particular button active?
  bool buttonActive(int srcNum) {
    if (_sourcesSelected.length >= _numSourcesRequired) {
      return false;
    }
    if (_sourcesSelected.where((s) => s == srcNum).length >= sourcesMax[srcNum]) {
      return false;
    }
    return true;
  }

  // action to take when the button labelled srcNum is pressed
  void processButton(int srcNum) {
    if (buttonActive(srcNum)) {
      setState(() {
        _sourcesSelected.add(srcNum);
      });
    }
  }

  // return that function that the solve/cancel button executes when tapped
  Function solveButtonAction() {
    if (_running) {
      return killSolver;
    } else {
      final readyToSolve = _sourcesSelected.length == _numSourcesRequired && _targetNumber >= 100;
      final sourcesIncludeTarget = _sourcesSelected.any((n) => n == _targetNumber);
      if (readyToSolve && !sourcesIncludeTarget) {
        return initSolver;
      } else {
        return null;
      }
    }
  }

  // remove just the last source number added
  void removeLast() {
    setState(() {
      if (_sourcesSelected.length > 0) {
        _sourcesSelected.removeLast();
      }
      _solutions.clear();
    });
  }

  // reset everything - remove any solutions, reset the target to zero and clear all the selected source numbers
  void resetPuzzle() {
    setState(() {
      _sourcesSelected.clear();
      _targetNumber = 0;
      _solutions.clear();
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
      if (_solutions.length > 0) {
        if (solution.away < _solutions.first.away) {
          _solutions.clear(); // this solution is better than the ones we have, dump everything
        }
      }
      _solutions.add(solution);
      // we sort only by the shortest solution since we've already eliminated any that are further away
      _solutions.sort((a, b) => a.steps.length.compareTo(b.steps.length));
      while (_solutions.length > _maxSolutions) {
        _solutions.removeLast();
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

    _solver = await Isolate.spawn(solutionSender, fromSolver.sendPort);
    return completer.future;
  }

  // called when the Solve button is pressed; clear the onscreen kb if possible, clear the solutions then start up the solver isolate
  void initSolver() async {
    setState(() {
      FocusScope.of(context).unfocus(); // dismiss the keyboard if possible
    });
    _solutions.clear();
    _sendToSolver = await startSolverListener();
    // we now have a running isolate and a port to send it the game
    _sendToSolver.send({'numbers': _sourcesSelected, 'target': _targetNumber});
    setState(() {
      _running = true;
    });
  }

  // kill the solver isolate if it's running then reset the running state
  void killSolver() {
    setState(() {
      _solver?.kill(priority: Isolate.immediate);
      _solver = null;
      _running = false;
    });
  }
}
