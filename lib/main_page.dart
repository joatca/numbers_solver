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
  static final Map<int, int> sourcesMaxAllowed = {
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
  static final _distinctSources = sourcesMaxAllowed.keys.toList();
  // find the largest source number (and we'll assume it's also the widest)
  static final _largestSmallSource = 10;
  static final _largestSource = 100;
  double _smallChipWidth;
  double _largeChipWidth;
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
  Color _dividerColor;
  static const _dividerThickness = 2.0;
  static const _stepSeparation = 6.0;
  static const _verticalStepSeparation = 3.0;
  Color _accentColor;
  Color _sourceButtonBackgroundColor;
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
  List<Solution> _solutions = [];
  Isolate _solver;
  SendPort _sendToSolver;
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    _smallChipWidth = textWidth(_largestSmallSource, _sourceButtonStyle);
    _largeChipWidth = textWidth(_largestSource, _sourceButtonStyle);
    _dividerColor = Theme.of(context).textTheme.button.color.withOpacity(0.2);
    _accentColor = Theme.of(context).accentColor;
    _sourceButtonBackgroundColor = _accentColor.withOpacity(0.6);
    final clearable = _sourcesSelected.any((src) => src != null) || _targetNumber > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget> [
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
            onPressed: clearable ? _resetPuzzle : null,
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo number',
            onPressed: clearable ?_removeLast : null,
          ),
          // IconButton(
          //   icon: _running ? const Icon(Icons.stop) : const Icon(Icons.play_arrow),
          //   tooltip: 'Solve',
          //   onPressed: _solveButtonAction(),
          // )
        ]
      ),
      body: OrientationBuilder(
          builder: (context, orientation) => orientation == Orientation.portrait ? _verticalLayout() : _horizontalLayout()),
    );
  }

  Widget _verticalLayout() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          // _actionButtonBar(),
          _sourceButtons(0, 5, _smallChipWidth),
          _sourceButtons(5, 10, _smallChipWidth),
          _sourceButtons(10, 14, _largeChipWidth),
          _standardDivider(_dividerColor),
          Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                _selectedDisplay(),
                _targetField(),
              ]),
          _standardDivider(_solutions.length > 0 ? _dividerColor : Colors.transparent),
          _solutionList(),
        ],
      ),
    );
  }

  Widget _horizontalLayout() {
    return Row(children: [
      _solutionList(),
      Column(
        // full contents of right section
        children: [
          // _actionButtonBar(),
          _sourceButtons(0, 5, _smallChipWidth),
          _sourceButtons(5, 10, _smallChipWidth),
          _sourceButtons(10, 14, _largeChipWidth),
          _standardDivider(_dividerColor),
          _selectedDisplay(),
          _standardDivider(_dividerColor),
          _targetField(),
        ],
      )
    ]);
  }

  Divider _standardDivider(Color color) => Divider(
        thickness: _dividerThickness,
        color: _dividerColor,
        height: 2.0,
      );

  // shows which numbers are currently selected
  Widget _selectedDisplay() {
    return Expanded(
        child: Text(
      _sourcesSelected.length > 0 ? _sourcesSelected.map((s) => s.toString()).join(' ') : '-',
      style: _sourceButtonStyle,
      textAlign: TextAlign.center,
    ));
  }

  Widget _targetField() {
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
                maybeSolve();
              });
            }));
  }

  Widget _solutionList() {
    return Expanded(
      // don't understand yet how this works, but needed to stop squishing everything else
      child: ListView.separated(
        itemCount: _solutions.length,
        separatorBuilder: (BuildContext context, int index) => _standardDivider(_dividerColor),
        itemBuilder: (BuildContext context, int index) => _resultTile(index),
      ),
    );
  }

  Widget _sourceButtons(int start, int end, double width) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _distinctSources.getRange(start, end).map<Widget>((srcNum) {
          return Container(
            padding: EdgeInsets.only(left: 4.0, right: 4.0),
              child: ActionChip(
              onPressed: () {
                processButton(srcNum);
              },
              backgroundColor: _sourceButtonBackgroundColor,
                  
              label: Container(
                alignment: Alignment.center,
                  width: width,
                  child: Text(
                    srcNum.toString(),
                    style: _sourceButtonStyle,
                  ))));
        }).toList());
  }

  Widget _resultTile(int index) => _solutionTile(_solutions[index]);

  // returns a value (number plus tag)
  Widget _valueTile(Value v) {
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

  Widget _stepTile(SolutionStep step) {
    return Container(
        margin: EdgeInsets.fromLTRB(0.0, 0.0, _stepSeparation, _verticalStepSeparation),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _valueTile(step.v1),
            Text(
              step.op.toString(),
              style: _numberStyle,
            ),
            _valueTile(step.v2),
            Text(
              '=',
              style: _numberStyle,
            ),
            _valueTile(step.result),
          ],
        ));
  }

  Widget _solutionTile(Solution solution) {
    final solutionWidgets = solution.steps.map<Widget>((step) => _stepTile(step)).toList();
    solutionWidgets.add(Text(
      "(${solution.away} away)",
      style: _numberStyle,
    ));
    return Wrap(
      children: solutionWidgets,
    );
  }

  double textWidth(int number, TextStyle style) {
    final Size size = (TextPainter(
            text: TextSpan(text: number.toString(), style: style),
            maxLines: 1,
            textScaleFactor: MediaQuery.of(context).textScaleFactor,
            textDirection: TextDirection.ltr)
          ..layout())
        .size;
    return size.width;
  }

  // is a particular button active?
  bool _buttonActive(int srcNum) {
    if (_sourcesSelected.length >= _numSourcesRequired) {
      return false;
    }
    if (_sourcesSelected.where((s) => s == srcNum).length >= sourcesMaxAllowed[srcNum]) {
      return false;
    }
    return true;
  }

  // action to take when the button labelled srcNum is pressed
  void processButton(int srcNum) {
    if (_buttonActive(srcNum)) {
      setState(() {
        _sourcesSelected.add(srcNum);
        maybeSolve();
      });
    }
  }

  void maybeSolve() {
    if (_running) {
      _killSolver();
    } else {
            final readyToSolve = _sourcesSelected.length == _numSourcesRequired && _targetNumber >= 100;
      final sourcesIncludeTarget = _sourcesSelected.any((n) => n == _targetNumber);
if (readyToSolve && !sourcesIncludeTarget) {
  _initSolver();
            }
    }
  }

  // remove just the last source number added
  void _removeLast() {
    setState(() {
      if (_sourcesSelected.length > 0) {
        _sourcesSelected.removeLast();
      }
      _solutions.clear();
      _killSolver();
    });
  }

  // reset everything - remove any solutions, reset the target to zero and clear all the selected source numbers
  void _resetPuzzle() {
    setState(() {
      _killSolver();
      _targetNumber = 0;
      _sourcesSelected.clear();
      _solutions.clear();
      targetTextController.clear();
    });
  }

  // solutionSender sends a null once the search is complete; if so then kill it, otherwise add the solution it just found
  void _receiveSolution(data) {
    if (data == null) {
      _killSolver();
    } else {
      setState(() {
        _addSolution(data);
      });
    }
  }

  // add the latest solution then trim everything down to the "best" - prefer closer to the target and shorter solutions
  void _addSolution(solution) {
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
  Future<SendPort> _startSolverListener() async {
    Completer completer = new Completer<SendPort>();
    ReceivePort fromSolver = ReceivePort();

    fromSolver.listen((data) {
      if (data is SendPort) {
        completer.complete(data); // this is how we'll send games to the solver Isolate
      } else {
        _receiveSolution(data); // otherwise this is how we receive solutions
      }
    });

    _solver = await Isolate.spawn(solutionSender, fromSolver.sendPort);
    return completer.future;
  }

  // called when the Solve button is pressed; clear the onscreen kb if possible, clear the solutions then start up the solver isolate
  void _initSolver() async {
    setState(() {
      FocusScope.of(context).unfocus(); // dismiss the keyboard if possible
    });
    _solutions.clear();
    _sendToSolver = await _startSolverListener();
    // we now have a running isolate and a port to send it the game
    _sendToSolver.send({'numbers': _sourcesSelected, 'target': _targetNumber});
    setState(() {
      _running = true;
    });
  }

  // kill the solver isolate if it's running then reset the running state
  void _killSolver() {
    setState(() {
      _solver?.kill(priority: Isolate.immediate);
      _solver = null;
      _running = false;
    });
  }
}
